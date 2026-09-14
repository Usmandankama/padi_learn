# PadiLearn cost register

What we pay, what we will pay, and what each number depends on. Kept next to
[DEVLOG.md](DEVLOG.md) and versioned with the code, because several of these
figures are mirrored in the app (`lib/utils/pricing.dart`) and drift silently
otherwise.

**How to maintain it:** update *Actual spend* monthly when invoices land. When a
third-party price changes, update the line **and** its `checked` date. Every
external price below carries one — treat any figure older than a quarter as
unverified, because none of these vendors are obliged to keep their pricing
still.

**Currency:** vendor prices are quoted in the currency the vendor bills in.
Do not bake an NGN conversion into this file — the rate moves too fast to keep
honest. Convert at the point of decision and record the rate you used.

---

## 1. Where we are today (2026-09-03)

Measured off the live project, not estimated:

| Resource | Now | Free-tier allowance | Headroom |
|---|---|---|---|
| Database | 13 MB | ~500 MB | Very large |
| Storage (all buckets) | 22 MB | ~1 GB | Very large |
| Egress | negligible | ~5 GB / month | **This is the one that breaks** |
| Courses / lessons | 15 / 47 | — | Seed data |
| Profiles / enrolments / transactions | 4 / 8 / 1 | — | Seed data |

Storage splits as `course-media` 20 MB (11 objects), `course-thumbnails`
1.9 MB (15), `profile-images` 15 kB (1).

**Current cash cost: nothing.** Everything is on free tiers. That is also the
problem — see section 2.

### The one number that matters

Those 11 demo clips average about 1.8 MB. They are *demos*. The source material
in `video/` is 779 MB, and a real hour-long course at watchable quality is
300 MB to 1 GB.

Egress is charged on every byte a student watches, every time. So:

- A 500 MB course watched once = 500 MB egress.
- A ~5 GB/month free allowance = **roughly 10 course-views per month.**
- A ~250 GB/month Pro allowance = **roughly 500 course-views per month.**

500 course-views is a few hundred students. This is why video has to leave
Supabase Storage before real traffic, and why storage size is a red herring —
we will never run out of storage, we will run out of egress. See section 5.

---

## 2. Committed before launch

Unavoidable, and none of it is usage-dependent.

| Item | Cost | Cadence | Checked | Notes |
|---|---|---|---|---|
| Google Play developer account | USD 25 | one-off, lifetime | 2026-09-03 | Verify. Required to publish at all |
| Apple Developer Program | USD 99 | per year | 2026-09-03 | Verify. Required for App Store *and* TestFlight |
| Supabase Pro | ~USD 25 | per month, per org | 2026-09-03 | Verify. Not needed for a small closed beta. Needed before real students stream video: the free egress allowance is unusable for video, and free projects pause after about a week idle |
| Transactional email (SMTP) | USD 0 to start | per month | 2026-09-03 | Supabase's built-in SMTP is rate-limited and not for production. Resend / SES / Postmark all have free tiers that cover launch volume |
| Domain | ~USD 10-15 | per year | 2026-09-03 | Needed for the privacy policy and account-deletion URLs the stores require |
| Privacy policy + deletion page hosting | USD 0 | — | 2026-09-03 | Static page; can live on the domain above |

**Android-first one-offs: ~USD 25 (Play) + domain.** Apple's USD 99 a year only applies once iOS ships.
**Fixed monthly floor: USD 0 for a small closed beta on free tiers; ~USD 25 once real students are streaming video.**

---

## 3. Per-transaction cost (already encoded in the app)

The authoritative split lives in the `verify-payment` edge function; the
client-side mirror is `lib/utils/pricing.dart`. **If a rate below changes, both
must change.**

| Constant | Value | Where |
|---|---|---|
| Platform commission | 15% of the settled amount | `kPlatformFeePercent` |
| Paystack percentage | 1.5% | `_paystackPercent` |
| Paystack flat fee | NGN 100, waived under NGN 2,500 | `_paystackFlatFee` |
| Paystack fee cap | NGN 2,000 | `_paystackFeeCap` |

`pricing.dart` says in its own comments: *"VERIFY AGAINST CURRENT PAYSTACK
RATES."* That has not been done. Do it before launch — every figure below
depends on it.

### What a sale actually yields

Computed with the code's own rounding:

| List price | Paystack takes | Settles | Platform keeps | Teacher gets | Platform share of list |
|---|---|---|---|---|---|
| NGN 1,000 | 15 | 985 | 148 | 837 | 14.8% |
| NGN 2,499 | 37 | 2,462 | 369 | **2,093** | 14.8% |
| NGN 2,500 | 138 | 2,362 | 354 | **2,008** | 14.2% |
| NGN 5,000 | 175 | 4,825 | 724 | 4,101 | 14.5% |
| NGN 10,000 | 250 | 9,750 | 1,463 | 8,287 | 14.6% |

