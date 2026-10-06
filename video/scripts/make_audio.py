"""Synthesise the score and the spot effects for the PadiLearn videos.

    cd video && python scripts/make_audio.py

Writes `public/audio/`: two music beds and nine one-shots. Re-running
overwrites, and the output is deterministic — the noise is drawn from a seeded
generator, so a rebuild produces byte-identical files and does not show up as
a diff for no reason.


WHY SYNTHESISE RATHER THAN DOWNLOAD
-----------------------------------
The whole video pipeline exists to avoid a rights problem: it is code rather
than stock clips so that nothing in it belongs to anybody else. Audio was the
one place that had not caught up. `SOURCES.md` records the previous bed as
CC0 and then spends two paragraphs on why that claim is shakier than it looks
— the licence rests on the artist, not on the Archive item it came from, and
that item is a user-assembled compilation containing other people's work.

Generated audio has no such question. It also lets every cue be tuned to the
exact frame it lands on, which matters because the direction in `theme.ts`
asks for things like "the number stopping is the beat — hit it exactly".


WHAT I CANNOT CHECK
-------------------
I cannot hear this. The script verifies what is measurable — sample rate,
length, peak and RMS level, no clipping, no silence — and the musical choices
below are deliberate rather than arbitrary. But whether it actually sounds
good is not something that can be established by inspecting an array, and
nobody should ship these without listening first.


THE MUSIC
---------
120 BPM, which at 30fps is a beat every 15 frames and a bar every 60, so the
grid lines up with the scene table in `AppAd.tsx` instead of fighting it. The
bed starts at frame 120 rather than 90, one second into the browse scene: it
lets the first visual land in silence, and it puts the closing card at frame
600 exactly eight bars later, so the logo build resolves on a bar line.

Four-bar loop in F: Fmaj9, Am7, B♭maj9, Cadd9. Warm, and it resolves rather
than vamping, which suits something that has to end. The third pass begins on
the closing card, so the last thing heard is the tonic arriving.

Half-time feel: the kick lands on 1, the rim on 3. At 120 BPM that reads as
unhurried rather than busy, which is the brief — "mid-tempo, warm,
Afrobeats-adjacent but understated".

The arrangement is baked in, not automated in Remotion, because which
instruments are playing is a musical decision and belongs with the music. Only
the overall fade is left to the composition.
"""
import math
import os
import struct
import subprocess
import shutil
import sys
import wave

import numpy as np

SR = 48_000
FPS = 30
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(os.path.dirname(HERE), "public", "audio")

rng = np.random.default_rng(20261005)


# --------------------------------------------------------------- primitives

def frames(n: float) -> int:
    """Frames to samples, so cue times can be written in the ad's own units."""
    return int(round(n / FPS * SR))


def sec(n: float) -> int:
    return int(round(n * SR))


def midi(note: int) -> float:
    return 440.0 * 2 ** ((note - 69) / 12)


def adsr(n, a=0.01, d=0.1, s=0.7, r=0.3):
    """Attack/decay/sustain/release over n samples, in seconds except `s`."""
    an, dn, rn = sec(a), sec(d), sec(r)
    sn = max(0, n - an - dn - rn)
    return np.concatenate([
        np.linspace(0, 1, an, endpoint=False) if an else np.zeros(0),
        np.linspace(1, s, dn, endpoint=False) if dn else np.zeros(0),
        np.full(sn, s),
        np.linspace(s, 0, rn) if rn else np.zeros(0),
    ])[:n]


def partials(freq, n, weights, detune=0.0):
    """Additive sine stack. Bandlimited by construction, so no aliasing —
    a naive saw at these pitches would fizz on the top partials."""
    t = np.arange(n) / SR
    out = np.zeros(n)
    for i, w in enumerate(weights, start=1):
        f = freq * i * (1 + detune * (i - 1))
        if f >= SR / 2:
            break
        out += w * np.sin(2 * np.pi * f * t + rng.uniform(0, 2 * np.pi))
    return out


def lowpass(x, cutoff):
    """One-pole lowpass. Gentle, which is what a pad wants."""
    a = math.exp(-2 * math.pi * cutoff / SR)
    out = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        out[i] = acc
    return out


def lowpass_fast(x, cutoff):
    """One-pole magnitude response applied in the frequency domain.

    The time-domain recursion cannot be vectorised in numpy, and running it
    per sample over a twenty-second bed is minutes of Python. Doing it as a
    spectral multiply is instant and, being zero-phase, actually kinder to
    transients than the real thing.
    """
    n = len(x)
    if n == 0:
        return x
    f = np.fft.rfftfreq(n, 1 / SR)
    h = 1.0 / np.sqrt(1.0 + (f / max(cutoff, 1e-6)) ** 2)
    return np.fft.irfft(np.fft.rfft(x) * h, n)


