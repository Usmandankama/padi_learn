# Where PadiLearn stands

A snapshot, not a plan. **Last updated 9 October 2026.** The checklists live
in `LAUNCH_WEB.md`, `LAUNCH_ANDROID.md` and `ADMIN_PANEL.md`. `DEVLOG.md`
says why things are the way they are. When this page and a checklist
disagree, trust the checklist and fix this page.

---

## The phase we are in: first tutors

**Out of beta since 8 October 2026.** The web app at app.padilearn.com and
the Android APK at dl.padilearn.com are the product, not a test, and
PadiLearn presents itself as taking payments. The website's terms, refund
policy, support page and privacy policy say so. Email, password reset and
account deletion have been confirmed working. Real money still waits on the
Paystack switch below; until then the deployed payment functions are the
June ones. What is missing is **teaching that
anyone made for real**. The next step is to recruit a few tutors, show them
the product, and onboard the ones who will publish.

Students come after that. The catalogue a student would see today is a
demo: 13 courses, all from the house "PadiLearn" account, whose 123 lessons
share 14 short clips of about 18 seconds each.

### Numbers on the live project (8 October 2026)

| | |
|---|---|
| Accounts | 7 (3 teachers, 4 students) |
| Courses | 13 live, 12 free; all by the house account |
| Lessons | 123, using 14 distinct videos (50 MB in storage) |
| Enrolments | 2 |
| Transactions | 1, Paystack **test mode** |
| Payout accounts | 0 |
| Supabase | Free plan. Ireland project `bouhrbjdxxqeylrxxmdl`, in the company account's organisation (9 October); Mumbai kept until the switch-over is checked |

---

## Before showing tutors the product

1. **Move the project to Ireland** (`REGION_MOVE.md`), before tutors start
   using it. Every request from Nigeria to Mumbai pays about 350 ms.
   **Supabase stays on the free plan until there are users** (Usman's
   decision, 8 October). That means: tell tutors to keep each lesson under
   50 MB (short, compressed 720p, split if long); the keep-alive workflow
   stops the project being paused; `tool/region_move/dump.sh` is the backup;
   leaked-password protection stays off.
2. **Keep "Test 15" until the payment test below is done, then archive it.**
   It is a NGN 5,000 development course with a cat photo, live in the
   marketplace. It is also the only paid course, which is why it is useful
   for the test.
3. **Be ready to explain payouts.** Teachers keep 85% of their price, a sale
   clears after 7 days, and from 8 October they ask for payouts in the app
   (Profile → Payouts, or "Get paid" on the earnings card). Transfers are
   still sent by hand and recorded in the admin panel.

---

## Payments: what stands between us and live money

A **company Paystack account** now exists, **approved on 9 October**. The
switch is happening on the Ireland project, together with the region move:
Ireland has no traffic until the apps point at it, so its functions can be
the new ones from the start while Mumbai keeps the June ones. In order:

| # | Step | Who |
|---|---|---|
| 1 | ~~Complete Paystack's compliance for a registered business (checklist below).~~ Approved 9 October. | Usman |
| 2 | In the **new** account: Settings → Preferences → transaction fees paid by **the business**. The code adds the card fee itself, so "customer pays" would charge it twice. | Usman |
| 3 | In the new account's API Keys & Webhooks: webhook URL `https://bouhrbjdxxqeylrxxmdl.supabase.co/functions/v1/paystack-webhook` (the Ireland project), callback URL `https://app.padilearn.com/payment-callback`. | Usman |
| 4 | Put the new account's **test** secret key in the **Ireland** project's Edge Functions → Secrets as `PAYSTACK_SECRET_KEY`. | Usman |
| 5 | ~~Deploy `initialize-payment`, `verify-payment` and `paystack-webhook` together, the webhook with JWT verification off.~~ Done on Ireland, 9 October, from the repo as of `a56e7d9`. | Claude |
| 6 | ~~Test-mode purchase of "Test 15", then once more with only the webhook to grant the course.~~ Done on Ireland, 9 October, with two throwaway students against the functions directly: charged NGN 5,178 (5,000 + card fee); split Paystack 177.67, PadiLearn 750.05, teacher 4,250.28; verify path and webhook-only path both recorded the sale and enrolled the student. The first webhook try failed because the test-mode webhook URL was not saved in Paystack. The app's own checkout screens are checked after the switch-over, still on the test key. | Usman and Claude |
| 7 | Publish the website's customer policies (8 October): terms with section 6, `/refunds`, `/support`, privacy, footer and FAQ, all naming Groundwork Tech Ltd. Paystack's reviewers read the website. | Push to `main` |
| 8 | Once Paystack approves the account: swap in the **live** secret key and repeat step 3 for live mode. | Usman |
| 9 | Delete the test-mode rows from `transactions`, and the enrolments they granted, so test money never shows up as a teacher's balance. Then archive "Test 15". | Claude, on request |