Compare rows two and three: raising the price by **NGN 1** costs the teacher
**NGN 85**, because Paystack's flat fee starts at 2,500. The app already warns
about this (`PriceBreakdown.isInFeeDeadZone`).

**Rule of thumb: we keep about 14.5% of list price.**

> **This only holds for sales made outside the app store.** Google Play's
> Payments policy requires Play Billing for digital content sold inside the
> app, and Apple's Guideline 3.1.1 requires IAP. The current in-app Paystack
> checkout breaks both. Sold through Play Billing, a store service fee (15% on
> the first USD 1M a year; verify) comes off the top, which on a NGN 5,000
> course leaves roughly NGN 149 if teacher payouts stay the same. See
> `docs/LAUNCH_ANDROID.md`.

---

## 4. Break-even

Fixed monthly floor is ~USD 25 (Supabase Pro) until video moves, then Pro plus
video delivery.

At ~14.5% of list, the monthly sales needed to cover USD 25 — fill in the rate
you actually get, because this moves:

```
sales needed  =  (25 x NGN_per_USD)  /  (avg_price x 0.145)
```

At an average price of NGN 5,000 that is `25 x rate / 724`. Record the rate used
and the resulting number each month rather than trusting a stale figure:

| Month | NGN/USD used | Avg price | Sales to break even | Actual sales | Covered? |
|---|---|---|---|---|---|
| _(fill in)_ | | | | | |

This ignores video delivery, which grows with usage rather than sitting flat.
Once section 5 is decided, add it to the numerator.

---

## 5. Usage-scaling costs (the ones that actually grow)

### Video delivery — the decision to make

Currently Supabase Storage, which is the wrong tool at any real volume: no
transcoding, no adaptive bitrate, and egress billed at general-purpose rates.
For students on Nigerian mobile data, no adaptive bitrate also means buffering,
which costs retention before it costs money.

Two candidates, both priced per stored minute plus per delivered minute or GB
rather than per general-purpose GB:

| Option | Model | Checked | Notes |
|---|---|---|---|
| Cloudflare Stream | per minute stored + per minute delivered | — | **Get a current quote.** Simplest; encoding and player included |
| Bunny Stream | per GB delivered + encoding | — | **Get a current quote.** Usually cheaper per GB; more configuration |
| Supabase Storage (today) | per GB egress | 2026-09-03 | Fine for thumbnails; wrong for video |

Decide before real traffic — migrating video after students have enrolled is
much harder than before. Thumbnails and profile images should stay on Supabase
Storage regardless; they are small and already integrated.

### Everything else that scales

| Driver | Grows with | Watch for |
|---|---|---|
| Database size | courses, enrolments, comments, notifications | Slow. Not a concern for years |
| Supabase egress | API responses plus any media still on Storage | Falls sharply once video moves |
| Realtime connections | concurrent active users | Capped per plan. `MarketplaceController` currently subscribes every user to the whole `courses` table — see DEVLOG |
| Edge function invocations | payment initialise/verify, video URL requests | One or two per purchase; cheap |
| Email | signups and password resets | Free tiers cover launch comfortably |
| Push (FCM) | not yet implemented | Free at our scale |

---

## 6. Actual spend log

The point of this file. Record what was really billed, not what was forecast.

| Month | Supabase | Video host | Email | Domain | Stores | Other | Total (USD) | Notes |
|---|---|---|---|---|---|---|---|---|
| 2026-09 | 0.00 | — | — | — | — | — | **0.00** | Everything still on free tiers; pre-launch |

---

## 7. Open questions

- [ ] Verify Paystack's current rates against section 3 and update `pricing.dart` **and** `verify-payment` together.
- [ ] Confirm Supabase Pro pricing and the free-tier limits quoted in section 1.
- [ ] Price Cloudflare Stream against Bunny Stream at a realistic assumption (say 200 courses x 45 min, 2,000 views/month) and record both quotes here.
- [ ] Decide the Supabase region. The project is in `ap-south-1` (Mumbai) for a Nigerian audience; moving is a project migration, not a setting, and it is cheapest to do with 4 profiles in the database.
- [ ] Is 15% the right commission? It is currently a constant in two places with no analysis behind it.
- [ ] Decide how paid courses are sold on Android without breaking Play's billing rules: free-only beta, web checkout with no in-app links to it, or Play Billing at a store fee. The commission question above depends on the answer.