def highpass(x, cutoff):
    return x - lowpass_fast(x, cutoff)


def noise(n):
    return rng.standard_normal(n)


def karplus(freq, n, damp=0.996):
    """Karplus-Strong plucked string.

    The direction for the leaf pop asks for "wood or plucked string, not a
    synth ping", and this is the difference: a filtered noise burst recirculating
    in a delay line decays unevenly across its partials the way a real string
    does, where an enveloped sine does not.
    """
    size = max(2, int(SR / freq))
    buf = list(rng.uniform(-1, 1, size))
    out = np.empty(n)
    for i in range(n):
        v = buf[i % size]
        nxt = damp * 0.5 * (v + buf[(i + 1) % size])
        out[i] = v
        buf[i % size] = nxt
    return out


def _comb(x, d, decay):
    """y[i] = x[i] + decay*y[i-d], done a delay-length at a time.

    Every sample in a block depends only on the sample one block earlier, so
    the recursion runs over n/d blocks of vector arithmetic instead of n
    scalar steps — about six hundred iterations for a twenty-second bed
    rather than a million.
    """
    n = len(x)
    pad = (-n) % d
    y = np.concatenate([x, np.zeros(pad)]).reshape(-1, d)
    for i in range(1, y.shape[0]):
        y[i] += decay * y[i - 1]
    return y.reshape(-1)[:n]


def _allpass(x, d, g):
    """y[i] = -g*x[i] + x[i-d] + g*y[i-d], blocked the same way."""
    n = len(x)
    pad = (-n) % d
    xb = np.concatenate([x, np.zeros(pad)]).reshape(-1, d)
    yb = np.zeros_like(xb)
    prev_x = np.zeros(d)
    prev_y = np.zeros(d)
    for i in range(xb.shape[0]):
        yb[i] = -g * xb[i] + prev_x + g * prev_y
        prev_x, prev_y = xb[i], yb[i]
    return yb.reshape(-1)[:n]


def reverb(x, decay=0.72, mix=0.22):
    """Schroeder reverb: six parallel combs into two allpasses.

    Everything synthesised here is bone dry, and without this it reads as a
    collection of separate beeps rather than sounds sharing a room with the
    picture. The comb delays are mutually prime so their echoes do not pile
    up into a ringing pitch.
    """
    wet = np.zeros_like(x)
    for d in (1557, 1617, 1491, 1422, 1277, 1356):
        wet += _comb(x, d, decay)
    wet /= 6.0
    for d, g in ((225, 0.5), (556, 0.5)):
        wet = _allpass(wet, d, g)
    return (1 - mix) * x + mix * wet


def soft_clip(x):
    return np.tanh(x)


def place(buf, sig, at, gain=1.0):
    """Mix `sig` into `buf` at sample offset `at`, clipping to the buffer."""
    start = max(0, at)
    end = min(len(buf), at + len(sig))
    if end <= start:
        return
    buf[start:end] += gain * sig[start - at: end - at]


def ramp(frame_points, values, n_samples):
    """A gain curve defined at frame numbers, interpolated per sample."""
    xs = np.array([frames(f) for f in frame_points], dtype=np.float64)
    return np.interp(np.arange(n_samples), xs, np.array(values, dtype=np.float64))


# ------------------------------------------------------------------- output

def write_wav(path, mono, peak=0.89):
    x = np.asarray(mono, dtype=np.float64)
    m = np.abs(x).max()
    if m > 0:
        x = x / m * peak
    pcm = (x * 32767).astype("<i2")
    stereo = np.repeat(pcm[:, None], 2, axis=1).tobytes()
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(stereo)
    return x


def ffmpeg():
    found = shutil.which("ffmpeg")
    if found:
        return [found]
    try:
        import imageio_ffmpeg
        return [imageio_ffmpeg.get_ffmpeg_exe()]
    except ImportError:
        return ["npx", "remotion", "ffmpeg"]


FFMPEG = ffmpeg()


def to_mp3(wav_path, mp3_path):
    subprocess.run(
        FFMPEG + ["-y", "-loglevel", "error", "-i", wav_path,
                  "-codec:a", "libmp3lame", "-b:a", "192k", mp3_path],
        check=True,
    )
    os.remove(wav_path)


