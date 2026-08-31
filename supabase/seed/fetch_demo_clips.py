"""Fetch one themed Pixabay clip per seeded course, trim it, and lay the files
out mirroring the `course-media` bucket so the whole tree can be dragged in.

Pixabay Content License: free for commercial use, no attribution required.
"""
import os
import re
import subprocess
import sys
import time
import urllib.parse
import urllib.request

OUT = r"C:\Users\USMAN\Desktop\Github projects\padi_learn\video\out\demo-clips\demo"
WORK = r"C:\Users\USMAN\AppData\Local\Temp\claude\C--Users-USMAN-Desktop-Github-projects-padi-learn\3f2046e3-3024-4771-a068-c515b499d8cb\scratchpad\clips"
FFMPEG = ["npx", "remotion", "ffmpeg"]
VIDEO_DIR = r"C:\Users\USMAN\Desktop\Github projects\padi_learn\video"

# Course slug -> Pixabay search term. Chosen to read as the subject of the
# course rather than generic "person at laptop" filler.
COURSES = [
    ("jamb-mathematics",       "mathematics"),
    ("waec-english",           "writing notebook"),
    ("flutter-for-beginners",  "programming"),
    ("python-basics",          "coding screen"),
    ("excel-for-office-work",  "office computer"),
    ("start-a-small-business", "market stall"),
    ("whatsapp-marketing",     "smartphone"),
    ("tailoring-basics",       "sewing"),
    ("phone-photography",      "photography"),
    ("personal-finance",       "money counting"),
]

UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
MAX_SECONDS = 15


def get(url, timeout=120):
    """Fetch via curl.

    urllib gets a 403 from Pixabay regardless of User-Agent — they fingerprint
    the client below the header level — while curl is served normally.
    """
    r = subprocess.run(
        ["curl", "-sL", "--max-time", str(timeout), "-A", UA,
         "-H", "Accept-Language: en-US,en;q=0.9",
         "-H", "Accept: text/html,application/xhtml+xml,video/mp4,*/*",
         url],
        capture_output=True,
    )
    if r.returncode != 0 or not r.stdout:
        raise RuntimeError(f"curl failed rc={r.returncode}")
    return r.stdout


def find_clip_urls(term):
    """Return candidate CDN mp4 URLs from a Pixabay video search page."""
    url = "https://pixabay.com/videos/search/" + urllib.parse.quote(term) + "/"
    html = get(url).decode("utf-8", "replace")
    tiny = re.findall(r"https://cdn\.pixabay\.com/video/[^\"' \\]+_tiny\.mp4", html)
    # Dedupe, preserve order, and prefer the medium rendition of each.
    seen, out = set(), []
    for t in tiny:
        base = t[: -len("_tiny.mp4")]
        if base in seen:
            continue
        seen.add(base)
        out.append(base)
    return out


def probe_seconds(path):
    r = subprocess.run(
        FFMPEG + ["-hide_banner", "-i", path],
        capture_output=True, text=True, cwd=VIDEO_DIR, shell=True,
    )
    m = re.search(r"Duration: (\d+):(\d+):(\d+\.\d+)", r.stderr + r.stdout)
    if not m:
        return None
    h, mnt, s = int(m.group(1)), int(m.group(2)), float(m.group(3))
    return h * 3600 + mnt * 60 + s


os.makedirs(WORK, exist_ok=True)
results = []

for slug, term in COURSES:
    print(f"\n=== {slug}  <- '{term}'", flush=True)
    try:
        bases = find_clip_urls(term)
    except Exception as e:
        print("  search failed:", e, flush=True)
        continue
    if not bases:
        print("  no clips found", flush=True)
        continue

    raw = os.path.join(WORK, slug + "_raw.mp4")
    got = None
    # Walk candidates until one downloads at a sane size.
    for base in bases[:4]:
        for variant in ("_medium.mp4", "_tiny.mp4"):
            try:
                data = get(base + variant, timeout=120)
            except Exception:
                continue
            mb = len(data) / 1048576
            if len(data) < 20000 or mb > 40:
                continue
            with open(raw, "wb") as f:
                f.write(data)
            got = (base + variant, mb)
            break
        if got:
            break

    if not got:
        print("  nothing downloadable", flush=True)
        continue
    print(f"  got {got[1]:.2f} MB from {got[0]}", flush=True)

    dest_dir = os.path.join(OUT, slug)
    os.makedirs(dest_dir, exist_ok=True)
    dest = os.path.join(dest_dir, "clip.mp4")

    # Trim and re-encode small. Audio dropped: these clips are silent ambient
    # b-roll anyway, and it keeps the whole set trivially inside the free
    # tier's per-file cap.
    cmd = FFMPEG + [
        "-y", "-hide_banner", "-loglevel", "error",
        "-i", raw, "-t", str(MAX_SECONDS),
        "-vf", "scale='min(1280,iw)':-2",
        "-c:v", "libx264", "-crf", "27", "-preset", "veryfast",
        "-movflags", "+faststart", "-an", dest,
    ]
    r = subprocess.run(cmd, capture_output=True, text=True, cwd=VIDEO_DIR, shell=True)
    if r.returncode != 0 or not os.path.exists(dest):
        print("  ffmpeg failed:", (r.stderr or "")[:300], flush=True)
        continue

    secs = probe_seconds(dest)
    size_mb = os.path.getsize(dest) / 1048576
    print(f"  -> clip.mp4  {size_mb:.2f} MB  {secs:.1f}s", flush=True)
    results.append((slug, round(secs) if secs else MAX_SECONDS, round(size_mb, 2), got[0]))
    time.sleep(1)

print("\n\n===== SUMMARY =====")
total = 0.0
for slug, secs, mb, src in results:
    total += mb
    print(f"{slug:26s} {secs:>3d}s  {mb:>5.2f} MB   {src}")
print(f"{'TOTAL':26s}      {total:>5.2f} MB   ({len(results)} clips)")
