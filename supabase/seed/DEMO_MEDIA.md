# Demo lesson clips — provenance and upload

Twelve files, **9.3 MB total**: eleven lesson videos, one per subject course,
plus the rendered ad as the welcome tour. Every seeded lesson already points at
these keys, so once they are uploaded the whole demo catalogue plays.

The files are at **`video/out/demo-clips/`** in the Remotion workspace, which
lives outside this repo at `Groundwork Tech ltd\Projects\PadiLearn-media\video`
(beside `PadiLearn-lesson-videos`). Every `video/` path below is relative to
`PadiLearn-media`. This file is the tracked record of what they are; a copy
sits beside the clips as `UPLOAD.md`.

## Where they come from

The eleven lesson videos are rendered by a separate project,
**`PadiLearn-lesson-videos`**, and brought in by `import_lesson_videos.py`
beside this file:

```bash
python supabase/seed/import_lesson_videos.py [path/to/PadiLearn-lesson-videos]
```

That writes the bucket-ready tree, the thumbnails (see `DEMO_THUMBNAILS.md`),
and the copies in `video/public/lessons/` that the ad renders from. The welcome
clip is our own ad: `cd video && npm run render:ad`, then copy
`out/padilearn-ad-16x9.mp4` to `out/demo-clips/demo/welcome-to-padilearn/clip.mp4`.

Nothing here is third-party footage any more. The previous set was Pixabay
b-roll fetched by `fetch_demo_clips.py`, retired and then deleted on
2026-10-07 (it is in git history).

## How to upload

`video/out/demo-clips/demo/` mirrors the bucket layout exactly.

**Supabase dashboard** → Storage → `course-media` → drag the whole `demo`
folder into the bucket root. That is the entire job.

If you would rather use the CLI:

```bash
supabase storage cp --recursive ./demo ss:///course-media/demo
```

## What is in them

| Course | Lesson | Length |
|---|---|---|
| `welcome-to-padilearn` | What PadiLearn is (the ad) | 24s |
| `waec-physics` | 14 · Projectile Motion | 18s |
| `waec-mathematics` | 7 · Completing the Square | 18s |
| `waec-chemistry` | 3 · The Mole | 18s |
| `bookkeeping` | 1 · The Accounting Equation | 18s |
| `pricing-and-margins` | 4 · Break-even Point | 18s |
| `tailoring` | 9 · The Bust Dart | 18s |
| `electrical-work` | 5 · Series and Parallel | 18s |
| `excel-for-business` | 11 · VLOOKUP's One Limitation | 18s |
| `programming-fundamentals` | 8 · Binary Search | 18s |
| `graphic-design` | 2 · The Type Scale | 18s |
| `broiler-farming` | 6 · Feed Conversion Ratio | 18s |

All 1280×720, 30fps, silent, roughly half a megabyte each.

**The lesson number is burned into the footage.** Each clip prints its own
course and lesson in the corner of every frame, which is why the seeded courses
are the lengths they are — the app numbers curriculum rows by their index, so
the fourteenth row has to be the fourteenth row. `demo_catalogue.sql` explains
this at length under THE FOOTAGE; do not reorder a lesson without re-cutting
the video.

**They are silent.** No voiceover was recorded. Audio would also have to be
re-cut every time a figure changed.

**One clip per course, shared by all its lessons**, with the filmed one set as
the course's free preview so a visitor who has not enrolled can only ever reach
the lesson whose number matches. See ONE REAL LESSON in `demo_catalogue.sql`.

## Licence

Ours. Rendered from our own source, in our own palette, with no third-party
footage, stock library or model release involved. The Pixabay licence question
that applied to the previous set does not arise.

## What these are and are not

**Every figure and every number in them is correct.** They get paused,
screenshotted and zoomed, and an education product caught with a wrong formula
on the board is worse off than one with no footage at all.

**Nobody teaches them.** They are diagrams that draw themselves, not a person
explaining something, and that is the gap a real course closes. Retire them one
at a time as real lessons arrive.