# ------------------------------------------------------------- spot effects

def sfx_sub():
    """The hook's title landing. One low hit, no music under it."""
    n = sec(1.1)
    t = np.arange(n) / SR
    f = np.linspace(62, 44, n)          # a slight downward bend reads as weight
    body = np.sin(2 * np.pi * np.cumsum(f) / SR)
    click = noise(sec(0.012)) * np.linspace(1, 0, sec(0.012))
    out = body * adsr(n, 0.004, 0.22, 0.28, 0.72)
    place(out, lowpass(click, 900), 0, 0.5)
    return out


def sfx_tick():
    """One course card arriving. Has to survive eleven of them in a row two
    frames apart, so it is very short and has almost no tail."""
    n = sec(0.09)
    click = highpass(noise(n), 1800) * adsr(n, 0.0005, 0.02, 0.0, 0.06)
    blip = np.sin(2 * np.pi * 2400 * np.arange(n) / SR) * adsr(n, 0.001, 0.015, 0.0, 0.03)
    return click * 0.5 + blip * 0.3


def sfx_chime():
    """The progress bar filling. A bell, struck softly."""
    n = sec(1.5)
    # Inharmonic partials are what separate a bell from an organ.
    out = np.zeros(n)
    base = midi(86)
    for mult, w, dec in ((1.0, 1.0, 1.6), (2.76, 0.5, 1.0), (5.40, 0.25, 0.7), (8.93, 0.12, 0.5)):
        t = np.arange(n) / SR
        out += w * np.sin(2 * np.pi * base * mult * t) * np.exp(-t / dec)
    return out


def sfx_rise():
    """Ascending ticks under the naira figure while it counts.

    Twelve of them over the count, each a step up a pentatonic scale, getting
    slightly louder. The last one is deliberately absent — the landing is a
    separate cue, so the rise can be retimed without moving the resolution.
    """
    n = sec(2.7)
    out = np.zeros(n)
    steps = [0, 2, 4, 7, 9, 12, 14, 16, 19, 21, 24, 26]
    for i, st in enumerate(steps):
        at = sec(i * (2.4 / len(steps)))
        ln = sec(0.3)
        t = np.arange(ln) / SR
        tone = np.sin(2 * np.pi * midi(69 + st) * t) * np.exp(-t / 0.09)
        place(out, tone, at, 0.25 + 0.05 * i / len(steps))
    return out


def sfx_land():
    """The number stopping. One resolved note, per the direction."""
    n = sec(2.0)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for note, w in ((65, 1.0), (69, 0.7), (72, 0.7), (77, 0.45)):   # F A C F
        out += w * partials(midi(note), n, [1, 0.4, 0.18, 0.08])
    return out * adsr(n, 0.006, 0.5, 0.25, 1.4)


def sfx_whoosh():
    """The bowl of the P sweeping out."""
    n = sec(0.8)
    t = np.arange(n) / SR
    band = noise(n)
    swept = highpass(lowpass_fast(band, 2600), 420)
    shape = np.sin(np.pi * np.clip(t / t[-1], 0, 1)) ** 1.6
    return swept * shape


def sfx_pluck():
    """The leaf springing from the shoot. Plucked string, not a ping."""
    n = sec(1.3)
    return karplus(midi(76), n, damp=0.9965) * adsr(n, 0.001, 0.3, 0.45, 0.9)


def sfx_chalk():
    """Texture under a lesson figure drawing itself. Barely there by design:
    it should register as the room the board is in, not as an effect."""
    n = sec(2.6)
    t = np.arange(n) / SR
    grain = lowpass_fast(highpass(noise(n), 1400), 5200)
    # Uneven, like a hand moving rather than a machine.
    wobble = 0.5 + 0.5 * np.abs(np.sin(2 * np.pi * 1.7 * t + np.sin(2 * np.pi * 0.6 * t)))
    return grain * wobble * np.minimum(1, np.minimum(t / 0.3, (t[-1] - t) / 0.4))


def sfx_mark():
    """A statement appearing in the announcement. Soft, low, barely a sound —
    the piece is a notice, and a notice does not chirp."""
    n = sec(0.7)
    t = np.arange(n) / SR
    body = (np.sin(2 * np.pi * midi(53) * t) * 0.8
            + np.sin(2 * np.pi * midi(60) * t) * 0.3)
    return body * np.exp(-t / 0.18)


# ------------------------------------------------------------------ the bed

