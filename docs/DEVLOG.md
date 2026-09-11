# PadiLearn dev log

Running record of changes that are worth understanding *later* — the ones where
the reasoning matters more than the diff. Newest first.

Not a changelog: routine fixes and UI tweaks stay in git history. An entry
earns its place here when it changes a contract (database shape, auth flow,
money), when it needs manual setup outside the repo, or when the next person to
touch that area would otherwise repeat a decision we already made.

Each entry: what changed, why, what it touches, and anything still outstanding.

---

## 2026-09-06 — Courses you already own

A student could see a course they had already bought sitting in the marketplace
with its price on it, and buy it again.

Two changes. The marketplace now hides courses the student is enrolled in — the
shelf is for things they can still buy. Everywhere a card can still show an
owned course (the dashboard's "Popular Courses", the course page) it prints
**Owned** where the price would go.

"Owned" rather than "Purchased" on purpose: free courses are enrolments too, and
telling someone they purchased something they got for nothing is a small lie a
receipt would contradict.

### Where the answer comes from

`OngoingCoursesController` already streams this student's `enrollments` for the
"Continue learning" row, so `ownedIds` is derived from the rows it has rather
than from a second query. Opening another realtime subscription on the same
table for the same user would have doubled this screen's share of the
connection budget to learn nothing new.

All three places rows land — the stream, the pull-to-refresh, the offline cache
— now go through one `_apply`, so the id set cannot drift from the list.

Two things that would have made this silently not work:

- **`RxSet` was the wrong type.** Its `value` is `@protected`, and its
  `contains()` reads the backing field directly — so calling it inside an `Obx`
  registers no dependency and the marketplace would not drop a course until
  some unrelated rebuild wandered past. It is a plain `Rx<Set<String>>`, read
  through `.value`, which is what actually subscribes.
- **Registration order.** The controller is registered per user id by the
  dashboard's widget, so whether the marketplace saw any enrolments depended on
  which tab built first. `HomeShell` now registers it alongside the student
  screens, and `forCurrentUser()` is the read-only accessor for screens that
  should not care about the tag — returning null rather than throwing, because
  teachers and signed-out users have no enrolments controller at all.

### Outstanding

Search shares the filter, so searching for a course you own finds nothing. That
is defensible for browsing and arguably wrong for search — the fix, if it
bites, is to filter the catalogue but let an explicit query through with the
card's `isOwned` badge already built for it.

---

## 2026-09-05 — Dark mode actually works, and password reset reaches the app

### Dark mode was a toggle attached to nothing

`SettingsController` switched `ThemeMode` and 36 files went on painting
`appWhite` surfaces with `richBlack` text, so turning it on produced black text
on white cards on a dark ground. The toggle worked; nothing downstream did.

The fix is a split in `colors.dart`. Constants there are now only things that
mean the same in both themes — the brand green, and foregrounds that always sit
on it (white on the green button is white either way). Anything describing a
**surface, or the ink on it**, moved to `AppPalette`, a `ThemeExtension` with
five tokens: `ground`, `surface`, `surfaceAlt`, `ink`, `inkSoft`, `hairline`.
Five, not a full system, because those are the only ones the app broke without.

`primaryColor` stays theme-independent on purpose. It is the identity, it
carries white text at the same contrast on either ground, and freezing it kept
168 usages out of this change.

`main.dart` now points every Material default that paints a surface at the
palette — scaffold, app bar, cards, dividers, dialogs, sheets, inputs,
snackbars. That matters more than it sounds: a screen that simply *doesn't* set
a colour now comes out right in both themes, so only the screens that
hard-coded one needed touching.

302 substitutions across 36 files. `appWhite` was the hard part — 71 uses split
between "white text on a green button" (must stay white) and "card background"
(must flip), which no find-and-replace can tell apart. They were classified by
walking back to the enclosing constructor, defaulting to *leaving it white*
when ambiguous: a stray white card is visible and fixable, white text turned
dark on a green button is invisible. 48 flipped, 24 stayed.

### `AppColors.palette` is a deliberate compromise

Much of this app paints from helper methods that were never handed a
`BuildContext` — `Widget _buildStats(TeacherController c)` and its like. A
context-only API would have meant changing dozens of signatures across 36 files
to fix a colour bug.

So there is a static `AppColors.palette`, bound once per frame from `MyApp`'s
builder above the Navigator. `AppColors.of(context)` still exists and is
preferred where a context is already in hand. The static holds because this app
has one `MaterialApp` and never renders two themes at once — if that changes, a
themed preview or a per-subtree `Theme`, those widgets have to move to `of`.

**The first version of this shipped broken, and it is worth understanding why.**
Reading a static creates *no dependency* on the `Theme` inherited widget. So
when the mode flipped, `MaterialApp` rebuilt and the static updated correctly,
but every screen already sitting in the Navigator never rebuilt — nothing had
told it to. Switching to light mode left a dark screen with a light strip along
the bottom, where the `Scaffold` (which *does* depend on the theme) had
repainted underneath a body that had not.

The fix is `AppColors.watch(context)`, called once at the top of every `build`
that paints from the palette — 46 of them. `Theme.of` inside it registers the
dependency, which is the part that makes the widget rebuild; refreshing the
static at the same time is what keeps the context-free helper methods correct,
since they re-run as part of that rebuild.

`test/widget_test.dart` covers it: a probe widget that watches and then paints
from the static, asserted across a mode flip. Removing the `watch` call fails
it, so it is a real guard rather than a restatement.

### Password reset dead-ended before it reached the app

`resetPasswordForEmail` was called with no `redirectTo`, there was no scheme
registered on Android, and nothing listened for the recovery session. The mail
arrived, the link opened a browser, and that was the end of it — no screen in
the app could set a password.

Now: `redirectTo: DeepLinks.passwordReset` (`padilearn://reset-callback`), an
intent-filter in `AndroidManifest.xml`, and a `passwordRecovery` listener in
`MyApp` that pushes the new `ResetPasswordScreen`. Following the link signs the
user into a short-lived recovery session, which is what lets `updateUser`
change the password without the old one — so that screen is only ever reached
from the link, never navigated to directly.

**Three places have to agree** or the redirect is silently refused and the user
lands on the project's site URL: `lib/config/deep_links.dart`, the
intent-filter, and Supabase's Redirect URLs allowlist.

### One home per account action

Logout, About and Edit Profile each existed in both Settings and the Profile
screen. They now live on Profile only, and Settings keeps just the things that
have no other home: Change Password, Notifications, Dark Mode.

The direction matters more than which copy survived. Removing duplicates in
*opposite* directions — Logout kept on Profile, Edit Profile kept in Settings —
would have taught two contradictory rules for where account actions live. So
Profile is the single home, and the Edit Profile button stays under the name
card, beside the photo and name it changes.

The commented-out GENERAL block went with it rather than being left to rot; git
has it.

Deleting it exposed a gap: About had only ever existed there and in the
*student* profile, so teachers were left without it. The section is now a shared
`ProfileSupportSection` used by both profiles rather than a block copied into
one of them — the two profile screens are maintained separately, which is
exactly how the roles diverged in the first place.

The version string went the same way. It had been written by hand in two places
and this would have made three, so `lib/utils/app_info.dart` holds the name,
version and legalese. It is still a constant that has to track `pubspec.yaml` by
hand; `package_info_plus` reads the number the build was actually stamped with,
and is worth adding the first time a shipped build claims the wrong version.

### Outstanding — needs doing in the Supabase dashboard

- Add `padilearn://reset-callback` under **Authentication → URL Configuration →
  Redirect URLs**. Until this is done the deep link does not work.
- Point **Authentication → SMTP Settings** at a real provider. The built-in
  sender is rate-limited to a handful of mails an hour and is not for
  production — a reset nobody receives is the same bug in a different place.
  Custom SMTP is available on the free plan; this does not need Pro.
- iOS will need the same scheme under `CFBundleURLTypes` whenever it ships.

---

## 2026-09-03 — System navigation insets, and four kinds of duplication

### The nav pill was underneath the device's own navigation

Flutter draws edge-to-edge by default at this target SDK, so the Scaffold's
`bottomNavigationBar` slot extends *behind* the system navigation bar. The pill
had a hard-coded `margin: bottom 30`, measured from the bottom of the screen
rather than from the bottom of the usable area — so on three-button navigation
(48dp) its lower half sat behind Back/Home/Recents, and on gesture navigation
it sat inside the handle strip, which swallows touches outright.

The gap is now measured from `MediaQuery.viewPadding.bottom`. `viewPadding`
rather than `padding` because `padding` collapses to zero when the keyboard is
up, and the pill would jump.

Same bug, same fix, in every other place something is anchored to the bottom:
the onboarding "Get Started" sheet, the marketplace filter and course-preview
sheets, the settings change-password sheet, the bank picker's last row, the
video player's comment box, and the course description's buy button. Bottom
sheets use `padding.bottom` there, not `viewPadding` — they already offset for
`viewInsets`, and double-counting would leave a gap the height of the nav bar
above the keyboard.

Two things fell out of rewriting the pill:

- The `Stack` around it was **not** left over from the deleted centre button —
  it was doing the centring. Scaffold hands that slot a *tight* full-width
  constraint, so a `Container` with its own `width` cannot size itself and
  silently becomes a full-width bar. It needs a full-width parent (`Align`) to
  be a pill inside. A test caught this; the eye would not have, quickly.
- The items are `Expanded` now. They were fixed-width children scaled with
  `.w` inside a pill whose width was *not* scaled, which overflows once the
  screen is far enough from the 393pt design width. Scale all three or none —
  this file now scales none, matching its unscaled 28pt icons.

`test/widget_test.dart` covers it at 0 / 24 / 48dp insets. It was the generated
counter smoke test before, tapping an `Icons.add` this app has never had.

### `Get.put` was quietly undoing the fenix registration

`teacher_dashboard.dart` and `my_courses.dart` both did
`Get.put(TeacherController())`. `main()` registers that controller with
`fenix: true` specifically so it survives the `Get.deleteAll()` on sign-out —
and `Get.put` replaces that registration with a non-fenix one, after which
every *other* screen's `Get.find<TeacherController>()` throws once someone
signs out. It also built a fresh controller, re-running all three fetches,
every time either tab was rebuilt. Both are `Get.find` now.

Register in `main()`, find at the point of use. Don't `Get.put` a controller
`main()` already owns.

### Tabs are an IndexedStack

`_screens[_selectedIndex]` disposed the outgoing tab's State on every switch,
which tore down and rebuilt its realtime subscriptions — the teacher's course
stream, the activity feed — and discarded scroll position and search text.
Safe to do now that the tabs share their controllers rather than each putting
their own.

### One spelling for money

`'NGN ${x.toStringAsFixed(0)}'` was written by hand in six places; the
"Free or price" rule existed a seventh time inside `PriceTag`, which took a
pre-stringified price *and* an `isFree` bool the price already implies; the
marketplace screen imported a card *component* to reach `formatPriceLabel`;
and `earnings_hint.dart` carried its own thousands-separator routine and wrote
the currency as the naira glyph while every other screen wrote `NGN`.

All of it is `lib/utils/money.dart` now, and the app says `NGN` throughout.
`NGN` over the glyph deliberately: the glyph is not guaranteed present in every
font we ship, and a tofu box where a price should be is worse than three
letters. Amounts are grouped (`NGN 25,000`), which they were not before outside
the earnings hint.

### Dead code

Removed: `avatar_stack.dart` (hard-coded `+52` and three asset faces, never
referenced), `custom_back_button.dart` and `center_nav_button.dart` (entirely
commented out), `otp_screen.dart` (a non-functional stub whose button does
nothing — nothing routes to it), and `firebase.json` (a leftover pointing at
the retired Firebase project; nothing in `pubspec.yaml` or `lib/` references
Firebase any more).

`CoursesController` lost `courses` / `fetchCourses()` and its `UserController`
handle. Nothing read that list — `MarketplaceController` owns the catalogue and
both the marketplace and the student dashboard read it from there — so it was a
full-table `select()`, every column including descriptions, fetched on every
launch and thrown away. It carries the tapped course to the description screen;
that is all it ever did.

### Still outstanding

`README.md` still describes a Firebase backend, `firebase_options.dart`, and a
FlutterFire setup that no longer exists. It needs rewriting against Supabase
before anyone new tries to follow it.

Dark mode is a toggle that does not work. `SettingsController` switches
`ThemeMode` and 36 files then paint `AppColors.appWhite` backgrounds and
`richBlack` text regardless. Either hide the toggle for v1 or do a proper
token pass — a half-dark app is worse than a light one.

---

## 2026-08-31 — Continue-learning order, course load time, thumbnails

### Latest enrolment first

`ongoing_courses_controller.dart` had **no ordering at all** — neither the
realtime stream nor the pull-to-refresh path. Rows arrived in whatever order
Postgres returned them, so the course you just bought landed wherever it
happened to fall, which is the one place a user will not look for it. Both
paths now `.order('enrolled_at', ascending: false)`. Ordering both matters: if
only the stream had it, a refresh would reshuffle the list.

### Opening a course was four round trips

`videoPlayer.dart` fetched the course, then its lessons, then this user's
progress, then their rating — sequentially, each awaiting the last, none
depending on the one before. Four serial round trips before the player even
asked for a video URL, which on a mobile connection is most of a second of
nothing.

Now one `Future.wait` over a record. Two things fell out of the rewrite:

- Each fetch is individually wrapped, so one failure no longer takes the others
  down. They previously shared a try/catch, meaning a ratings hiccup could
  leave the screen with no lessons at all.
- The course row is selected by column instead of `select()`, which had been
  pulling every field including the full description.

The fifth trip — the signed playback URL — genuinely depends on knowing which
lesson, so it stays sequential.

### Thumbnails

Eleven photographs, 1.4 MB, at `video/out/demo-thumbs/`. Plain photography with
no text baked in: the card already prints title, author and price *underneath*
the image, so type in the picture collides with it, and stock photos with words
on top are the tacky look to avoid.

Took three passes, and every rejection came from actually looking at the
results: a literal **snake** for Python, a **cartoon dog with a guitar** for the
welcome card, a flat "RISK ASSESSMENT" illustration for Excel, the blue
"SOCIAL" tech-collage for WhatsApp, and — twice — foreign banknotes for a
course priced in naira. Adding `image_type=photo` to the Pixabay search stopped
the vector art; the currency problem was solved by picking an image with no
money in frame.

Remaining imperfections are recorded in `supabase/seed/DEMO_THUMBNAILS.md`
rather than smoothed over: the finance ledger is a joke if you read it closely,
the photography card shows a film SLR rather than a phone, and the WhatsApp one
leans laptop.

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
