"""Import the eleven PadiLearn lesson videos and build everything downstream
of them: bucket-ready clips, course thumbnails, and the copies the Remotion ad
renders from.

The videos themselves are produced by a separate project
(`PadiLearn-lesson-videos`), which is their source of truth. This script is the
boundary: it takes those MP4s and lays them out the way this repo needs them,
so nothing here has to know how they were made.

    python supabase/seed/import_lesson_videos.py [SOURCE_DIR]

SOURCE_DIR defaults to the sibling-project path below. Re-running is safe and
overwrites, which is the point — rebuild a lesson over there, run this, and the
catalogue, the thumbnails and the ad all pick it up.


WHAT IT WRITES
--------------
All into the Remotion workspace at `VIDEO` (below), outside this repo:

  video/public/lessons/<slug>.mp4    the ad render reads these
  video/public/thumbs/<slug>.jpg     card art for the ad's mock grid
  video/out/demo-clips/demo/...      drag into `course-media`
  video/out/demo-thumbs/demo/...     drag into `course-thumbnails`

The `out/` trees mirror the bucket layout exactly so the whole folder can be
dropped into Supabase Storage in one go.


THE THUMBNAILS
--------------
Taken at t=13s, which is the one moment the figure and the formula are both on
the board and the takeaway has not landed yet — the fullest frame that is still
legible shrunk to a 126px-wide course card.

Then inverted to dark. The lesson boards are near-white (#FBFAF7), and a
near-white thumbnail inside a white card on a white marketplace reads as a
broken image rather than a deliberate one. Inverting *lightness* while keeping
hue and saturation turns the board navy and the ink into light green and
near-white, which is the app's palette anyway, and makes each figure's silhouette
the thing you notice at card size. A plain `negate` would have worked for the
board and turned every green line magenta.

The retired `fetch_demo_thumbs.py` (now only in git history) argued against
type baked into a thumbnail, because the card prints the title underneath. That still holds and these obey it: what the
crop keeps is the diagram, and the only text at this size is unreadable texture.
"""
import os
import shutil
import subprocess
import sys

import numpy as np
from PIL import Image

DEFAULT_SOURCE = (
    r"C:\Users\USMAN\Desktop\Groundwork Tech ltd\Projects\PadiLearn-lesson-videos"
)

#: The Remotion workspace. It lived in this repo as `video/` until 2026-10-07,
#: when it moved out with the rest of the marketing media.
VIDEO = r"C:\Users\USMAN\Desktop\Groundwork Tech ltd\Projects\PadiLearn-media\video"

PUBLIC_CLIPS = os.path.join(VIDEO, "public", "lessons")
PUBLIC_THUMBS = os.path.join(VIDEO, "public", "thumbs")
BUCKET_CLIPS = os.path.join(VIDEO, "out", "demo-clips", "demo")
BUCKET_THUMBS = os.path.join(VIDEO, "out", "demo-thumbs", "demo")

#: Frame to freeze for the thumbnail. See THE THUMBNAILS above.
POSTER_AT = "13.0"

#: Board background after inversion. The app's `richBlack`, so the thumbnails
#: sit in the same palette as every other dark surface in the product.
NAVY = np.array([0x0D, 0x1B, 0x2A], dtype=float) / 255.0

#: source file stem -> course slug. The slug is what the bucket key, the
#: thumbnail name and `demo_catalogue.sql` all agree on, so this table is the
#: single place the two projects' naming is reconciled.
LESSONS = [
    ("01-physics-projectile-motion", "waec-physics"),
    ("02-maths-completing-the-square", "waec-mathematics"),
    ("03-chemistry-the-mole", "waec-chemistry"),
    ("04-bookkeeping-accounting-equation", "bookkeeping"),
    ("05-pricing-break-even", "pricing-and-margins"),
    ("06-tailoring-bust-dart", "tailoring"),
    ("07-electrical-series-parallel", "electrical-work"),
    ("08-excel-index-match", "excel-for-business"),
    ("09-programming-binary-search", "programming-fundamentals"),
    ("10-design-type-scale", "graphic-design"),
    ("11-poultry-feed-conversion", "broiler-farming"),
]


def ffmpeg():
    """Locate an ffmpeg, preferring one that is already installed.

    imageio-ffmpeg ships its own binary and is already a dependency of the
    lesson-video renderer, so on the machine that makes these videos it is
    always present. `npx remotion ffmpeg` is the fallback; it runs with `VIDEO`
    as its working directory, so it works once that workspace's
    `node_modules` is installed.
    """
    found = shutil.which("ffmpeg")
    if found:
        return [found]
    try:
        import imageio_ffmpeg

        return [imageio_ffmpeg.get_ffmpeg_exe()]
    except ImportError:
        pass
    return ["npx", "remotion", "ffmpeg"]


FFMPEG = ffmpeg()


def run(args):
    subprocess.run(
        FFMPEG + ["-y", "-loglevel", "error"] + args,
        check=True,
        cwd=VIDEO,
    )


