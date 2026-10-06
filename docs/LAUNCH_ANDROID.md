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

**Why Glovo and Bolt can use Paystack and PadiLearn cannot.** The policy covers
only digital content consumed inside the app. Physical goods and real-world
services are exempt, which accounts for every Nigerian app that looks like a
counter-example: Glovo and Jumia deliver goods, Bolt sells an actual car
journey, Kuda and PiggyVest are financial services. PadiLearn sells video
watched in the app, so the right comparison is Netflix and Spotify — neither
of which lets you subscribe inside their Android app at all. They removed the
purchase rather than pay the fee, and they do not link out either, because
that is banned too.

Enforcement is uneven, so you will find Nigerian edtech apps seemingly taking
card payments for digital courses. Some are exempt for reasons not visible from
outside, some sell in-person tutoring, and some are in breach and have not been
caught. It is enforced on report, on review of an update, or once you are big
enough to notice — not by audit. "They got away with it" is not a defence when
it is your account being terminated.

**And why Spotify and Netflix now show a "See plans" link.** That link-out is
recent and rests on two things PadiLearn does not have. First, jurisdiction:
the April 2025 Epic v. Apple injunction stopped Apple charging commission on
external links **in the US**, the EU's DMA forced the same there, and Epic v.
Google did it to Play. Nigeria is covered by neither remedy, and storefronts
differ by region, so a US build is no guide. Second, Apple's **reader app**
entitlement, a global carve-out for apps that exist to consume content bought
elsewhere — books, music, video. Netflix and Spotify are its archetype;
a marketplace with uploads, comments and progress tracking is a stretch, the
entitlement must be applied for, and **Google has no equivalent**, so it would
not help on Android at all.

Check the live policy text before building against any of this: it is moving
quickly, appeals are outstanding, and a competitor's app is evidence of their
legal position, not of what is permitted to you. Two things worth confirming:
whether Google's user-choice billing (a reduced fee, not 15%) covers Nigeria
yet, and whether Play's anti-steering rules still apply here in full.

The fix is a business decision, not a code change:

| Option | What it means | What you keep on a NGN 5,000 sale | Work |
|---|---|---|---|
| **1. Free courses only for the beta** | Paid courses aren't sold in the app yet. No billing, no Paystack, no company registration needed. | NGN 0 (nothing is sold) | Hide the Buy button on paid courses |
| **2. App for watching only, buying on the web** | Students buy on a website and watch in the app. The app shows no price, Buy button or link to the website's checkout. | ~NGN 724 (unchanged) | Build a web checkout. It doesn't exist yet. |
| **3. Google Play Billing** | Purchases go through Google. Google charges a service fee (15% on your first USD 1M a year; check the current rate). **Confirm first that Nigeria is a supported merchant country for Play payouts** — if a payments profile cannot be opened from Nigeria, this option is closed regardless of the fee. | ~NGN 149 if teacher payouts stay the same | Fixed-price products, a separate way to reconcile Google's payouts with teacher earnings, and a new commission model |

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

- [x] **Payment path for Android.** *Decided 2026-10-05: option 2, split by how a build is distributed.* `kPaidCheckoutEnabled` is a `--dart-define` rather than a platform constant, because the Play Payments policy binds apps *distributed through Play*, not the source:

  | Build | Command | Paystack in-app |
  |---|---|---|
  | Direct APK, from padilearn.com | `flutter build apk --release --split-per-abi --dart-define=PAID_CHECKOUT=true` | **on** |
  | Web | `flutter build web --release` | **on** (the default on web) |
  | Anything uploaded to Play, closed test included | `flutter build appbundle --release` | **off** (the default on mobile) |

  **Never pass `PAID_CHECKOUT=true` to a build that goes to Play**, the closed test included — that is the violation that terminates developer accounts.
- [ ] **Personal or organisation Play account.** A personal account is available now, and the 14-day rule applies to it. An organisation account needs a D-U-N-S number, which in turn needs the registered company. If you are thinking of waiting for an organisation account to avoid the test, first check whether the test rule really exempts it.
- [x] **Package name is final:** `com.padilearn.app`. *Changed 2026-09-16 from `com.dankamaInnoHu.padiLearn`, before any upload.* It can never be changed after the first upload. The tester opt-in URL is `play.google.com/apps/testing/com.padilearn.app`.

---

## B. Code and build

### Must be done before the production review

