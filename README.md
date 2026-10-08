# PadiLearn

PadiLearn is an educational marketplace app aimed at a Nigerian audience. Users sign up as **teachers** to publish video courses, or as **students** to browse, enrol in, and learn from them. Built with **Flutter** on the front end and **Supabase** (Auth, Postgres, Storage, Edge Functions) on the back end.

> **Status: onboarding the first tutors.** The web app ([app.padilearn.com](https://app.padilearn.com)) and a sideloaded Android APK are live; the app is not on a store yet. The catalogue is demo content from the house account, no real sale has been made, and live payments wait on the company Paystack account. Today's numbers and next steps are in [`docs/STATUS.md`](docs/STATUS.md).
>
> For the business model and the store-billing constraint, see [`docs/PRODUCT_OVERVIEW.md`](docs/PRODUCT_OVERVIEW.md). The checklists are [`docs/LAUNCH_WEB.md`](docs/LAUNCH_WEB.md), [`docs/LAUNCH_ANDROID.md`](docs/LAUNCH_ANDROID.md) and [`docs/ADMIN_PANEL.md`](docs/ADMIN_PANEL.md). [`docs/DEVLOG.md`](docs/DEVLOG.md) records why things are the way they are.

---

## Features

### Authentication & onboarding
- Email/password sign up and login via Supabase Auth, plus **Google** and **Apple** sign-in (native ID-token flow; the Google button hides itself until client IDs are configured).
- Role is **claimed**, not assumed — OAuth providers return an identity and nothing else, so a profile may exist with no role and the app answers with a role picker.
- Splash with session check, multi-page onboarding, forgot-password with a deep link back into the app.

### Students
- Dashboard of ongoing courses with saved progress, cached for **offline** viewing.
- Marketplace with live search and category filters; courses already owned are hidden from browsing but still findable by search.
- Course detail with a lesson list that doubles as the sales pitch — titles are public, videos are not.
- Video player (Chewie) with playback speed, fullscreen and resume-from-last-position.
- Per-course **comments** and **ratings**, and the ability to report a course or comment.

### Teachers
- Dashboard with analytics and earnings.
- Create and edit courses: upload video and thumbnail to Supabase Storage with progress, set title, description, price, category and lessons.
- A live earnings estimate while setting a price, showing what the student pays and what the teacher keeps.
- **Notifications** on new comments and enrolments, delivered by database triggers over realtime.
- Payouts: a verified bank account, a balance that counts the 7-day hold, refunds and payouts, payout requests from the app, and a history of what was sent. Transfers are sent by hand and recorded in the admin panel.

### Foundation
- Role-based navigation; the home shell loads the right screen set.
- **Row Level Security is the authorisation layer** — the app talks to Postgres directly with a publishable key, and anything that must not be client-decided lives in an Edge Function using the service role.
- In-app account deletion, removing storage objects and the auth user.
- A separate **admin app** (`lib/admin/main.dart`) at admin.padilearn.com, behind Cloudflare Access and a second factor: reports, users and suspensions, courses and takedowns, refunds, payouts, categories and an audit log. See `docs/ADMIN_PANEL.md`.
- Sentry error reporting, active only when a DSN is passed at build time.

---

## Payments

Courses are sold once, in NGN, through **Paystack**. The platform keeps **15%** of the list price.

The **card fee is fronted to the student**: a teacher's price is what settles, with Paystack's cut grossed up on top at checkout. On a course listed at NGN 5,000 the student pays NGN 5,178, Paystack takes NGN 178, PadiLearn keeps NGN 750 and the teacher earns NGN 4,250.

The gross-up exists in both `lib/utils/pricing.dart` and `supabase/functions/_shared/paystack.ts` because Dart cannot run in an Edge Function. **The two must agree exactly** — `initialize-payment` charges the total and `grantEntitlement` rejects anything under it. `test/pricing_test.dart` covers the maths.

**Where paid checkout is on** is decided by `kPaidCheckoutEnabled` in `lib/config/features.dart`, set per build: on for the web app and the APK handed out from padilearn.com, off for anything uploaded to Google Play. Google Play and Apple require store billing for digital content consumed in-app, and forbid pointing users to an outside checkout. The reasoning is in `docs/PRODUCT_OVERVIEW.md`.

---

## Tech stack

| Area | Choice |
|------|--------|
| Framework | Flutter (Dart SDK `>=3.4.3 <4.0.0`) |
| State management | [GetX](https://pub.dev/packages/get) |
| Backend | Supabase — `supabase_flutter` (Auth, Postgres, Storage, Edge Functions) |
| Payments | Paystack, via Edge Functions and a `webview_flutter` checkout |
| Auth providers | `google_sign_in`, `sign_in_with_apple` |
| Media | `video_player` + `chewie`, `image_picker` |
| Local storage | `shared_preferences` (video progress, offline course cache) |
| Errors | `sentry_flutter` |
| UI | `flutter_screenutil`, `google_fonts` — Poppins throughout, Playfair Display for occasional display text |
| Platforms | Android, iOS |
| Website | Astro 5 on Cloudflare Pages (`website/`) |

### Data model

Postgres, every table with RLS enabled:

| Table | Holds |
|---|---|
| `profiles` | name, email, role (`Student` \| `Teacher`, nullable until claimed), avatar |
| `courses` | title, description, price, category, thumbnail, owner, rating aggregates, archive state |
| `lessons` | ordered lessons per course; titles public, video paths not |
| `enrollments` | **the entitlement.** Its existence is what grants access |
| `lesson_progress` | per-user, per-lesson progress |
| `course_ratings`, `course_comments` | ratings and threaded comments (a teacher can pin) |
| `notifications` | written by triggers on comment and enrolment |
| `transactions` | the money ledger, keyed on the Paystack reference |
| `payout_accounts` | teacher bank details |
| `categories`, `content_reports` | taxonomy and moderation queue |

Schema lives in `supabase/migrations`; demo content in `supabase/seed`; auth email templates in `supabase/templates`.

### Edge Functions

| Function | Job |
|---|---|
| `initialize-payment` | Starts a Paystack transaction at the authoritative, server-computed amount |
| `verify-payment` | Confirms a payment the app asks about, then grants the entitlement |
| `paystack-webhook` | Does the same from Paystack's side, so fulfilment survives the app dying. **Deploy with `--no-verify-jwt`** — Paystack holds no JWT and the signature check is its only authentication |
| `get-course-video` | Signs a playback URL, only for an enrolled user |
| `payout-account` | Validates and stores teacher bank details |
| `delete-account` | Removes a user's storage objects and auth user |

---

## Project structure

```
lib/
├── main.dart                 # Entry, Supabase init, GetX bindings, theme, deep links
├── config/                   # supabase_config (gitignored), features, deep_links, web_links
├── controller/               # GetX controllers (courses, marketplace, user, teacher, enrollment…)
├── models/
├── services/                 # Supabase/Paystack access: auth, course, lesson, payment, comment…
├── screens/
│   ├── onboarding/           # Splash + onboarding
│   ├── login/ register/ forgot_password/
│   ├── home/                 # HomeShell + bottom nav
│   ├── marketplace/          # Marketplace + course cards/grid/list
│   ├── description/          # Course detail, purchase summary, enrolment
│   ├── payment/              # Paystack checkout WebView
│   ├── student/ teacher/     # Dashboards, course authoring, profiles
│   ├── notifications/
│   ├── videoplayer/ settings/
│   └── components/           # Shared widgets
└── utils/                    # colors, money, pricing, app_info, links, video_metadata

supabase/                     # migrations, edge functions, seed, email templates
website/                      # Astro site for padilearn.com
docs/                         # STATUS, DEVLOG, LAUNCH_WEB, LAUNCH_ANDROID, ADMIN_PANEL, REGION_MOVE, PRODUCT_OVERVIEW
```

---

## Getting started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (Dart `>=3.4.3`)
- Android Studio / Xcode with an emulator or a device
- A [Supabase](https://supabase.com/dashboard) project
- The [Supabase CLI](https://supabase.com/docs/guides/local-development), to push migrations and deploy functions

### 1. Clone and install
```bash
git clone <your-repo-url>
cd padi_learn
flutter pub get
```

### 2. Configure Supabase

> ⚠️ `lib/config/supabase_config.dart` is **gitignored** and not in the repo. Copy the template and fill it in:

```bash
cp lib/config/supabase_config.example.dart lib/config/supabase_config.dart
```

The URL and **publishable** key come from Dashboard → Project Settings → API. The publishable key is a client key whose access is fully constrained by RLS, so it is safe to ship; the `service_role` key must never go in this file.

Push the schema and deploy the functions:

```bash
supabase db push
```

```bash
supabase functions deploy paystack-webhook --no-verify-jwt
```

Remaining functions deploy normally with `supabase functions deploy <name>`. They expect `PAYSTACK_SECRET_KEY` and, optionally, `PLATFORM_FEE_PERCENT` (defaults to 15) as secrets.

In the dashboard, add every redirect the app uses to Authentication → URL Configuration, or Supabase silently falls back to the Site URL.

### 3. Google and Apple sign-in (optional)

Leave the client IDs in `supabase_config.dart` empty and the Google button hides itself rather than shipping one that fails. To enable it, create OAuth clients in **Google Cloud Console** (not Firebase) and list the Web client ID under Authentication → Providers → Google. Full walkthrough in `docs/LAUNCH_ANDROID.md`.

### 4. Run
```bash
flutter run
```

### Release builds

`android/key.properties` (gitignored) holds the upload keystore details — copy `android/key.properties.example`. Without it the release build still signs with the debug key and says so in the build log, so a fresh clone keeps working but cannot upload to Play.

---

## Troubleshooting

**`supabase_config.dart` not found**
You skipped step 2. Copy the example file and fill it in.

**Google sign-in returns no ID token**
Almost always configuration. On Android the token is only issued when `serverClientId` matches a Web client whose SHA-1 covers the signing key in use — debug builds fail until the debug keystore's fingerprint is registered too.

**Build fails: `paging file is too small` / `insufficient memory for the Java Runtime`**
The Gradle JVM heap is set in `android/gradle.properties` (`org.gradle.jvmargs`). Lower it (e.g. `-Xmx1536m`), close other heavy apps, run `cd android && ./gradlew --stop`, and/or increase the Windows paging file, then retry.

**App hangs on a loading spinner after login**
A session exists with no matching `profiles` row. The home shell clears the stale session and returns to login. Note that a profile with a **null role** is not a dead session — it is a Google or Apple signup that has not picked a role yet, and the app answers with the role picker.

**A paid course does not unlock after payment**
Check the `transactions` ledger for the Paystack reference. Enrolment is granted by `verify-payment` or `paystack-webhook`, never by the client, so a missing enrolment with a successful transaction points at those functions — confirm the webhook was deployed with `--no-verify-jwt`.

---

## Tests

```bash
flutter test
```

Covers the pricing split, money formatting, navigation-bar placement against the system nav, and marketplace filtering. There is no CI yet.

---

## License
Private project — not currently licensed for redistribution.
