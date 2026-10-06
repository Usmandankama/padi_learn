# Audio sources and licences

**All of it is ours.** Every file here is synthesised by
`../../scripts/make_audio.py` — three music beds and nine spot effects, from
oscillators, filtered noise and a Karplus-Strong string. Nothing was
downloaded, sampled or recorded, so there is no licence, no attribution and
nobody to ask.

```bash
cd video && python scripts/make_audio.py
```

Deterministic: the noise comes from a seeded generator, so a rebuild produces
byte-identical files and does not show up as a diff for no reason.

| File | What it is | Used by |
|---|---|---|
| `bed-ad-v2.mp3` | 20s, 120bpm, F–Am–B♭–C | `AppAd`, from frame 120 |
| `bed-teachers.mp3` | 18s drone and slow pulse | `TeacherCall` |
| `bed-sting-v2.mp3` | 4s swell resolving on F | `LogoSting` |
| `sfx-sub.wav` | Low hit, bending down | Hook title landing |
| `sfx-tick.wav` | 90ms click | Each course card arriving |
| `sfx-chime.wav` | Inharmonic bell | Progress bar filling |
| `sfx-rise.wav` | Twelve ascending ticks | Under the naira count |
| `sfx-land.wav` | Resolved F chord | The number stopping |
| `sfx-whoosh.wav` | Swept noise | The bowl of the P sweeping |
| `sfx-pluck.wav` | Plucked string | The leaf popping |
| `sfx-chalk.wav` | Soft grain | Under a lesson figure drawing |
| `sfx-mark.wav` | Low soft mark | Each announcement statement |

One-shots are normalised WAV; balance is set per cue by the `volume` prop at
the call site, which is where a mix belongs.

## Why this replaced the downloaded tracks

Two CC0 tracks by HoliznaCC0 used to sit here, and this file used to spend two
paragraphs explaining why that was shakier than it looked: the licence claim
rested on the artist rather than on the Archive item they came from, and that
item was a user-assembled compilation containing other artists' work. The
honest summary was that nobody had verified it.

The whole video pipeline exists to avoid exactly that — it is code rather than
stock footage so that nothing in it belongs to anyone else. Audio was the last
place that had not caught up. Synthesising it closes the question, and it
also lets every cue be written to the frame it lands on, which a licensed
track cannot do.

## Nobody has listened to this

The generator checks sample rate, length, peak, RMS and clipping, and the
renders were onset-analysed to confirm each cue fires on the intended frame.
None of that establishes that it sounds good, which is not a property you can
read off an array.

**Listen before this ships.** If something is wrong, the fix is a number in
`make_audio.py` or a `volume` at the call site, then a re-render — not a trip
to a stock library.
