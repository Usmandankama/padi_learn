# Demo lesson clips — provenance and upload

Eleven clips, one per seeded course, **13 MB total**. Every seeded lesson in
the database already points at these keys, so once they are uploaded the whole
demo catalogue plays.

The files themselves are at **`video/out/demo-clips/`**, which is gitignored —
13 MB of stock footage does not belong in the repo, and the fetch script can
regenerate them. This file is the tracked record of what they are and where
they came from; a copy sits beside the clips as `UPLOAD.md`.

## How to upload

`video/out/demo-clips/demo/` mirrors the bucket layout exactly.

**Supabase dashboard** → Storage → `course-media` → drag the whole `demo`
folder into the bucket root. That is the entire job.

If you would rather use the CLI:

```bash
supabase storage cp --recursive ./demo ss:///course-media/demo
```

Nothing else needs changing — `lessons.video_url` and `duration_seconds` are
already set to match these exact files.

## What is in them

| Course | Subject of the clip | Length | Size |
|---|---|---|---|
| welcome-to-padilearn | The PadiLearn ad | 24s | 2.82 MB |
| jamb-mathematics | Technical/geometric drawing | 14s | 2.49 MB |
| waec-english | Desk, notebook, writing | 15s | 0.55 MB |
| flutter-for-beginners | Overhead laptop typing | 15s | 0.50 MB |
| python-basics | Code on screen | 15s | 0.39 MB |
| excel-for-office-work | Keyboard close-up | 14s | 1.05 MB |
| start-a-small-business | Market stall | 7s | 0.34 MB |
| whatsapp-marketing | Phone in hand | 8s | 0.10 MB |
| tailoring-basics | Sewing machine close-up | 10s | 1.45 MB |
| phone-photography | Someone taking a photo | 5s | 0.41 MB |
| personal-finance | Financial spreadsheet | 12s | 2.82 MB |

## Licence

Every clip except the welcome one came from **Pixabay** under the
[Pixabay Content License](https://pixabay.com/service/license-summary/): free
for commercial use, no attribution required, no permission needed. The welcome
clip is our own render.

One limit worth knowing: the Pixabay licence does not allow redistributing
their content *as the product itself* — reselling it, or reuploading it to
another stock library. Using clips as placeholder lesson video inside a demo is
squarely fine. If PadiLearn ever charged for a course whose entire content was
Pixabay stock, that would be a different question.

## What these are and are not

**They are b-roll standing in for lessons.** Each one shows the *subject* of
its course — a sewing machine, a spreadsheet, code on a screen — not a person
teaching it. Close enough that tapping a lesson produces something plausible;
not close enough to survive a viewer who watches carefully.

**All lessons in a course share one clip.** Six JAMB lessons play the same 14
seconds. Nobody in a demo opens six lessons of one course, and 11 files keep
this at 13 MB instead of 42 files and ~50 MB.

**They are silent.** Audio was stripped — the sources were ambient b-roll and
dropping it kept every file well inside the free tier's 50 MB per-file cap.

**Two are approximations.** The photography clip shows a film camera, not a
phone, and the personal-finance spreadsheet is denominated in dollars rather
than naira. Both were the best of what a general stock library had; replace
them first if anyone will be looking closely.
