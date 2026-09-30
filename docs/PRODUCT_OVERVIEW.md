# PadiLearn — product overview and handoff

Context for anyone picking up work on PadiLearn without having lived through
the decisions. Written 30 September 2026. Pair it with `DEVLOG.md` (why things
are the way they are) and `LAUNCH_ANDROID.md` (what is left to do).

---

## What it is

A marketplace for video courses by Nigerian teachers. Teachers upload
pre-recorded courses; students buy one-off access and watch on their phone.
Not a subscription, not live tuition, not certification.

Mobile-first by choice: the audience is on Android phones in Nigeria, on data
they pay for. The website exists for legal pages and, soon, for buying.

**Stage: pre-launch.** The app works end to end but has never been on a store.
Real usage is roughly 10 enrolments and 3 rated courses — seed-level numbers,
not traction. Nothing has ever been sold.

---

## The business model

| | |
|---|---|
| What is sold | Permanent access to one course. One-off payment, no subscription. |
| Currency | NGN only. |
| Processor | Paystack. |
| Platform take | 15% of the course's list price. |
| Teacher take | 85% of the list price. |
| Card fee | Paid by the student, added on top at checkout. |

On a course listed at NGN 5,000: the student pays **NGN 5,178**, Paystack takes
**NGN 178**, PadiLearn keeps **NGN 750**, the teacher earns **NGN 4,250**.

The teacher's price is what *settles*, so their earnings never move with a fee
they did not agree to. See `lib/utils/pricing.dart` and
`supabase/functions/_shared/paystack.ts` — the gross-up is duplicated in Dart
and TypeScript out of necessity, and **the two must agree exactly**, because
`initialize-payment` charges the total while `grantEntitlement` rejects
anything under it.

Teacher payouts are not built. `payout_accounts` and the `transactions` ledger
exist; moving money to teachers is manual and undesigned.

---

## The constraint that shapes everything

**Paid courses cannot be sold inside the mobile app.**

Google Play's Payments policy and Apple's Guideline 3.1.1 require digital
content consumed in-app to be sold through store billing. They *also* forbid
pointing users from inside the app to an outside checkout — by button, link,
WebView or wording. Breaking this risks removal; repeated violations risk
account termination.

Two objections come up reliably, both answered at length in
`LAUNCH_ANDROID.md`:

- *Glovo and Bolt take card payments in Nigeria.* They sell physical goods and
  real-world services, which are exempt. Courses are not.
- *Spotify and Netflix show a "See plans" link now.* That rests on the 2025 US
  Epic injunctions and the EU DMA, plus Apple's reader-app entitlement.
  **Nigeria is covered by none of it**, and Google has no reader-app
  equivalent.

So the plan is: **sell on the web, watch in the app.** Store billing was
considered and rejected — roughly 5x less revenue per sale, two separate
implementations, a new commission model, and merchant eligibility from Nigeria
that has never been confirmed.

In-app paid checkout is switched off behind `kPaidCheckoutEnabled` in
`lib/config/features.dart`. The closed beta ships free courses only.

**A consequence that drives architecture:** the app may not advertise where to
buy, so search results are the main discovery route for a paid course. Web
course pages must be server-rendered and indexable. Static, client-rendered
pages would remove the only compliant discovery channel there is.

---

## How it is built

- **App** — Flutter 3.38, ~15k lines across `lib/`. GetX for state. Android
  package `com.padilearn.app`.
- **Backend** — Supabase only. Auth, Postgres, Storage. Firebase was removed
  entirely; do not reintroduce it.
- **Security model** — the app talks to Postgres directly with a publishable
  key, and **Row Level Security is the authorisation layer**. Anything that
  must not be client-decided lives in an edge function using the service role.
- **Edge functions** — `initialize-payment`, `verify-payment`,
  `paystack-webhook`, `get-course-video`, `payout-account`, `delete-account`.
- **Website** — Astro 5, static, on Cloudflare Pages, ~1k lines in `website/`.
  Marketing plus `/privacy`, `/terms`, `/delete-account`, `/email-confirmed`,
  `/payment-callback`.
- **Email** — `hello@padilearn.com`. Inbound on Hostinger, outbound via Resend.
- **Errors** — Sentry is wired into `main.dart` but dark until a DSN is passed
  at build time.

**Entitlement is one row.** An `enrollments` row is what grants access, and
`get-course-video` checks for it before signing a playback URL. Payment
confirmation writes that row server-side; clients can self-enrol only in free
courses, and RLS enforces it. Any new purchase path must end at that same row.

Videos sit in Supabase Storage. Fine at this size, but egress is the cost that
bites first; Bunny or Cloudflare Stream is the intended escape. YouTube was
ruled out.

---

## The web build (the piece being handed over)

Turn the existing Astro site into a storefront. It is an addition to
`website/`, not a new codebase, and **it never learns to play video** — that
line is what stops it becoming a second product.

In scope:

1. **Supabase auth on the web.** The site has none today, and a purchase must
   attach to a user ID. Client-side `supabase-js` with the publishable key and
   RLS, the same trust model as the app. *This is the bulk of the work.*
2. **Course catalogue and course pages**, server-rendered via
   `@astrojs/cloudflare` so they are indexable. Public read of `courses`.
3. **Buy** → `initialize-payment` → Paystack → `/payment-callback`.
4. **Rewrite `payment-callback.astro`.** Read its header comment: it currently
   assumes the in-app WebView intercepts it and its only job is bouncing the
   user back to the app. For web purchases it must call `verify-payment` and
   confirm on the page.

Out of scope, permanently: video playback, the lesson player, progress,
comments, notifications, the teacher dashboard, uploads, payout management.

Gotchas that cost a day each if unknown:

- **Password reset currently deep-links to `padilearn://reset-callback`**,
  straight into the app. A web user resetting a password gets bounced toward an
  app they may not have installed. Needs a web reset page and a branch in the
  redirect logic.
- **Supabase's redirect allowlist must contain every URL used**, or the
  redirect silently falls back to the Site URL.
- **Google sign-in on the web is a different flow** from the app's. The app
  uses native ID tokens; the web needs the OAuth redirect flow, which means
  filling in the Client Secret and registering the callback URL in Google
  Cloud — fields the native setup deliberately leaves empty.
- **Prices shown while browsing are the teacher's list price.** The card fee is
  itemised at checkout, matching the app. Do not show grossed-up prices in the
  catalogue.

---

## Open questions, not yet decided

- **Company registration.** CAC private company limited by shares, sole
  director. Optional for launch, but Paystack will likely require a registered
  business for marketplace payouts.
- **Paystack's marketplace structure.** PadiLearn collects money on behalf of
  teachers, which Paystack treats differently from an ordinary merchant.
  Subaccounts, split payments or Transfers — a compliance review is open and
  will decide it.
- **Teacher payouts.** No mechanism, no schedule, no reconciliation.
- **Refunds.** `website/src/pages/terms.md` still has a placeholder here.
- **Video hosting.** When does Supabase Storage stop being viable, and what is
  the trigger to move.

---

## What is blocking launch

The bottleneck is a calendar, not the code. A Google personal developer account
must run a **closed test with 12 or more testers opted in for 14 consecutive
days** before it can apply for production. That clock has not started.

It needs: a release keystore (does not exist yet), a Play account with identity
verification, and one uploaded build. Nothing else shortens it, and most
remaining work can happen during the 14-day wait.

The quieter risk: with 3 courses in the catalogue, 12 testers will open the app
and find nothing to browse. Getting teachers to publish is probably the real
constraint on whether the test produces any signal at all.
