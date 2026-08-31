# PadiLearn dev log

Running record of changes that are worth understanding *later* — the ones where
the reasoning matters more than the diff. Newest first.

Not a changelog: routine fixes and UI tweaks stay in git history. An entry
earns its place here when it changes a contract (database shape, auth flow,
money), when it needs manual setup outside the repo, or when the next person to
touch that area would otherwise repeat a decision we already made.

Each entry: what changed, why, what it touches, and anything still outstanding.

---

## 2026-08-31 — Demo lesson clips

Eleven themed clips, one per seeded course, 13 MB total, sitting at
`video/out/demo-clips/` ready to drag into `course-media`. Every seeded lesson
now points at them with a truthful `duration_seconds`.

**Pixabay was the only stock library that could be scripted.** Coverr, and
Pexels without an API key, are closed; Pixabay's search pages do expose their
CDN `_medium.mp4` URLs. One catch worth recording: Pixabay serves curl fine but
returns 403 to Python's urllib no matter what User-Agent is set — they
fingerprint below the header level, so `fetch_demo_clips.py` shells out to curl.

Pixabay Content License: commercial use, no attribution. The one limit is that
you cannot redistribute their content *as the product* — fine as placeholder
lesson video, not fine if a paid course were nothing but Pixabay stock.

### Verified by looking, which audio never allowed

Extracted a frame from each clip and actually reviewed them. Three of the first
ten were wrong and got refetched: Flutter had a dated "matrix code" wall,
personal finance showed hands counting **US dollars** for a course priced in
naira, and photography was an out-of-focus coastline — a photo's subject, not
the craft. A fourth pass caught phone-photography and whatsapp-marketing
resolving to the *identical* clip, which would have played the same video in
two different courses; the fetch script grew a candidate offset.

This is the difference from the music: video can be checked before it ships.

### Decisions

- **One clip per course, shared by its lessons.** Nobody in a demo opens six
  lessons of one course, and 11 files keep this at 13 MB rather than 42 files.
- **`duration_seconds` rewritten to the real file length**, and the seeded
  resume point pulled from 4:12 back to 6s — it was beyond the end of a 14s
  clip, so the player would have tried to seek past the file.
- **Silent.** Audio stripped; the sources were ambient b-roll.
- Clips are gitignored (regenerable stock footage); the fetch script and
  `DEMO_MEDIA.md` are tracked so the set can be rebuilt or audited.

Still approximations: the photography clip shows a film camera rather than a
phone, and the finance spreadsheet is in dollars. Best available from a general
stock library — replace first if anyone will look closely.

---

## 2026-08-27 — Audio pipeline, with placeholder beds

Remotion's `<Audio>` takes a per-frame `volume` function, so fades and (later)
ducking under a voiceover are envelope edits rather than new plumbing. Both
compositions now carry a bed.

The ad's music starts at the **browse** scene rather than frame 0, so the hook
plays dry and the opening line lands in silence — that is what
`directions.hook` asks for, honoured in the build instead of left as a note for
someone else to apply.

### Sourcing was harder than expected

Free Music Archive, Pixabay and Incompetech all turned out to be dead ends for
automated download: FMA and Pixabay serve file URLs through JavaScript, and
Incompetech's old direct MP3 paths now 404. The Internet Archive was the only
source with genuinely direct, unauthenticated file URLs.

Landed on two HoliznaCC0 tracks — that artist dedicates their catalogue under
CC0 1.0, so no attribution is owed and the dedication cannot be revoked.

### Two caveats, both recorded in `public/audio/SOURCES.md`

- **The licence rests on the artist, not the Archive item it came from.** That
  item has no `licenseurl` in its metadata and is a user-assembled compilation
  containing other artists whose terms were not checked. Only HoliznaCC0-credited
  files were taken; the authoritative CC0 statement is on the artist's own FMA
  pages. Verify there before anything ships.
- **Nobody has listened to these.** They were picked from title, genre tag and
  duration. Audio is the one thing in this project that cannot be checked by
  looking at it, and music choice is almost entirely taste. Placeholders that
  prove the pipeline — swapping is a file replacement, same names, nothing else
  changes.

Still missing: voiceover, and every spot effect the direction asks for. A logo
sting in particular wants designed sound rather than a music bed; what is on it
now exists so the file is not silent.

---

## 2026-08-27 — Spores, depth, and a director's cut

### Logo

Particles and a slight 3D tilt on the mark. The motes are precomputed once from
Remotion's seeded `random`, **not** `Math.random`: frames render independently
and in parallel, so an unseeded value re-rolls every frame and the motes strobe
instead of drifting. The tilt is capped around 16 degrees — past roughly 14 the
tile's rounded corners start reading as a distorted rectangle rather than a
square turned in space.

