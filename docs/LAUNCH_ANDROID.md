# PadiLearn Android launch checklist

The working list for the first Google Play release. Tick an item by changing
`[ ]` to `[x]`.

Checked against this repo, the live Supabase project, and Google's Play Console
help pages on **2026-09-11**. Google changes these rules often; re-check anything
here that is more than a few months old.

---

## Start here: how paid courses can be sold on Android

**The in-app Paystack checkout can't ship on Google Play.** Play's Payments
policy requires apps that sell digital content used inside the app, such as
pre-recorded courses, to use Google Play Billing. It also bans pointing users
from inside the app to an outside payment page, whether by button, link,
WebView or message. `course_description_screen.dart` opens
`PaystackCheckoutScreen` for paid courses, which breaks both rules. Apple's
Guideline 3.1.1 says the same, so this isn't only an Android problem.

The fix is a business decision, not a code change:

| Option | What it means | What you keep on a NGN 5,000 sale | Work |
|---|---|---|---|
| **1. Free courses only for the beta** | Paid courses aren't sold in the app yet. No billing, no Paystack, no company registration needed. | NGN 0 (nothing is sold) | Hide the Buy button on paid courses |
| **2. App for watching only, buying on the web** | Students buy on a website and watch in the app. The app shows no price, Buy button or link to the website's checkout. | ~NGN 724 (unchanged) | Build a web checkout. It doesn't exist yet. |
| **3. Google Play Billing** | Purchases go through Google. Google charges a service fee (15% on your first USD 1M a year; check the current rate). | ~NGN 149 if teacher payouts stay the same | Fixed-price products, a separate way to reconcile Google's payouts with teacher earnings, and a new commission model |

**Recommended: run option 1 for the closed test.** The test is there to find out
whether teachers will publish and students will watch, and it doesn't need
money to answer that. Choose between 2 and 3 before the first real sale.

Breaking the Payments policy can get the app rejected or removed. Serious or
repeated violations can get the developer account terminated, and a solo
developer struggles to get a terminated account back.

---

## The critical path: a 14-day clock

Google personal developer accounts created after 13 November 2023 must run a
**closed test with at least 12 testers opted in for 14 days in a row** before
they can apply for production. That wait sets the launch date, so start it
early:

1. Create the release keystore and make a release build
2. Put the privacy policy online
3. Create the Play developer account and verify your identity
4. Fill in the App content declarations
5. Publish the closed test
6. Get 12 or more testers opted in (recruit 15 to 20)
7. **Wait 14 days.** Fix things and push new builds to the same track meanwhile.
8. Apply for production access
9. Wait for review (allow several days)
10. Release to production with a staged rollout

Most of the code work in section B can happen during step 7.

---

## A. Decisions

- [ ] **Payment path for Android** (see above). Recommended: free courses only for the closed test.
- [ ] **Personal or organisation Play account.** A personal account is available now, and the 14-day rule applies to it. An organisation account needs a D-U-N-S number, which in turn needs the registered company. If you are thinking of waiting for an organisation account to avoid the test, first check whether the test rule really exempts it.
- [ ] **Confirm the package name is final:** `com.dankamaInnoHu.padiLearn`. It can never be changed after the first upload.

---

## B. Code and build

### Must be done before the production review

- [x] **Payments, for the closed test.** Paid checkout is switched off (`kPaidCheckoutEnabled` in `lib/config/features.dart`). Paid courses show "Not available yet" and point nowhere else. Choosing the real payment path is still open in section A.
- [ ] **In-app account deletion.** *Live 2026-09-14: migration applied, function deployed with JWT verification on; not yet tested on a phone.* The `delete-account` edge function removes the user's storage files and then the auth user, and both profile screens have a "Delete account" tile. The migration keeps `transactions` (buyer set to null). A teacher with paying students is refused and sent to support. **Still to do:** test it with a throwaway student and a throwaway teacher. The *web* deletion page is in section D.
- [x] **Remove the fake popularity numbers.** *Done 2026-09-14: migration applied, counters now match the real rows (10 enrolments, 3 rated courses).* Cards and filters now read `rating_avg` / `rating_count` and show "New" when a course has no ratings. The migration recounts enrolments and ratings from real rows, and the seed no longer invents them.
- [ ] **Reporting for user content.** *Live 2026-09-14 (`content_reports` created); not yet tested on a phone.* Report a course from its page, or a comment from its menu, into `content_reports`. **Acting on reports is manual:** check open reports in the dashboard every day during the test, and add an email alert before production.
- [ ] **Release signing.** Release builds are currently signed with the debug key (`android/app/build.gradle`), and no keystore exists. Create an upload keystore. Keep its passwords in `android/key.properties` and make sure git ignores that file. Wire up `signingConfigs.release` and enrol in Play App Signing. **Back the keystore up somewhere other than this laptop.**
- [ ] **Password reset, end to end.** Add `padilearn://reset-callback` under Supabase's Redirect URLs, then test the whole flow on a real phone.
- [x] **Help & Support.** *Done 2026-09-14.* It opens an email to `hello@padilearn.com`, and copies the address if the phone has no mail app.
- [ ] **Error reporting.** *Code done 2026-09-14.* Sentry is wired into `main.dart` and only switches on when the build passes `--dart-define=SENTRY_DSN=...`. **Still to do:** create the Sentry project, add the DSN to release builds, and name Sentry in the privacy policy and the Data safety form (crash logs).
- [ ] **Build number.** `pubspec.yaml` has `version: 1.0.0+1`. Increase the number after `+` for every upload.
- [ ] **Commit your work.** About 67 files from this week are still uncommitted.