Steps 2 to 4 must be done before the apps point at Ireland. Mumbai's
`initialize-payment` dates from June, charges the bare list price and falls
back to a callback domain PadiLearn does not own. Ireland's adds the card
fee, so pairing it with a "customer pays" setting double-charges. Step 6 can
run before the switch-over, from a local build pointed at Ireland.

### Paystack compliance, registered business

From Paystack's help centre, checked 8 October 2026. Confirm on the
dashboard's Compliance page, which is the authority.

- **Profile and contact:** business name and description, address, phone,
  support email (`hello@padilearn.com`), website (`padilearn.com`).
- **Documents:** certificate of incorporation, RC number, Form CAC 2
  (share capital), Form CAC 7 (directors), memorandum and articles, and the
  company's TIN.
- **People:** each director's details, with BVN consent given through
  NIBSS's iGree page. Also the people who together own at least 50%, which
  is you. Paystack's page asks for "at least two directors". The company has
  one, which CAMA 2020 allows for a small company. If the form insists,
  ask support@paystack.com rather than adding anyone.
- **Proof of address:** a recent utility bill.
- **Settlement account:** a bank account **in the company's name**.
- **Describe the model plainly:** an online course marketplace that collects
  payments and pays teachers their share by bank transfer. Paystack treats
  collecting on others' behalf differently from selling your own goods, so
  saying it up front is better than being asked later.

---

## The Supabase account

Done on 8 October: the project moved into the **"GroundworkTech"**
organisation. It stays on the **free plan** until PadiLearn has users. The
upgrade, when it comes, is Billing → Pro on that organisation (USD 25 a
month), paid with the company's card and TIN on the invoices, and nothing
else changes. Still worth doing now: invite `hello@padilearn.com` as a
second Owner, and turn on MFA for both logins.

## Moving out of Mumbai

A project's region is fixed when it is created, so moving means a new project
in Ireland and a copy of everything. The runbook, with scripts in
`tool/region_move/`, is **`REGION_MOVE.md`**. It works on the free plan.

Measured from Usman's laptop on 8 October, best of five TCP connects to each
AWS region: Mumbai 347 ms, London 163 ms, Paris 169 ms, Frankfurt 180 ms,
Ireland 201 ms, Cape Town 132 ms. A request to the current project takes
430 to 510 ms to its first byte. **Target: Ireland (`eu-west-1`)**, project
`bouhrbjdxxqeylrxxmdl` in the company account's organisation. London was the
first choice; on 9 October the two timed the same (Ireland 174 ms, London
186 ms), and Usman kept Ireland.

## Customer policies (decided 8 October)

On the website, with the numbers kept in `website/src/site.ts`:

- **Operator:** Groundwork Tech Ltd, Nigeria. Only the name and
  `hello@padilearn.com` are published; the RC number and address can be
  added to `site.company` later.
- **Support:** reply within 2 working days, Monday to Friday except public
  holidays (`/support`).
- **Refunds** (`/refunds`): no returns, since courses are digital. Charged
  without access, or charged twice: access or a refund. Course removed by us:
  full refund, card fee included. Not as described: within 7 days, reviewed.
  Unfixable playback fault: refund. Approved refunds are sent within 5 working
  days. Escalation: FCCPC (consumer), NDPC (data).
- **Teachers:** 85%, a 7-day hold, payouts on request from NGN 1,000, sent
  within 5 working days, 30 days' notice before the commission changes.

## Decisions waiting on Usman

- **Refunds outside takedowns.** The terms promise them for double charges
  and not-as-described courses, but the admin panel can record a refund only
  for a taken-down course. Until that is extended, refund in Paystack and
  record it in `refunds` by hand. Proposed split: the same as a takedown
  (the student gets everything back, the teacher loses that sale's share,
  PadiLearn absorbs the fee).
- **Payout minimum.** NGN 1,000, set in `payout_minimum()`.

## Still open from the checklists

- Course reporting from the player: added 8 October; test it on a phone.
- Sentry: wired in, but no DSN in either CI build, so crashes go unseen.
- Database backups: none taken yet. Run `tool/region_move/dump.sh` (it doubles as the backup script).
- Supabase region is Mumbai until `REGION_MOVE.md` is done.
- Google sign-in: no OAuth clients yet. Email and password work.
- `padilearn-admin.pages.dev` still serves the admin sign-in page without
  Cloudflare Access (`ADMIN_PANEL.md`, item 14).
- Play Store: blocked on the D-U-N-S number, or a personal account and its
  14-day closed test. The web app and the APK cover distribution meanwhile.
- The landing page's Android screenshots predate the real catalogue and
  show invented ratings and prices.
