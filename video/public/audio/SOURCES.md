# Audio sources and licences

Both tracks are by **HoliznaCC0**, who releases their catalogue under
**CC0 1.0 Universal** — a dedication to the public domain. No attribution is
required, the dedication cannot be revoked, and commercial use is permitted.

| File | Track | Used in |
|---|---|---|
| `bed-ad.mp3` | HoliznaCC0 — *Projector Screen (LoFi, Happy)* | `AppAd`, from the browse scene onward |
| `bed-sting.mp3` | HoliznaCC0 — *Adventure Begins Loop* | `LogoSting` |

Downloaded from the Internet Archive item
[`06-holizna-cc-0-break-from-reality-lo-fi-peaceful-.mp-3`](https://archive.org/details/06-holizna-cc-0-break-from-reality-lo-fi-peaceful-.mp-3).
Both are 320 kbps, 48 kHz stereo.

## Two caveats worth reading before this ships

**The licence claim rests on the artist, not on that Archive item.** The item
itself carries no `licenseurl` in its metadata, and it is a user-assembled
compilation that also contains tracks by other artists (Brentin Davis,
VibeDepot) whose terms have *not* been checked. Only the HoliznaCC0-credited
files were taken. The authoritative CC0 statement is on the artist's own
pages — [Free Music Archive](https://freemusicarchive.org/music/holiznacc0/)
shows "CC0 1.0 Universal" on their albums. Verify there, not here, before
anything goes public.

**Nobody has listened to these.** They were chosen from title, genre tag and
duration; audio cannot be judged by inspecting it. Treat both as placeholders
that prove the pipeline, not as a scoring decision. Swapping is a file
replacement — keep the same names and nothing else changes.

## What is still missing

The direction in `src/theme.ts` asks for things a music bed cannot supply:

- **Voiceover.** Five lines, written, unrecorded.
- **Spot effects** — the UI ticks as cards land, the chime on the progress bar,
  the ascending counter under the naira figure, and for the sting a whoosh on
  the bowl sweep and a soft plucked note as the leaf opens. A sting really
  wants designed sound rather than music; the bed on it now is there so the
  file is not silent, not because it is right.
- **Ducking.** Once there is a voiceover, the bed needs to drop under it. The
  `volume` prop takes a per-frame function, so that is an envelope edit rather
  than new plumbing.
