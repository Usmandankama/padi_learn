# PadiLearn dev log

Running record of changes that are worth understanding *later* — the ones where
the reasoning matters more than the diff. Newest first.

Not a changelog: routine fixes and UI tweaks stay in git history. An entry
earns its place here when it changes a contract (database shape, auth flow,
money), when it needs manual setup outside the repo, or when the next person to
touch that area would otherwise repeat a decision we already made.

Each entry: what changed, why, what it touches, and anything still outstanding.

---

## 2026-08-27 — Promo video, rendered from code

### Why

The demo needs course content, and the honest options were all bad: scraped
TikTok or YouTube clips are somebody else's copyright (and their music is
licensed for playback *on that platform*, so even the creator's permission
doesn't clear it), and stock b-roll doesn't look like a lesson. Building the ad
instead sidesteps the question entirely and produces something needed anyway —
a Play Store listing video, a pitch asset, a thing to forward on WhatsApp.

It also gives the marketplace an honest place to put it: a free "Welcome to
PadiLearn" course pinned at the top, which real platforms genuinely do.

### What

`video/` — a standalone Remotion workspace. Node, not Dart; it is not part of
the Flutter build and does not touch `pubspec.yaml`. The only thing crossing
the boundary is the MP4s, which get uploaded to `course-media` like any other
video. Both cuts render at ~3 MB, well under the free tier's 50 MB per-file cap.

Two compositions off one set of components — 1920x1080 for the in-app course
video, 1080x1920 for store and social. Sharing the components is the point:
the two cuts cannot drift apart, and the layout reads its own orientation to
decide whether the caption sits beside the phone or above it.

The app screens in it are React recreations, not screen recordings.
`CourseCard.tsx` follows the real widget's proportions and `Phone.tsx` lays its
children out at 393x852 — the app's own ScreenUtil design size — so a mock is
built from a widget's real dimensions with no arithmetic. Sharper than a
capture, re-renders at any resolution, and needs no device. The tradeoff is
that it can drift: **if a screen changes materially, the mock has to follow, or
the ad advertises something that no longer exists.**

All ad copy lives in one `script` object in `src/theme.ts`, and all timing in
one `SCENES` table in `AppAd.tsx`. Rewording the ad is editing strings and
re-rendering — no re-timing, no reflowing. That is the whole argument for doing
this in code rather than a timeline.

### Still outstanding

- **No narration.** Remotion animates but does not speak. A voiceover recorded
  in a Nigerian accent would carry more for this market than any TTS; add it
  with Remotion's `<Audio>`.
- **No captions**, and most social video is watched muted. Needed before the
  vertical cut goes anywhere public.
- **Licence.** Remotion is free for individuals and small companies but needs a
  paid company licence above a small headcount — check remotion.dev/license
  before this ships as company work.
- `demoCourses` is placeholder catalogue data, and the payout figure in the
  teacher scene is illustrative. Both want replacing with real seed data before
  the ad is shown as fact.

---

## 2026-08-24 — Social sign-in, and role as a separate step

### Why

Signup asked for name, email, password, confirmation *and* a role before the
user had seen anything of the app. Adding Google/Apple removes most of that,
but the two providers return an identity and nothing else — there is no way to
attach a role to `signInWithOAuth` or `signInWithIdToken`, because the provider
owns the token payload.

So role stopped being part of signup and became its own step. Identity first,
role second, and the second step only appears when the first could not supply
one. Email signup still collects both on the register form and never sees the
new screen.

### Database — `20260803000001_role_claiming.sql`

- `handle_new_user` no longer defaults the role to `'Student'`. That
  `coalesce` was invisible while email was the only way in; with OAuth it would
  have silently filed every teacher as a student, with no prompt and no route
  back. A profile may now exist with `role` null, which the app reads as
  "hasn't been asked yet".
- `profiles.role` gained a check constraint. The value arrives as client-set
  auth metadata, so it is user input; anything other than `Student`/`Teacher`
  used to land in the column verbatim and fall through the app's
  `role == 'Student'` test into the student shell.
- New `claim_role(p_role text)` — security definer, fills the column only
  `where role is null`. That predicate is the whole security argument: it can
  complete onboarding but cannot promote anyone. Returns the role in force, so
  a retry after a lost response is not mistaken for a failure.
