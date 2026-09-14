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

The two ad cuts are 720 frames — 24 seconds at 30fps; the stings are 120, or 4
seconds. Each pair shares every component and all its copy, so the cuts cannot
drift apart: only the frame differs, and the layout reads its own orientation
to decide whether the caption sits beside the phone or above it.

## Changing it

**The words** are all in `src/theme.ts` under `script`. Edit them and
re-render — nothing needs re-timing, which is the main reason this is code
rather than a timeline.

**The timing** is the `SCENES` table at the top of `src/AppAd.tsx`. Durations
are in frames; the total is derived from the table, so a scene can be
lengthened without also updating a duration constant somewhere else.

**The palette** is `src/theme.ts`, mirrored by hand from
`lib/utils/colors.dart`. If the app's colours change, this is the one file that
has to follow.

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

`demoCourses` in `CourseCard.tsx` is placeholder catalogue data. Swap it for the
real seed once that exists.

## Known gaps

- **A placeholder music bed, and nothing else.** Two CC0 tracks are wired up
  (see `public/audio/SOURCES.md`) — but nobody has listened to them, because
  audio cannot be judged by inspecting it. They prove the pipeline; they are
  not a scoring decision. **No voiceover and no spot effects**: the lines and
  cues are written, render `EditorsNotes` and hand it over.
- **No captions.** Most social video is watched muted. Worth adding before the
  vertical cut goes anywhere public.
- **Licence.** Remotion is free for individuals and small companies but
  requires a paid company licence above a small headcount. Check
  remotion.dev/license before this ships as company work.