- [x] **Payments, for the closed test.** Paid checkout is switched off (`kPaidCheckoutEnabled` in `lib/config/features.dart`). Paid courses show "Not available yet" and point nowhere else. Choosing the real payment path is still open in section A.
- [ ] **In-app account deletion.** *Live 2026-09-14: migration applied, function deployed with JWT verification on; not yet tested on a phone.* The `delete-account` edge function removes the user's storage files and then the auth user, and both profile screens have a "Delete account" tile. The migration keeps `transactions` (buyer set to null). A teacher with paying students is refused and sent to support. **Still to do:** test it with a throwaway student and a throwaway teacher. The *web* deletion page is in section D.
- [x] **Remove the fake popularity numbers.** *Done 2026-09-14: migration applied, counters now match the real rows (10 enrolments, 3 rated courses).* Cards and filters now read `rating_avg` / `rating_count` and show "New" when a course has no ratings. The migration recounts enrolments and ratings from real rows, and the seed no longer invents them.
- [ ] **Reporting for user content.** *Live 2026-09-14 (`content_reports` created); not yet tested on a phone.* Report a course from its page, or a comment from its menu, into `content_reports`. **Acting on reports is manual:** check open reports in the dashboard every day during the test, and add an email alert before production.
- [x] **Release signing.** *Keystore created 2026-10-05.* `C:\Users\USMAN\keystores\padilearn-upload.jks`, alias `padilearn-upload`, RSA 2048, valid to 2054-02-20. Passwords live in the git-ignored `android/key.properties`. Upload-key fingerprints, for the Google OAuth clients: SHA-1 `B2:3C:84:36:C2:8E:8F:DC:4F:93:3B:BD:49:B9:13:61:4F:30:1F:09`, SHA-256 `B8:FB:A3:29:B0:97:8E:FA:62:E6:45:D1:70:41:BA:06:BD:E5:97:CA:73:49:0D:F3:59:AC:FA:62:8A:87:DC:94`. **Neither the .jks nor key.properties is in git, and neither exists anywhere but this laptop. Copy both off it now** — lose them and this app can never be updated again. *Gradle side done 2026-09-16:* `signingConfigs.release` reads `android/key.properties`, which is git-ignored (as are `*.jks` / `*.keystore`); `key.properties.example` shows the shape. Without that file the build still falls back to the debug key and says so, so a fresh clone keeps working. **Still to do:** run `keytool` to create the upload keystore, write the real `key.properties`, and enrol in Play App Signing. **Back the keystore up somewhere other than this laptop** — lose it and the app can never be updated again.
- [ ] **Password reset, end to end.** Add `padilearn://reset-callback` under Supabase's Redirect URLs, then test the whole flow on a real phone.
- [x] **Help & Support.** *Done 2026-09-14.* It opens an email to `hello@padilearn.com`, and copies the address if the phone has no mail app.
- [ ] **Error reporting.** *Code done 2026-09-14.* Sentry is wired into `main.dart` and only switches on when the build passes `--dart-define=SENTRY_DSN=...`. **Still to do:** create the Sentry project, add the DSN to release builds, and name Sentry in the privacy policy and the Data safety form (crash logs).
- [ ] **Build number.** `pubspec.yaml` has `version: 1.0.0+1`. Increase the number after `+` for every upload.
- [ ] **Commit your work.** About 67 files from this week are still uncommitted.

### Before taking real money (not needed for a free-only beta)

- [ ] **Paystack webhook** for `charge.success`. *Written 2026-09-17, not deployed and not type-checked* (no Deno or Supabase CLI on this machine). `supabase/functions/paystack-webhook` verifies Paystack's HMAC SHA-512 signature in constant time, re-asks Paystack what happened, then fulfils through the new `supabase/functions/_shared/paystack.ts`, which `verify-payment` now calls too — one copy of the fee split, so the two paths cannot drift. Both writes stay idempotent, so app and webhook may race or repeat safely. A 500 asks Paystack to redeliver, a 200 closes cases retrying could never fix. **Still to do:** `supabase functions deploy paystack-webhook --no-verify-jwt` (Paystack holds no JWT, so the signature check is the only authentication — deploying it *with* JWT verification silently breaks every delivery), redeploy `verify-payment` since it changed, set the webhook URL in Paystack's dashboard to `https://<project>.supabase.co/functions/v1/paystack-webhook`, then test with a real payment and with a deliberately killed app. Note the shared directory means these must go up with the CLI, not pasted into the dashboard editor.
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

- [x] **Authentication → URL Configuration.** *Done 2026-09-16:* Site URL is `https://padilearn.com`, and both `padilearn://reset-callback` and `https://padilearn.com/email-confirmed` are in the Redirect URLs allow list. Verified against the code — those are the only two the app asks for (`deep_links.dart`, `web_links.dart`), the Android intent filter matches the scheme and host, and all four site pages return 200. A redirect that isn't listed silently falls back to the Site URL.
- [ ] Set up **custom SMTP** with Resend. *DNS complete 2026-09-16:* `send` and `rsend` now resolve to Resend (`forge.rmta.net`), DKIM is published at `resend._domainkey` with `d=padilearn.com` so DMARC aligns on DKIM, and `send.padilearn.com` carries Resend's SPF — the root SPF correctly still lists only Hostinger, because Resend's envelope sender is the `send` subdomain. MX is untouched, so inbound mail to `hello@padilearn.com` still goes to Hostinger. **Still to do:** confirm the domain shows Verified in Resend, point Supabase Auth's SMTP settings at Resend, and send a real reset and a real signup to prove it end to end — correct DNS does not mean Supabase is using it.
- [ ] Turn on **leaked password protection**.
- [ ] Decide whether signups need **email confirmation**, and test signing up with that setting.
- [ ] **Back up the database yourself** before launch (for example with `pg_dump`). Don't count on the free plan's backups.
- [ ] Stay on the **free plan** for the closed test. Move to **Pro** before real students stream video.
- [ ] Not needed for the beta, but needed before growth: rewrite the RLS policies to use `(select auth.uid())`, and add the missing foreign-key indexes.

