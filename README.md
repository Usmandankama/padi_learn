# PadiLearn

PadiLearn is an educational marketplace app aimed at a Nigerian audience. Users can sign up as **teachers** to create and sell video courses, or as **students** to browse, enrol in, and learn from those courses. It is built with **Flutter** on the frontend and **Firebase** (Auth, Firestore, Storage) on the backend.

---

## Features

### Authentication & onboarding
- Email/password **sign up** and **login** via Firebase Auth.
- Role selection at sign up — **Student** or **Teacher**.
- Splash screen with auto session check, multi-page **onboarding**, and a forgot-password screen.
- Minimalist, themed login/register UI with inline validation and a password show/hide toggle.

### Students
- **Dashboard** showing ongoing courses with saved progress, plus a curated "Courses to Buy" grid.
- **Marketplace** with live search and category filters (Programming, Design, Marketing, Business).
- **Course detail** screen with enrol / "continue learning" flow.
- **Video player** (Chewie) with playback-speed control, fullscreen, and **resume from last position** (stored locally per course).

### Teachers
- **Teacher dashboard** with analytics and earnings widgets.
- **Create / edit courses** — upload a video and thumbnail (Firebase Storage) with title, description, price, category, and author.
- **My Courses** management and a profile screen with stats and tabs.

### Foundation
- **Role-based navigation** — the home shell loads the right screen set based on the user's role.
- Real-time course listing via Firestore snapshots.
- Responsive sizing with `flutter_screenutil`; consistent green theme.

---

## Tech stack

| Area | Choice |
|------|--------|
| Framework | Flutter (Dart SDK `>=3.4.3 <4.0.0`) |
| State management | [GetX](https://pub.dev/packages/get) |
| Backend | Firebase — `firebase_auth`, `cloud_firestore`, `firebase_storage`, `firebase_core` |
| Media | `video_player` + `chewie`, `image_picker` |
| Storage | `shared_preferences` (local video progress) |
| UI | `flutter_screenutil`, `google_fonts`, Montserrat + Playfair Display |
| Platforms | Android, iOS |

### Firestore data model
- `users/{uid}` — `name`, `email`, `role` (`Student` | `Teacher`), optional `profileImageUrl`.
- `courses/{courseId}` — `title`, `description`, `price`, `category`, `author`, `videoUrl`, `thumbnailUrl`, `userId`, `createdAt`.
- `enrollments/{userId}_{courseId}` — `userId`, `courseId`, `title`, `image`, `videoUrl`, `progress`, `isFree`, `enrolledAt`.

---

## Project structure

```
lib/
├── main.dart                 # App entry, Firebase init, GetX bindings, theme
├── controller/               # GetX controllers (courses, marketplace, user, teacher, enrollment)
├── models/                   # Data/UI models (e.g. onboarding pages)
├── screens/
│   ├── onbooading/           # Splash + onboarding
│   ├── login/ register/ forgot_password/
│   ├── home/                 # HomeShell + bottom nav
│   ├── marketplace/          # Marketplace + course cards/grid/list
│   ├── description/          # Course detail + enrolment
│   ├── student/              # Student dashboard & profile
│   ├── teacher/              # Teacher dashboard, create/edit course, profile
│   ├── videoplayer/          # Chewie-based player
│   ├── settings/
│   └── components/           # Shared widgets (text field, dropdown, etc.)
└── utils/                    # colors.dart, utils.dart (auth helpers)
```

---

## Getting started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (Dart `>=3.4.3`)
- Android Studio / Xcode with an emulator or a physical device
- A [Firebase](https://console.firebase.google.com) project
- The [FlutterFire CLI](https://firebase.flutter.dev/docs/cli/): `dart pub global activate flutterfire_cli`

### 1. Clone and install
```bash
git clone <your-repo-url>
cd padi_learn
flutter pub get
```

### 2. Configure Firebase
> ⚠️ Firebase config files are **gitignored** (see `.gitignore`) and are **not** included in the repo, so you must generate them yourself. A missing `google-services.json` will fail the Android build.

The easiest path generates everything in one step:
```bash
flutterfire configure
```
Select (or create) your Firebase project and the Android/iOS targets. This produces:
- `lib/firebase_options.dart`
- `android/app/google-services.json`
- iOS `GoogleService-Info.plist`

In your Firebase project, enable:
- **Authentication** → Email/Password sign-in
- **Cloud Firestore**
- **Storage**

Then wire the generated options into `main.dart`:
```dart
import 'firebase_options.dart';
// ...
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

### 3. Run
```bash
flutter run
```

---

## Troubleshooting

**Build fails: `google-services.json is missing`**
You haven't run `flutterfire configure` (or placed the file at `android/app/google-services.json`). See step 2.

**Build fails: `paging file is too small` / `insufficient memory for the Java Runtime`**
The Gradle JVM heap is set in `android/gradle.properties` (`org.gradle.jvmargs`). Lower it (e.g. `-Xmx1536m`), close Android Studio/other heavy apps, run `cd android && ./gradlew --stop`, and/or increase the Windows paging file, then retry.

**App hangs on a loading spinner after login**
This happens when an authenticated session has no matching `users/{uid}` document (e.g. a session from a different Firebase project). The home shell now clears the stale session and returns to login — sign up again to recreate the profile document, and ensure your `google-services.json` points to the project where the account lives.

---

## Notes & roadmap
- **Payments are not yet implemented** — "Buy Course" currently enrols the user without a payment gateway.
- Add **Firestore security rules** before production; the client currently trusts the `role` field for teacher access.
- Generate proper app icons/splash and review image error/loading states across the marketplace.

---

## License
Private project — not currently licensed for redistribution.
