"""Fetch one photo per seeded course and crop it to a course thumbnail.

Deliberately plain photography — no text baked in, no gradient wash, no
badge. The card already prints the title, author and price *underneath* the
image (see course_card.dart), so anything written into the picture would
collide with it, and stock photos with type dropped on top are exactly the
"tacky" look to avoid. What makes a grid of these read as one product is
consistent crop, consistent size and a subject that is obvious at 180px wide.

Output: 1280x720 JPEG, quality 82, mirroring the course-thumbnails bucket.
"""
import os
import re
import subprocess
import urllib.parse

OUT = r"C:\Users\USMAN\Desktop\Github projects\padi_learn\video\out\demo-thumbs\demo"
WORK = r"C:\Users\USMAN\AppData\Local\Temp\claude\C--Users-USMAN-Desktop-Github-projects-padi-learn\3f2046e3-3024-4771-a068-c515b499d8cb\scratchpad\thumbs"
FFMPEG = ["npx", "remotion", "ffmpeg"]
VIDEO_DIR = r"C:\Users\USMAN\Desktop\Github projects\padi_learn\video"
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"

# slug, search term, which candidate to take (offset avoids two courses
# landing on the same picture, and lets a bad first hit be stepped over).
COURSES = [
    ("welcome-to-padilearn",   "students learning together", 0),
    ("jamb-mathematics",       "mathematics blackboard",     0),
    ("waec-english",           "english book writing",       1),
    ("flutter-for-beginners",  "mobile app development",     0),
    ("python-basics",          "python code",                0),
    ("excel-for-office-work",  "spreadsheet data",           0),
    ("start-a-small-business", "african market trader",      0),
    ("whatsapp-marketing",     "social media phone",         1),
    ("tailoring-basics",       "tailor sewing fabric",       0),
    ("phone-photography",      "photographer camera",        2),
    ("personal-finance",       "savings money planning",     1),
]


def curl(url, timeout=90):
    r = subprocess.run(
        ["curl", "-sL", "--max-time", str(timeout), "-A", UA,
         "-H", "Accept-Language: en-US,en;q=0.9", url],
        capture_output=True,
    )
    if r.returncode != 0 or not r.stdout:
        raise RuntimeError("curl failed")
    return r.stdout


def candidates(term):
    url = "https://pixabay.com/images/search/" + urllib.parse.quote(term) + "/"
    html = curl(url).decode("utf-8", "replace")
    urls = re.findall(
        r"https://cdn\.pixabay\.com/photo/[^\"' ]+_1280\.(?:jpg|jpeg)", html)
    seen, out = set(), []
    for u in urls:
        if u in seen:
            continue
        seen.add(u)
        out.append(u)
    return out


os.makedirs(WORK, exist_ok=True)
results = []

for slug, term, offset in COURSES:
    print(f"\n=== {slug}  <- '{term}' (+{offset})", flush=True)
    try:
        cands = candidates(term)
    except Exception as e:
        print("  search failed:", e, flush=True)
        continue
    if len(cands) <= offset:
        print(f"  only {len(cands)} candidates", flush=True)
        continue

    raw = os.path.join(WORK, slug + ".jpg")
    picked = None
    for u in cands[offset:offset + 4]:
        try:
            data = curl(u)
        except Exception:
            continue
        if len(data) < 30000:
            continue
        with open(raw, "wb") as f:
            f.write(data)
        picked = u
        break

    if not picked:
        print("  nothing downloadable", flush=True)
        continue

    os.makedirs(OUT, exist_ok=True)
    dest = os.path.join(OUT, slug + ".jpg")

    # Cover-crop to 16:9 rather than letterbox: the card crops to fill anyway,
    # so doing it here means the framing is decided once and is predictable.
    r = subprocess.run(
        FFMPEG + [
            "-y", "-hide_banner", "-loglevel", "error", "-i", raw,
            "-vf", "scale=1280:720:force_original_aspect_ratio=increase,"
                   "crop=1280:720",
            "-q:v", "4", dest,
        ],
        capture_output=True, text=True, cwd=VIDEO_DIR, shell=True,
    )
    if r.returncode != 0 or not os.path.exists(dest):
        print("  ffmpeg failed:", (r.stderr or "")[:200], flush=True)
        continue

    kb = os.path.getsize(dest) / 1024
    print(f"  -> {slug}.jpg  {kb:.0f} KB", flush=True)
    results.append((slug, round(kb), picked))

print("\n\n===== SUMMARY =====")
total = 0
for slug, kb, src in results:
    total += kb
    print(f"{slug:26s} {kb:>5d} KB  {src}")
print(f"{'TOTAL':26s} {total:>5d} KB  ({len(results)} thumbnails)")