Two wrong passes on the particles worth remembering: brand green made them
invisible (they travel over green in both variants), and clustering them at the
leaf's base read as dirt on the artwork rather than something coming off it.
They are white now, larger, spread along the leaf's whole length.

### Editing direction

`EditorsNotes` — the ad at half size with running timecode, the current scene
and its bounds, and the voiceover / sound / vibe direction beside it, plus a
scene timeline and the notes holding across the whole cut. For handing to a
sound designer, VO artist or editor.

**A separate composition, not an overlay inside the ad.** That was a choice: an
in-ad flag can be left switched on, and the notes would then ship. This way
`AppAdLandscape` has no code path that draws them at all. The reference cut
also carries a standing "REFERENCE — NOT FOR RELEASE" watermark so a stray copy
is obviously not the deliverable, with no context needed.

The direction lives in `src/theme.ts` beside the ad copy and reads the same
`SCENES` table the ad does, so retiming a scene carries its notes along instead
of silently desynchronising them.

---

## 2026-08-27 — Logo motion graphic

`video/src/components/LogoMark.tsx` — the mark animated as a plant growing,
which is the idea already sitting in the logo that nothing was using. The stem
rises out of the baseline, the bowl sweeps right to close the "P", the shoot
draws along its curve, and the leaf springs from where it meets the shoot with
a little overshoot. A pass of light crosses the tile; once settled the mark
breathes very slightly, so a held frame is never quite dead.

Two new compositions (`LogoSting`, `LogoStingSquare`, 4s each) and the ad's
closing card, which now runs the same build instead of showing a flat PNG.

### Why live SVG rather than animating the PNG

The point is animating the parts *against each other* — a raster can only scale
and fade as one lump. The leaf, its vein and the shoot are the exact path data
lifted out of `assets/branding/icon_foreground.svg`, so the organic shapes are
the real artwork. Only the "P" is reconstructed: it is two rounded rectangles
and a half-round right edge, trivial to match and far easier to reveal
piecewise than the converter's clip-path soup.

**Consequence to remember:** the mark is now drawn in two places. If the brand
mark ever changes, `LogoMark.tsx` has to follow, and it will not fail loudly if
it doesn't — it will just quietly animate the old logo.

### The mistake worth keeping

The first attempt at the tile-less variant inverted the fills, painting
everything white for the green background. The leaf disappeared: it sits *on*
the white P in the real artwork, so white-on-white is nothing at all. The
variant now keeps the true colours and only drops the tile. Noted in the props
doc so it isn't re-derived.

`speed` multiplies the build's pace — the full 110-frame growth reads well
standing alone but would eat a whole scene of the ad, so the closing card runs
it at 2x and holds the wordmark back until the mark has finished.

---

## 2026-08-27 — Demo catalogue seed

`supabase/seed/demo_catalogue.sql` — 11 courses, 42 lessons, and one student
part-way through a course. Applied to the remote project.

**Not in `supabase/migrations/`.** Migrations describe the database's shape and
every environment has to run all of them; this is sample data for showing the
app to people, and production should be able to skip it. Run by hand.

Re-runnable: every id is derived from its slug
(`'a0000000-…' || substr(md5(slug),1,12)`) rather than generated, so a second
run updates the same rows instead of duplicating them. The shared prefix is
also what makes the teardown at the bottom of the file safe — real courses get
random ids and cannot collide with it.

Two things the first run taught us, both now fixed in the file:

- `courses.enrollments` is maintained by a trigger on real signups, so the
  `on conflict do update` must NOT refresh it — doing so would discard genuine
  enrolments every time the seed was re-applied. The invented starting counts
  are set on insert only.
- The first row's `null` category needed an explicit `::text`, or the column
  type stays unknown and the FK to `categories(name)` will not resolve.

Student progress is seeded by inserting `lesson_progress` rows and letting the
recompute trigger derive the percentage, rather than writing
`enrollments.progress` directly — so what the app shows is what the app would
have calculated. JAMB Mathematics reads 33%, from 2 of 6 lessons complete.

### Outstanding, and deliberate

The seed writes thumbnail URLs and video keys for files that do not exist yet.
Nothing breaks meanwhile: `CourseThumbnail` degrades to the branded placeholder
on a 404, so it reads as deliberate rather than broken. The file header carries
the manifest of exactly which filenames to upload and to which bucket. The one
that matters most is `demo/welcome-to-padilearn/1.mp4` — put the rendered ad
there and it becomes the video that plays in the free Welcome course.

**The instructor names, enrolment counts and ratings are invented.** They exist
so the cards do not all read "0 students". Do not present them as traction, and
do not let an invented instructor name reach anywhere a reader would take it
for a real teacher.

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