BAR = 60          # frames, at 120bpm / 30fps
BEAT = 15
BED_START = 120   # frame the bed enters on
BED_FRAMES = 600  # to frame 720, the end of the cut

# Fmaj9 - Am7 - Bbmaj9 - Cadd9, voiced to sit under the picture rather than
# on top of it.
CHORDS = [
    [53, 60, 65, 69, 72, 79],   # F   A  C  E(as 9th above) ...
    [57, 64, 69, 72, 76],       # Am7
    [58, 65, 70, 74, 77],       # Bbmaj9
    [60, 67, 72, 76, 74],       # Cadd9
]


def bed_ad():
    n = frames(BED_FRAMES)
    pad = np.zeros(n)
    pluck = np.zeros(n)
    shaker = np.zeros(n)
    kick = np.zeros(n)
    rim = np.zeros(n)

    bars = BED_FRAMES // BAR          # 10
    for b in range(bars):
        chord = CHORDS[b % 4]
        at = frames(b * BAR)
        ln = frames(BAR) + sec(0.6)   # overlap so chords bleed into each other

        voice = np.zeros(ln)
        for note in chord:
            voice += partials(midi(note), ln, [1, 0.35, 0.14, 0.06, 0.03], detune=0.0012)
        voice /= len(chord)
        place(pad, voice * adsr(ln, 0.35, 0.5, 0.75, 0.9), at)

        # A two-note figure per bar, pentatonic, never on the downbeat so it
        # answers the chord instead of doubling it.
        for beat, deg in ((1.5, 0), (3.0, 2)):
            pn = sec(0.5)
            t = np.arange(pn) / SR
            f = midi(chord[-1] + [0, 2, 4, 7, 9][deg % 5])
            tone = (np.sin(2 * np.pi * f * t) + 0.3 * np.sin(2 * np.pi * 2 * f * t))
            place(pluck, tone * np.exp(-t / 0.16), at + frames(beat * BEAT), 0.5)

        for eighth in range(8):
            sn = sec(0.055)
            hit = highpass(noise(sn), 5500) * np.exp(-np.arange(sn) / SR / 0.012)
            accent = 1.0 if eighth % 2 == 0 else 0.55
            place(shaker, hit, at + frames(eighth * BEAT / 2), 0.22 * accent)

        # Half-time: kick on 1, rim on 3.
        kn = sec(0.5)
        t = np.arange(kn) / SR
        f = 115 * np.exp(-t / 0.028) + 44
        place(kick, np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.16), at)
        rn = sec(0.18)
        tr = np.arange(rn) / SR
        place(rim, (highpass(noise(rn), 2200) * 0.6
                    + np.sin(2 * np.pi * 320 * tr) * 0.4) * np.exp(-tr / 0.03),
              at + frames(2 * BEAT), 0.5)

    # Arrangement, in absolute frames of the ad. Scene table in AppAd.tsx:
    # browse 90, lesson 225, learn 389, teach 494, cta 600, end 720.
    def g(points, values):
        return ramp([p - BED_START for p in points], values, n)

    # Each curve reaches its level EARLY in the scene it belongs to and holds.
    # Ramping straight from one scene boundary to the next means a part only
    # arrives as its scene ends: the first cut did that to the pad and the
    # pluck, and measuring the bed showed browse 0.4 dB above the lesson
    # scene that was supposed to drop away under it.
    pad_g    = g([120, 165, 225, 262, 389, 430, 494, 600, 690, 720],
                 [0.0, 0.62, 0.62, 0.22, 0.22, 0.34, 0.52, 0.70, 0.70, 0.0])
    pluck_g  = g([120, 170, 225, 240, 389, 430, 494, 600, 655, 720],
                 [0.0, 0.34, 0.34, 0.00, 0.00, 0.30, 0.40, 0.30, 0.00, 0.0])
    shaker_g = g([120, 175, 225, 248, 389, 432, 494, 600, 640, 720],
                 [0.0, 0.55, 0.55, 0.00, 0.00, 0.28, 0.55, 0.40, 0.00, 0.0])
    # A kick arrives, it does not fade in. Stepped over two frames so the
    # first hit of the teach scene is the first thing you hear of it.
    kick_g   = g([120, 492, 494, 600, 648, 720], [0.0, 0.0, 0.78, 0.80, 0.0, 0.0])
    rim_g    = g([120, 492, 494, 600, 648, 720], [0.0, 0.0, 0.45, 0.45, 0.0, 0.0])

    mix = (pad * pad_g * 0.55 + pluck * pluck_g * 0.30
           + shaker * shaker_g + kick * kick_g + rim * rim_g)
    return soft_clip(reverb(mix, decay=0.70, mix=0.18) * 1.1)