def to_dark(image):
    """Invert lightness, keeping hue and saturation, over a navy board.

    HSL rather than a straight `255 - x`: inverting RGB rotates hue to the
    complement, so the brand green would come back magenta. Inverting only L
    keeps every line the colour it was and just swaps which end of the scale
    the board and the ink sit at.
    """
    rgb = np.asarray(image.convert("RGB"), dtype=float) / 255.0
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    high, low = rgb.max(-1), rgb.min(-1)
    lightness = (high + low) / 2.0
    chroma = high - low

    denominator = np.where(lightness < 0.5, high + low, 2.0 - high - low)
    saturation = np.where(chroma == 0, 0.0, chroma / np.maximum(denominator, 1e-9))

    hue = np.zeros_like(lightness)
    coloured = chroma > 0
    from_r = coloured & (high == r)
    from_g = coloured & (high == g) & ~from_r
    from_b = coloured & (high == b) & ~from_r & ~from_g
    with np.errstate(invalid="ignore", divide="ignore"):
        hue[from_r] = ((g - b)[from_r] / chroma[from_r]) % 6
        hue[from_g] = ((b - r)[from_g] / chroma[from_g]) + 2
        hue[from_b] = ((r - g)[from_b] / chroma[from_b]) + 4
    hue *= 60.0

    flipped = 1.0 - lightness
    c = (1.0 - np.abs(2.0 * flipped - 1.0)) * saturation
    x = c * (1.0 - np.abs((hue / 60.0) % 2 - 1.0))
    m = flipped - c / 2.0

    out = np.zeros_like(rgb)
    sector = (hue // 60).astype(int) % 6
    for index, channels in enumerate(
        [(c, x, 0), (x, c, 0), (0, c, x), (0, x, c), (x, 0, c), (c, 0, x)]
    ):
        mask = sector == index
        for channel, value in enumerate(channels):
            out[..., channel][mask] = value[mask] if hasattr(value, "shape") else 0.0
    out += m[..., None]

    # Ink keeps its inverted colour; board fades to navy rather than to the
    # near-black that a straight lightness flip would give it. 1.35 is a gain
    # that holds the thin 1px rules visible after the downscale to card size.
    ink = np.clip((1.0 - lightness) * 1.35, 0.0, 1.0)[..., None]
    blended = NAVY * (1.0 - ink) + out * ink
    return Image.fromarray((np.clip(blended, 0, 1) * 255).astype("uint8"))


def main():
    source = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_SOURCE
    if not os.path.isdir(source):
        sys.exit(
            "Source folder not found: %s\n"
            "Pass the PadiLearn-lesson-videos checkout as the first argument."
            % source
        )

    for directory in (PUBLIC_CLIPS, PUBLIC_THUMBS, BUCKET_THUMBS):
        os.makedirs(directory, exist_ok=True)

    missing = [
        stem
        for stem, _ in LESSONS
        if not os.path.isfile(os.path.join(source, stem + ".mp4"))
    ]
    if missing:
        sys.exit("Missing in %s:\n  %s" % (source, "\n  ".join(missing)))

    for stem, slug in LESSONS:
        src = os.path.join(source, stem + ".mp4")

        # The clips already are what the app wants — 1280x720, 30fps, silent,
        # about half a megabyte — so they are copied, not re-encoded. A
        # re-encode here would only lose a generation for no gain.
        shutil.copyfile(src, os.path.join(PUBLIC_CLIPS, slug + ".mp4"))
        course_dir = os.path.join(BUCKET_CLIPS, slug)
        os.makedirs(course_dir, exist_ok=True)
        shutil.copyfile(src, os.path.join(course_dir, "clip.mp4"))

        poster = os.path.join(PUBLIC_THUMBS, slug + ".png")
        run(["-ss", POSTER_AT, "-i", src, "-frames:v", "1", poster])
        thumb = to_dark(Image.open(poster))
        os.remove(poster)

        for destination in (
            os.path.join(PUBLIC_THUMBS, slug + ".jpg"),
            os.path.join(BUCKET_THUMBS, slug + ".jpg"),
        ):
            thumb.save(destination, "JPEG", quality=82, optimize=True)

        print("  %-26s %s" % (slug, os.path.basename(src)))

    print(
        "\n%d lessons imported.\n"
        "  render inputs  video/public/lessons, video/public/thumbs\n"
        "  upload to course-media       video/out/demo-clips/demo\n"
        "  upload to course-thumbnails  video/out/demo-thumbs/demo"
        % len(LESSONS)
    )

    # The staging trees mirror the buckets, so anything left over from an
    # earlier catalogue would be uploaded alongside the current one and sit
    # there unreferenced. Reported rather than deleted: `welcome-to-padilearn`
    # is a legitimate resident that this script does not produce (it is the
    # rendered ad), and guessing which strays are safe to remove is not this
    # script's call to make.
    known = {slug for _, slug in LESSONS} | {"welcome-to-padilearn"}
    stale = sorted(
        name
        for name in os.listdir(BUCKET_CLIPS)
        if os.path.isdir(os.path.join(BUCKET_CLIPS, name)) and name not in known
    )
    if stale:
        print(
            "\nNot from this catalogue, still in video/out/demo-clips/demo:\n  %s\n"
            "Delete them before uploading, or they go into the bucket too."
            % "\n  ".join(stale)
        )


if __name__ == "__main__":
    main()
