# PadiLearn video

Renders the app's promotional video with [Remotion](https://remotion.dev).
Standalone Node workspace — it is not part of the Flutter build and never
touches `pubspec.yaml`. The only thing that crosses the boundary is the MP4s it
produces, which get uploaded to the `course-media` bucket like any other video.

```bash
cd video
npm install
npm run studio          # live preview, scrub the timeline, hot reload
npm run render:all      # both cuts into out/
```

## What it produces

| Composition | Frame | Where it goes |
|---|---|---|
| `AppAdLandscape` | 1920×1080 | The in-app "Welcome to PadiLearn" course video |
| `AppAdVertical` | 1080×1920 | Play Store listing, social, WhatsApp |
| `LogoSting` | 1920×1080 | Intro bumper, splash, top of any future video |
| `LogoStingSquare` | 1080×1080 | Social avatar animation, square placements |
| `EditorsNotes` | 1920×1080 | Marked-up reference for a sound designer / VO artist / editor |
| `TeacherCall` | 1080×1920 | "First teachers" announcement — WhatsApp status, social |
| `TeacherCallSquare` | 1080×1080 | The same announcement for square placements |
| `TeacherFlyer` | 1080×1350 | Announcement flyer, dark — for sharing (`remotion still`) |
| `TeacherFlyerLight` | 1080×1350 | The same flyer on paper stock — for print (`remotion still`) |

The two ad cuts are 720 frames — 24 seconds at 30fps; the stings are 120, or 4
seconds. Each pair shares every component and all its copy, so the cuts cannot
drift apart: only the frame differs, and the layout reads its own orientation
to decide whether the caption sits beside the phone or above it, and whether
the lesson scene has room for a course strip under the player.

The cut runs hook → browse → **lesson** → learn → teach → cta. The lesson
scene is the proof beat: two real lessons played at a size you can read them
at, rather than another mock screen. Everything before it is a claim about the
product; it is the only part that is the product.

## Changing it

**The words** are all in `src/theme.ts` under `script`. Edit them and
re-render — nothing needs re-timing, which is the main reason this is code
rather than a timeline.

**The timing** is the `DURATIONS` table at the top of `src/AppAd.tsx`. Only
durations are written down; each scene's start is accumulated from the ones
before it and the total from all of them, so retiming is editing one number
with nothing to keep in sync by hand. `teach` carries the remainder that keeps
the cut at exactly 720 frames — lengthen another scene and take it out of that
one. `SCENE_ORDER` comes off the same table, so the notes overlay cannot miss
a scene that was added to the ad.

**The palette** is `src/theme.ts`, mirrored by hand from
`lib/utils/colors.dart`. If the app's colours change, this is the one file that
has to follow.

## The "first teachers" announcement

A second campaign, not a cut of the ad. `npm run render:announcement` builds
all four pieces.

The ad explains PadiLearn to someone who might learn on it. This asks someone
who already teaches to put a course on it *before there is one*, so it is
addressed to a different person and it is the only one of the two that asks
for anything. It looks different on purpose — type on a dark ground, one
statement at a time, built around a single number, no phones and no product
screens — so the two are not mistakeable at a glance.

**The copy is in `src/announcement.ts`, and the comment at the top of that
file is the important part.** It lists what the piece may claim and what it
may not, each checked against `docs/PRODUCT_OVERVIEW.md`, because a
recruitment pitch is a promise to a person who may act on it. The short
version: the 85/15 split, the student-paid card fee and the worked example are
all real and may be stated. "Start earning today" may not — nothing is open
yet. "Get paid straight to your account" may not either, even though the
product ad says it: payouts are not built, so this piece talks about the split
and never about the mechanism.

The flyer has a dark and a light variant off one layout. Dark is for sharing,
where it sits among other images and has to hold its own; light is for paper,
where a dark ground is a print bill and a smudge.

**Both videos are silent.** Not an oversight: a typographic notice carries
without sound, most of it will be watched muted on WhatsApp status anyway, and
the two beds in `public/audio/` are unlistened placeholders (see Known gaps) —
the wrong thing to attach to a piece that goes out in public. Add one the same
way `AppAd` does if you want a score.

## The logo animation

`src/components/LogoMark.tsx` builds the mark as a plant growing: the stem
rises out of the baseline, the bowl sweeps out to close the "P", the shoot
draws itself, then the leaf springs from where it meets the shoot with a little
overshoot. A pass of light crosses it, and once settled it breathes very
slightly so a held frame is never quite static.

It is live SVG, not `icon_light.png` being scaled around, because the whole
point is animating the parts *against each other* — a raster can only move as
one lump. The leaf, its vein and the shoot are the exact paths from
`assets/branding/icon_foreground.svg`, so the organic shapes are the real
artwork; only the "P" is reconstructed, being two rounded rectangles and a
half-round right edge.

