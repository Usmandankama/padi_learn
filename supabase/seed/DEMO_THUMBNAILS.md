# Demo course thumbnails

Eleven photographs, one per seeded course. **1.4 MB total**, 1280×720 JPEG.
`courses.thumbnail_url` already points at these exact paths, so uploading them
is the only remaining step.

Files are at **`video/out/demo-thumbs/demo/`** (gitignored — regenerable stock
photography does not belong in the repo). `fetch_demo_thumbs.py` beside this
file rebuilds the set.

## Upload

Supabase dashboard → Storage → **`course-thumbnails`** → drag the `demo` folder
into the bucket root. The bucket is public, so the URLs resolve immediately.

Largest file is 335 KB, so the size ceiling that dropped six of the video
uploads is not a risk here.

## The design decision

**Plain photography. No text baked in, no gradient wash, no badge.**

The card prints the title, instructor and price *underneath* the image
(`course_card.dart`), so anything written into the picture collides with what
the card already says — and stock photos with type dropped on top are exactly
the tacky look to avoid. What makes a grid read as one product is consistent
crop, consistent size, and a subject that is legible at ~180px wide. That is
what these do.

Cover-cropped to 16:9 here rather than letterboxed, because the card crops to
fill anyway — deciding the framing once makes it predictable.

## What it took to get here

Three passes, because the first results were bad in ways only looking could
catch:

- **`python-basics` returned a literal snake.** Then, after rewording, a clay
  figurine of a person at a computer. It is now real source code on screen.
- **`welcome-to-padilearn` returned a cartoon dog playing a guitar.** It is now
  children working at desks in a classroom — the strongest image in the set for
  this market.
- **`excel-for-office-work` was a flat "RISK ASSESSMENT" illustration**, and
  the search needed `image_type=photo` before it would stop returning vector
  art. Illustrations among photographs are what break the grid's consistency.
- **`whatsapp-marketing` was the blue "SOCIAL" tech-collage** — the single most
  dated look in stock photography.
- **`personal-finance` returned US dollars, then Indian rupees.** Foreign
  banknotes are as wrong as each other for a course priced in naira, so the
  final pick avoids currency in frame entirely.

## Known imperfections

- **`personal-finance`** is a handwritten ledger whose columns, read closely,
  are a joke ("Happiness / Troubles, Failures, Defeats"). Illegible at card
  size and it reads correctly as *handwritten budgeting*, but it would not
  survive someone zooming in.
- **`phone-photography`** shows a film SLR, not a phone.
- **`whatsapp-marketing`** leans laptop rather than phone.

All three are the best a general stock library offered. Replace them first if
the catalogue ever gets real scrutiny.

## Licence

[Pixabay Content License](https://pixabay.com/service/license-summary/): free
for commercial use, no attribution required. The limit is redistributing their
content *as the product* — fine as course artwork, not fine as a stock library
of your own.