def bed_teachers():
    """The announcement bed. 18s, far sparser than the ad's.

    A notice does not need a groove. This is a low drone with a slow pulse and
    one chord change, so the statements land in something rather than in
    silence, and the only real movement is reserved for the closing card.
    """
    n = frames(540)
    t = np.arange(n) / SR
    out = np.zeros(n)

    # Two sustained voices a fifth apart, drifting very slowly.
    for note, w in ((41, 0.9), (48, 0.5), (60, 0.22)):
        f = midi(note)
        drift = 1 + 0.0016 * np.sin(2 * np.pi * 0.07 * t + note)
        out += w * np.sin(2 * np.pi * f * np.cumsum(drift) / SR)

    # A slow pulse on the bar, felt rather than heard.
    for b in range(10):
        pn = sec(1.2)
        tp = np.arange(pn) / SR
        hit = np.sin(2 * np.pi * midi(29) * tp) * np.exp(-tp / 0.3)
        place(out, hit, frames(b * 54), 0.5)

    # Lift into the closing card (beat 5 of 6, frame 486 of 540).
    lift = ramp([0, 300, 420, 486, 520, 540], [0.34, 0.42, 0.5, 0.72, 0.72, 0.0], n)
    tail = np.minimum(1.0, t / 1.2)
    return soft_clip(reverb(out * lift * tail, decay=0.8, mix=0.3) * 0.9)


def bed_sting():
    """Four seconds under the standalone logo build.

    A swell that arrives on the tonic as the mark settles, and nothing else —
    a bumper has no time for an arrangement. The shine at frame 84 is the
    moment it should feel resolved, so the chord completes just before it and
    the tail rings out past the end of the picture.
    """
    n = frames(120)
    t = np.arange(n) / SR
    out = np.zeros(n)

    # F major, built up a voice at a time so it blooms rather than starting.
    for note, w, enter in ((41, 0.9, 0.00), (53, 0.6, 0.25), (60, 0.45, 0.55),
                           (65, 0.40, 0.95), (72, 0.28, 1.35)):
        v = partials(midi(note), n, [1, 0.3, 0.12, 0.05], detune=0.001)
        gate = np.clip((t - enter) / 0.5, 0, 1)
        out += w * v * gate

    swell = ramp([0, 20, 84, 104, 120], [0.0, 0.35, 0.85, 0.85, 0.0], n)
    return soft_clip(reverb(out * swell * 0.5, decay=0.78, mix=0.3))


# ------------------------------------------------------------------ verify

def report(name, x):
    peak = float(np.abs(x).max())
    rms = float(np.sqrt((x ** 2).mean()))
    dbfs = 20 * math.log10(rms) if rms > 0 else -999
    clipped = int((np.abs(x) > 0.999).sum())
    flag = "  <-- CHECK" if (clipped or rms < 1e-4) else ""
    print(f"  {name:22s} {len(x)/SR:6.2f}s  peak {peak:.3f}  rms {dbfs:7.1f} dBFS"
          f"  clipped {clipped}{flag}")
    return clipped == 0 and rms > 1e-4


def main():
    os.makedirs(OUT, exist_ok=True)
    ok = True

    print("spot effects")
    for name, fn in [
        ("sfx-sub", sfx_sub), ("sfx-tick", sfx_tick), ("sfx-chime", sfx_chime),
        ("sfx-rise", sfx_rise), ("sfx-land", sfx_land), ("sfx-whoosh", sfx_whoosh),
        ("sfx-pluck", sfx_pluck), ("sfx-chalk", sfx_chalk), ("sfx-mark", sfx_mark),
    ]:
        sig = fn()
        written = write_wav(os.path.join(OUT, name + ".wav"), sig)
        ok &= report(name + ".wav", written)

    print("beds")
    for name, fn in (("bed-ad-v2", bed_ad), ("bed-teachers", bed_teachers),
                     ("bed-sting-v2", bed_sting)):
        sig = fn()
        wav = os.path.join(OUT, name + ".wav")
        written = write_wav(wav, sig, peak=0.80)
        ok &= report(name + ".mp3", written)
        to_mp3(wav, os.path.join(OUT, name + ".mp3"))

    print("\nWritten to public/audio/.")
    print("NOTHING HERE HAS BEEN LISTENED TO. Levels and lengths check out;")
    print("whether it sounds good is not a thing a script can tell you.")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