Two variants. `tile` is the app-icon lockup on its green tile; `bare` drops the
tile for placing on a brand-green background. **The fills do not invert between
them** — the leaf is green *on* the white P in the real mark, so painting it
white for a green background makes it disappear into the letter.

`speed` multiplies the pace. The full 110-frame build reads well standing
alone; the ad's closing card runs it at `speed={2}` because it has a scene to
fit into, not four seconds to spend.

## Handing it to an editor

`npm run render:notes` produces the ad with direction laid beside it: running
timecode, the current scene and its bounds, the voiceover line, the sound cue
and the intended vibe, plus a scene timeline and the notes that hold across the
whole cut.

It is a **separate composition**, not an overlay toggled inside the ad. There
is no flag that could be left switched on, `AppAdLandscape` has no code path
that draws the notes, and the reference cut carries a standing
"REFERENCE — NOT FOR RELEASE" watermark so a stray copy is obviously not the
deliverable even with no context.

The direction itself is in `src/theme.ts` under `directions` and
`globalDirections`, beside the ad copy. It reads the same `SCENES` table the ad
does, so retiming a scene moves its notes with it rather than silently
desynchronising them.

## The mock screens

`src/components/` recreates the real UI in React rather than compositing screen
recordings. `CourseCard.tsx` follows the Flutter widget's actual proportions —
18px radius, the 11:10 thumbnail-to-body split, Poppins 13.5 at w600 — and
`Phone.tsx` lays its children out at 393×852, the app's own ScreenUtil design
size, so a mock screen can be built from a widget's real dimensions with no
arithmetic.

That means it stays sharp at any resolution and needs no device or emulator to
re-shoot. It also means it can drift from the real app: if a screen changes
materially, the mock has to be updated to match, or the ad is advertising
something that no longer exists.

The catalogue they display is **not** invented here any more. `src/catalogue.ts`
mirrors `supabase/seed/demo_catalogue.sql` — the same eleven courses, the same
titles, authors, prices and lesson lists the app serves — so the ad and the
product cannot disagree about what is for sale. Edit one, edit the other.

That also means the card chrome has to be right, and three things in it were
not: the rating pill sat top-right instead of bottom-left, the category pill
printed in ink instead of brand green, and a paid course's price printed in ink
instead of green. All three now follow `course_card.dart`.

The cards show `New` and a zero enrolment count because that is what the seeded
app actually renders — both columns are trigger-derived and the seed leaves
them at zero. The previous cut invented figures like "1.2k students"; at card
size the line is a few pixels tall and unreadable, so the fake bought nothing
and cost the one thing an ad should not spend.

## The lesson footage

`public/lessons/` holds the eleven lesson videos, one per course, and
`public/thumbs/` the card art cut from them. Both are tracked, for the reason
the audio beds are: a clean clone has to be able to render.

They are **not** made here. A separate project, `PadiLearn-lesson-videos`,
renders them, and `supabase/seed/import_lesson_videos.py` brings them across —
into `public/` for this render, and into `out/demo-clips/` and
`out/demo-thumbs/` laid out for the Storage buckets. Re-run it after rebuilding
a lesson over there and everything downstream picks it up:

```bash
python ../supabase/seed/import_lesson_videos.py
```

Each video prints its own course name and lesson number into the frame
("WAEC PHYSICS · LESSON 14"). The `lesson` scene and `LessonMock` both read
those positions out of `catalogue.ts` rather than restating them, so the chrome
the ad draws around a clip always agrees with the chrome inside it.

## Known gaps

- **A placeholder music bed, and nothing else.** Two CC0 tracks are wired up
  (see `public/audio/SOURCES.md`) — but nobody has listened to them, because
  audio cannot be judged by inspecting it. They prove the pipeline; they are
  not a scoring decision. **No voiceover and no spot effects**: the lines and
  cues are written, render `EditorsNotes` and hand it over.
- **No captions.** Most social video is watched muted. Worth adding before the
  vertical cut goes anywhere public.
- **The lessons are taught by nobody.** The footage is generated: every figure
  and every number in it is correct and checkable, but there is no teacher in
  it, because there is not yet a teacher. It exists so the catalogue is not
  visibly empty when the first testers open the app. The moment someone
  records a real lesson, that clip replaces one of these — on a marketplace a
  shaky phone recording of someone who knows their subject outsells an
  animation, because the buyer is buying the teacher.
- **Licence.** Remotion is free for individuals and small companies but
  requires a paid company licence above a small headcount. Check
  remotion.dev/license before this ships as company work.