### Google sign-in

- [ ] **On Supabase's Google provider page, only "Client IDs" matters.** The app uses the **native** flow (`GoogleSignIn.authenticate()` → `signInWithIdToken`, `auth_service.dart`), never the web redirect, so leave **Client Secret** and **Callback URL** alone — both belong to `signInWithOAuth`. Leave **Skip nonce checks** off (`google_sign_in` puts no nonce in the token, so the check passes; turn it on only if iOS later fails with a nonce error) and **Allow users without an email** off. Supabase validates the token's `aud` claim against the Client IDs list: on Android `aud` is the **Web** client ID, because Android passes it as `serverClientId`; on iOS it is the **iOS** client ID. The Android client ID is never listed there.
- [ ] **A plain Google Cloud project — not Firebase.** Nothing runs on Google Cloud: no hosting, no database, no billing account. The only artifact is an OAuth client, which is a registration record saying an app with this package and this signing certificate may ask Google for ID tokens. Firebase is a layer over the same Google Cloud project and would create the same clients, which is why every tutorial reaches for it, but it would also drag `google-services.json` and the Firebase Gradle plugin back into a build that has been free of both since the move to Supabase. Use console.cloud.google.com → APIs & Services → Credentials. **The project already exists:** `padilearn`, created by Firebase in 2024 and orphaned by the move to Supabase. Reuse it — it holds no OAuth clients, so there is nothing to collide with. Its three leftover Firebase API keys are referenced by no code in this repo (the string `AIza` appears nowhere) and can be deleted once sign-in works; Credentials → Restore deleted credentials undoes that for 30 days. The `firebase-adminsdk` service account still has admin rights to the old project, so revoke any JSON key ever downloaded for it.
- [ ] **Configure the OAuth consent screen first** (newer consoles call it Google Auth Platform → Branding); no client can be created until it exists. App name, support email, and `padilearn.com` as the authorised domain. **Then publish it.** Left in *Testing*, only manually-added test users can sign in at all and their refresh tokens expire after seven days — a slow failure that looks like a bug in the app. The app asks only for `email`, `profile` and `openid`, which Google treats as non-sensitive, so publishing to production is instant and needs no verification review.
- [ ] **Three OAuth clients in Google Cloud Console.** **Web** — its ID goes both in Supabase's Client IDs and in `googleWebClientId` in the git-ignored `lib/config/supabase_config.dart`, which is empty today, which is why the button is hidden rather than broken (`isGoogleSignInConfigured`). **Android** — package `com.padilearn.app`, no secret, never listed in Supabase, but without it Google issues no ID token at all. **iOS** — later; its ID goes in the Supabase list and in `googleIosClientId`. **Any client created before 2026-09-16 under `com.dankamaInnoHu.padiLearn` is void**, because the package rename orphaned it.
- [ ] **The Android client needs every signing certificate, not just this laptop's.** Debug SHA-1 here is `17:B5:FB:AD:FC:1B:CC:9C:01:70:15:D4:D2:4E:7B:6E:CD:DB:77:7F` (valid to 2054); register it or sign-in fails in development. The upload keystore does not exist yet — see **Release signing** in section B — so its fingerprint cannot be added until it does. **The one that catches people:** under Play App Signing the build testers install is re-signed with *Google's* key, not the upload key. And **an Android OAuth client holds exactly one package name plus one SHA-1** — unlike Firebase, where one app carried a list of fingerprints — so every certificate needs a client of its own: name them `PadiLearn Android (debug)`, `(upload)` and `(Play App Signing)` or you will be guessing later. Take the third fingerprint from Play Console (Test and release → Setup → App signing, shown in newer consoles as Protected with Play → Play Store protection → Manage Play app signing). Miss it and Google sign-in works on every build you make by hand and fails for all 15 testers.
- [ ] **Two loose ends in the app itself.** `assets/branding/google_logo.png` is absent — the button falls back to text, which ships fine but breaks Google's branding rules. `ios/Runner/Info.plist` has no `CFBundleURLTypes` block, so iOS sign-in cannot return to the app until the reversed iOS client ID (`com.googleusercontent.apps.…`) is registered as a URL scheme.

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