### Before taking real money (not needed for a free-only beta)

- [ ] **Paystack webhook** for `charge.success`. Today, if the app dies after a student pays but before it calls `verify-payment`, Paystack keeps the money and the student gets no enrolment.
- [ ] **Check Paystack's current fees** against `lib/utils/pricing.dart` and `verify-payment`, and update both together.

### Build and test on real phones

- [ ] `flutter build appbundle --release` succeeds. Release builds shrink the code with R8, which can break a plugin that works fine in debug.
- [ ] Install the release build from the internal testing track on at least **one low-end phone** and **one Android 15/16 phone using gesture navigation**. Check the nav bar, bottom sheets, dark mode in both directions, video playback and uploads.
- [ ] After uploading, open **App bundle explorer** in Play Console and confirm the app supports **16 KB memory pages**. This has been required since 1 November 2025 for apps targeting Android 15 or later. Flutter 3.38 supports it; a plugin's native code is what could fail.

### Already done (checked 2026-09-11)

- [x] **Target API level.** Play has required API 36 for new apps and updates since 31 August 2026. Flutter 3.38 defaults to target and compile SDK 36 (minimum 24), and `build.gradle` uses those defaults.
- [x] **The only permission requested is INTERNET.**
- [x] Written in code this week, still to be tested on a phone: nav bar clears the system navigation, dark mode, password-reset screen, owned-course labels and marketplace filtering.

---

## C. Supabase

- [ ] In **Authentication → URL Configuration**, set **Site URL** to `https://padilearn.com` and add both `padilearn://reset-callback` and `https://padilearn.com/email-confirmed` to **Redirect URLs**. A redirect that isn't listed silently falls back to the Site URL.
- [ ] Set up **custom SMTP** with Resend. *In progress 2026-09-14:* `hello@padilearn.com` is the sender and the templates are in `supabase/templates/`. DNS is now on Cloudflare. The DKIM record is published, but Resend's `send` and `rsend` CNAME records were missing when checked. Add them in Cloudflare as **DNS only** (grey cloud), then verify the domain in Resend.
- [ ] Turn on **leaked password protection**.
- [ ] Decide whether signups need **email confirmation**, and test signing up with that setting.
- [ ] **Back up the database yourself** before launch (for example with `pg_dump`). Don't count on the free plan's backups.
- [ ] Stay on the **free plan** for the closed test. Move to **Pro** before real students stream video.
- [ ] Not needed for the beta, but needed before growth: rewrite the RLS policies to use `(select auth.uid())`, and add the missing foreign-key indexes.

---

## D. Web presence and legal

