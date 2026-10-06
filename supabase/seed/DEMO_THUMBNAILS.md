# Demo course thumbnails

Twelve images, one per seeded course. **364 KB total**, 1280×720 JPEG.
`courses.thumbnail_url` already points at these exact paths, so uploading them
is the only remaining step.

Files are at **`video/out/demo-thumbs/demo/`** (gitignored — regenerable).
`import_lesson_videos.py` beside this file rebuilds the set, and also writes a
copy into `video/public/thumbs/` for the ad to render from, so the card art in
the ad and the card art in the app are the same file.

## Upload

Supabase dashboard → Storage → **`course-thumbnails`** → drag the `demo` folder
into the bucket root. The bucket is public, so the URLs resolve immediately.

## What they are

Not photographs. Each one is a frame of that course's own lesson video, taken
at 13 seconds — the one moment the figure and the formula are both on the board
and the takeaway has not landed yet, which is the fullest frame that is still
legible shrunk to a 126px-wide card.

Then inverted to dark. The lesson boards are near-white (`#FBFAF7`), and a
near-white thumbnail inside a white card on a white marketplace reads as a
broken image rather than a deliberate one. The inversion flips *lightness*
while keeping hue and saturation, so the board goes navy and the ink comes back
as light green and near-white — the app's own palette — and what you notice at
card size is the silhouette of the figure. A plain negate would have done the
board correctly and turned every green line magenta.

`welcome-to-padilearn.jpg` is the exception: a frame of the ad's opening card,
green with "Everybody sabi something." on it.

## Why no type on them

The card prints the title, author and price *underneath* the image
(`course_card.dart`), so anything written into the picture collides with it,
and the one thing that would collide hardest is the course title repeated. The
crop keeps the diagram; the only text left in frame is a few pixels tall and
reads as texture.

That constraint is inherited from the previous set of thumbnails, which were
stock photography fetched by `fetch_demo_thumbs.py` — now retired, see the
banner at the top of that file.

## Consistency

What makes a grid of these read as one product is that they genuinely are one
set: same source, same timecode, same treatment, same palette, and a different
figure in each. Eleven different shapes — a parabola, a balance, two circuits,
a spreadsheet, a halving array, a type ladder — so the catalogue does not look
generated, which it is, but should not look.