- **Pre-existing hole closed while here.** The "Users can update their own
  profile" policy is `auth.uid() = id` with no `WITH CHECK`, so *any* signed-in
  user could patch their own row and become a Teacher in one client call,
  bypassing every teacher-gated policy behind it. RLS cannot say "any column
  but this one", so the grant was narrowed instead: table-level UPDATE revoked,
  then re-granted on `(name, profile_image_url)` only — the same reasoning as
  `payout_accounts`. Those two are the only columns the app writes
  (`editprofile_screen.dart`).

### App

- `auth_service.dart` — `signInWithGoogle`, `signInWithApple`, `claimRole`,
  and the `isGoogleSignInConfigured` / `isAppleSignInAvailable` gates that
  decide whether a button is worth showing.
- Native flow (`signInWithIdToken`), not `signInWithOAuth`. The browser flow
  bounces the user out to a custom tab and back through a deep link; the native
  one uses the platform account picker and needs no URL scheme registered for
  either provider.
- `RoleSelectionScreen` — two cards, no back button, no skip. The app branches
  on role everywhere, so an unanswered picker has nowhere to go but itself.
- `HomeShell` — the branch that used to treat a null role as a dead session and
  sign the user out now routes to the picker. Left alone, every social sign-in
  would have landed straight back on the login screen, forever. A missing
  profile *row* is still a dead session and still signs out.
- `SocialSignIn` — shared by login and register, renders nothing when no
  provider is configured, so an unconfigured build looks exactly like before.
- Apple only ever discloses a name on the *first* authorization, so it is
  written to the blank `profiles.name` right after sign-in. Never overwrites.

### Expected advisor warning

Supabase's security linter flags `claim_role` under
`authenticated_security_definer_function_executable` — a signed-in user can
call a SECURITY DEFINER function over `/rest/v1/rpc/`. That is the design, not
a slip: the function exists precisely so a client can write a column it has no
grant on, and the `where role is null` predicate is what makes that safe. Do
not "fix" it by revoking EXECUTE or switching to SECURITY INVOKER — either one
breaks the role picker.

Applied to the remote project on 2026-08-24; verified afterwards that the
UPDATE grant is down to `(name, profile_image_url)`, the constraint is present,
and both existing profiles kept their roles.

### Still outstanding

Everything below is console/Xcode work that cannot be done from the repo. Until
the first item is done the Google button stays hidden and nothing regresses.

1. **Google Cloud Console** — create a *Web* client and an *iOS* client, plus
   an *Android* client for each signing certificate (the debug keystore's SHA-1
   too, or debug builds fail with a null ID token). Put the web and iOS IDs in
   `lib/config/supabase_config.dart` — see `supabase_config.example.dart`.
2. **Supabase dashboard** — Authentication → Providers → Google: enable, and
   list the **web** client ID under "Authorized Client IDs". That is the
   audience the ID token is validated against. Enable Apple the same way.
3. **iOS** — add the reversed iOS client ID
   (`com.googleusercontent.apps.…`) as a URL scheme in `ios/Runner/Info.plist`,
   and add the "Sign in with Apple" capability in Xcode (there is no
   `Runner.entitlements` yet; adding one by hand means editing the pbxproj, so
   it was left for Xcode to do properly).
4. **`assets/branding/google_logo.png`** — the official mark. Google's branding
   terms do not allow redrawing it, so the button ships without one and renders
   fine when it appears.
5. **Existing rows are untouched.** Everyone who signed up before this has a
   role already, so nobody is sent to the picker retroactively.

### Noticed, not fixed

`android/app/` has *both* `build.gradle` and `build.gradle.kts`, declaring
different `applicationId`s (`com.dankamaInnoHu.padiLearn` vs
`…padi_learn`). Whichever Gradle picks decides the package name that Google's
Android OAuth client must be registered against — worth resolving before step 1.

Also: `.gitignore` ignores `/supabase` wholesale, so no migration file in
`supabase/migrations/` is under version control — the remote database is
currently the only record of the schema. The new migration follows that
existing convention rather than quietly breaking it, but a schema this app
depends on should be tracked (`git add -f`, or narrow the ignore rule).