- [x] **Domain.** `padilearn.com` bought 2026-09-14. The payment callback URL now uses it.
- [x] **Website on Cloudflare Pages.** *Live 2026-09-14 at https://padilearn.com and www (Pages project `padi-learn`, production branch `feat/launch-blockers` until merged to `main`).* DNS moved from Hostinger to Cloudflare (`autumn`/`kanye.ns.cloudflare.com`). Email stays on Hostinger: its MX, SPF, DMARC, DKIM (`hostingermail-a/b/c._domainkey`) and `autodiscover`/`autoconfig` records **must stay DNS only (grey cloud)**. When proxied, DKIM signing and mail-app setup break. The three pages below are at `/privacy`, `/delete-account` and `/terms`.
- [ ] **Privacy policy page.** *Live at https://padilearn.com/privacy (checked 2026-09-14). Before submitting to Play: read it through, name Sentry once crash reporting is on, and add the operator's legal name once decided.* Cover what you collect (see the table in section E), why, who processes it (Supabase, plus Paystack once payments exist), how long you keep it, how to delete it, and how to contact you. Write it once to satisfy both Play and Nigeria's Data Protection Act 2023.
- [x] **Account-deletion web page.** *Live at https://padilearn.com/delete-account (checked 2026-09-14): in-app steps, email request, and what is deleted and kept, matching the deployed function.* A form, or clear instructions for requesting deletion by email.
- [ ] **Terms of service.** *Drafted 2026-09-14 at `website/src/pages/terms.md`. The refunds and payouts section is a placeholder until paid courses launch.* Cover teacher-uploaded content (who owns it, what's banned, how takedowns work), refunds, and payouts.
- [x] **A support email address.** `hello@padilearn.com`. Also use it on the Play listing and in the privacy policy.

---

## E. Play Console

- [ ] Create the developer account (USD 25) and complete identity verification.
- [ ] Create the app: default language, type "app", free to download.
- [ ] Fill in the **App content** section:
  - [ ] Privacy policy URL
  - [ ] **App access.** Signing in is required, so give the reviewer a working **student** login and a working **teacher** login with a course on it.
  - [ ] Ads: none
  - [ ] Content rating questionnaire. Mention the user-generated content (comments and uploaded courses).
  - [ ] Target audience. Choose adult age groups unless you mean to serve children; including under-13s brings in Play's Families rules.
  - [ ] Data safety form, including the data-deletion questions (see the table below)
  - [ ] Financial features declaration. Read it and answer honestly. Collecting teachers' bank details so you can pay them is not the same as offering users a financial product.
  - [ ] Government, news and health declarations: no
- [ ] **Store listing:** app name (30 characters max), short description (80), full description (4,000), icon at 512×512, feature graphic at 1024×500, at least two phone screenshots, category Education, contact email.
- [ ] **Countries:** Nigeria to start.

### Data safety: what the app actually collects

Taken from the code and database schema:

| Play category | Where it's stored | Purpose |
|---|---|---|
| Name, email address | `profiles`, Supabase Auth | Account |
| User IDs | Supabase Auth | Account |
| Photos | `profile-images` bucket | Profile |
| Videos | `course-media` bucket (teachers) | App functionality |
| Other user-generated content | Comments, course text, ratings | App functionality |
| App interactions | Lesson progress | App functionality |
| Purchase history | `transactions` (once paid courses exist) | App functionality |
| Financial info: bank name, account number, account name | `payout_accounts` (teachers) | Paying teachers |

Data is encrypted in transit (HTTPS). The answer to "users can request deletion"
only becomes **yes** once account deletion in section B is built.

---

## F. Closed test

- [ ] Upload to **internal testing** first and install it yourself.
- [ ] Create the **closed testing** track and add testers by email list or Google Group.
- [ ] **Recruit 15 to 20 testers** so a few dropouts don't take you under 12. They need Google accounts on Android phones, have to opt in through the test link, and must stay opted in.
- [ ] **Keep 12 or more opted in for 14 days in a row.** A tester who opts out and back in starts their own 14 days again.
- [ ] Push fixes to the closed track during those 14 days.
- [ ] Collect feedback in one place, such as a form or a WhatsApp group. Play asks how the test went when you apply for production.

---

## G. Production

- [ ] Apply for production access in Play Console.
- [ ] Release with a **staged rollout** (for example 20% of users first), then widen it.
- [ ] Allow several days for review.

---

## H. First week live

- [ ] Check error reporting and Android vitals every day.
- [ ] Reply to every store review and support email.
- [ ] Compare Supabase egress and database size with `docs/COSTS.md`.

---

## Sources

- [Google Play Payments policy](https://support.google.com/googleplay/android-developer/answer/9858738)
- [Target API level requirements](https://support.google.com/googleplay/android-developer/answer/11926878)
- [Testing requirements for new personal developer accounts](https://support.google.com/googleplay/android-developer/answer/14151465)
- [Account deletion requirements](https://support.google.com/googleplay/android-developer/answer/13327111)
- [16 KB page size requirement (Android Developers Blog)](https://android-developers.googleblog.com/2025/05/prepare-play-apps-for-devices-with-16kb-page-size.html)
