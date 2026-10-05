import React from 'react';
import {
  AbsoluteFill,
  Audio,
  Easing,
  Sequence,
  interpolate,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from 'remotion';
import {loadFont as loadPoppins} from '@remotion/google-fonts/Poppins';
import {loadFont as loadPlayfair} from '@remotion/google-fonts/PlayfairDisplay';
import {colors, FPS} from './theme';
import {announcement} from './announcement';
import {LogoMark} from './components/LogoMark';

const {fontFamily: poppins} = loadPoppins();
const {fontFamily: playfair} = loadPlayfair();

/**
 * The "first teachers" announcement.
 *
 * Deliberately nothing like `AppAd`. That one is a product tour: phones,
 * screens, a marketplace, a lesson playing. This is a notice — type on a dark
 * ground, one statement at a time, built around a single number. The two
 * should not be mistakeable for each other at a glance, because they are
 * addressed to different people and only one of them is asking for anything.
 *
 * The register is the one creator platforms use when they open to creators:
 * lead with the split, state the terms as a list, no adjectives, and say
 * plainly what is and is not open yet. What it avoids is the house style of
 * a generated advert — no gradient wash, no glow, no drop-shadowed cards, no
 * centred everything, no stock photograph of somebody smiling at a laptop.
 * Flat brand colour, hairline rules, a visible left margin, and real numbers.
 *
 * Motion is restrained on purpose: text rises a few pixels and fades, rules
 * draw across. Nothing springs or overshoots. Bounce is the tell.
 */

const MARGIN = 96;

/** Beat boundaries in frames at 30fps. Durations only; starts accumulate. */
const BEATS = [
  {key: 'line0', duration: 84},
  {key: 'line1', duration: 96},
  {key: 'line2', duration: 84},
  {key: 'share', duration: 114},
  {key: 'terms', duration: 108},
  {key: 'cta', duration: 54},
] as const;

const STARTS = BEATS.reduce<number[]>((acc, beat, i) => {
  acc.push(i === 0 ? 0 : acc[i - 1] + BEATS[i - 1].duration);
  return acc;
}, []);

export const CALL_DURATION = BEATS.reduce((t, b) => t + b.duration, 0);

/** One spot effect, at one frame. `layout="none"` — it places sound, not pixels. */
const Cue: React.FC<{at: number; src: string; volume?: number}> = ({
  at,
  src,
  volume = 1,
}) => (
  <Sequence from={at} layout="none">
    <Audio src={staticFile(`audio/${src}.wav`)} volume={volume} />
  </Sequence>
);

/**
 * Fade and lift, with a hold between. The only move in the piece.
 *
 * A plain function, not a hook — it calls no React state and is invoked from
 * inside conditionals, which a `use*` name would make illegal as well as
 * misleading.
 */
const reveal = (local: number, duration: number, delay = 0) => {
  const f = local - delay;
  const opacity = interpolate(f, [0, 11, duration - 20, duration - 9], [0, 1, 1, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const lift = interpolate(f, [0, 16], [14, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: Easing.out(Easing.cubic),
  });
  return {opacity, transform: `translateY(${lift}px)`};
};

/** A statement, set large, left-aligned, hanging off the margin. */
const Statement: React.FC<{text: string; local: number; duration: number; size: number}> = ({
  text,
  local,
  duration,
  size,
}) => (
  <div
    style={{
      ...reveal(local, duration),
      fontFamily: playfair,
      fontSize: size,
      fontWeight: 700,
      lineHeight: 1.06,
      letterSpacing: -1.5,
      color: colors.appWhite,
      whiteSpace: 'pre-line',
    }}
  >
    {text}
  </div>
);

export const TeacherCall: React.FC = () => {
  const frame = useCurrentFrame();
  const {width, height} = useVideoConfig();
  const square = Math.abs(width - height) < 2;

  // One scale knob rather than a branch per element: the 1:1 cut is the same
  // layout at the same proportions, just shorter, so nothing can drift
  // between the two the way two hand-tuned layouts would.
  const s = square ? 0.78 : 1;

  const at = (i: number) => frame - STARTS[i];
  const showing = (i: number) =>
    frame >= STARTS[i] && frame < STARTS[i] + BEATS[i].duration;

  return (
    <AbsoluteFill
      style={{
        background: colors.richBlack,
        WebkitFontSmoothing: 'antialiased',
      }}
    >
      {/* ---- score ----
          Far sparser than the ad's: a low drone with a slow pulse, one soft
          mark as each statement arrives, and movement held back for the
          number and the close. A notice should not chirp at you.

          The drone runs from frame 0, unlike the ad's bed — there is no hook
          here whose silence needs protecting, and a statement appearing in
          total silence reads as a slide rather than a film. */}
      <Audio
        src={staticFile('audio/bed-teachers.mp3')}
        volume={(f) =>
          interpolate(f, [0, 20, CALL_DURATION - 40, CALL_DURATION], [0, 0.5, 0.5, 0], {
            extrapolateLeft: 'clamp',
            extrapolateRight: 'clamp',
          })
        }
      />

      {/* One low mark per statement, on the frame its text starts to rise. */}
      {[0, 1, 2].map((i) => (
        <Cue key={i} at={STARTS[i]} src="sfx-mark" volume={0.3} />
      ))}

      {/* The number is the point of the piece, so it gets the one real hit,
          and the kicker under it gets the resolution ten frames later. */}
      <Cue at={STARTS[3]} src="sfx-sub" volume={0.5} />
      <Cue at={STARTS[3] + 10} src="sfx-land" volume={0.26} />

      {/* A tick as each term rules itself in — `reveal` staggers them seven
          frames apart, so these are those frames. */}
      {[0, 1, 2].map((i) => (
        <Cue key={i} at={STARTS[4] + i * 7} src="sfx-tick" volume={0.16} />
      ))}
      <Cue at={STARTS[4] + 24} src="sfx-chime" volume={0.2} />

      {/* `LogoMark` runs at speed 2.4 on the closing card, putting its
          bowlSweep (26) and leafPop (56) at scene frames 11 and 23. */}
      <Cue at={STARTS[5] + 8} src="sfx-whoosh" volume={0.28} />
      <Cue at={STARTS[5] + 23} src="sfx-pluck" volume={0.38} />
      {/* Standing header. Gives the piece a frame and keeps the brand present
          without a logo sitting over every statement. */}
      <div
        style={{
          position: 'absolute',
          top: MARGIN * s,
          left: MARGIN * s,
          right: MARGIN * s,
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'baseline',
          fontFamily: poppins,
          fontSize: 20 * s,
          fontWeight: 600,
          letterSpacing: 2.6,
          textTransform: 'uppercase',
          color: 'rgba(255,255,255,0.5)',
        }}
      >
        <span style={{color: colors.primary}}>PadiLearn</span>
        <span>{announcement.eyebrow}</span>
      </div>

      {/* A hairline that fills as the piece runs. A progress bar without
          being one — it reads as a rule that happens to be drawing. */}
      <div
        style={{
          position: 'absolute',
          top: MARGIN * s + 40 * s,
          left: MARGIN * s,
          right: MARGIN * s,
          height: 1,
          background: 'rgba(255,255,255,0.14)',
        }}
      >
        <div
          style={{
            width: `${(frame / CALL_DURATION) * 100}%`,
            height: '100%',
            background: colors.primary,
          }}
        />
      </div>

      {/* The statements all hang off the same baseline and left margin, so
          each one replaces the last in place instead of the eye having to
          find it again. */}
      <AbsoluteFill
        style={{
          padding: `0 ${MARGIN * s}px`,
          justifyContent: 'center',
        }}
      >
        {announcement.beats.map((text, i) =>
          showing(i) ? (
            <Statement
              key={text}
              text={text}
              local={at(i)}
              duration={BEATS[i].duration}
              size={112 * s}
            />
          ) : null,
        )}

        {showing(3) ? (
          <div>
            <div
              style={{
                ...reveal(at(3), BEATS[3].duration),
                fontFamily: playfair,
                fontSize: 320 * s,
                fontWeight: 700,
                lineHeight: 0.84,
                letterSpacing: -10,
                color: colors.primary,
              }}
            >
              {announcement.share.figure}
            </div>
            <div
              style={{
                ...reveal(at(3), BEATS[3].duration, 10),
                fontFamily: playfair,
                fontSize: 70 * s,
                fontWeight: 700,
                letterSpacing: -1,
                color: colors.appWhite,
                marginTop: 26 * s,
              }}
            >
              {announcement.share.of}
            </div>
          </div>
        ) : null}

        {showing(4) ? (
          <div>
            {announcement.terms.map((term, i) => (
              <div
                key={term}
                style={{
                  ...reveal(at(4), BEATS[4].duration, i * 7),
                  borderTop: '1px solid rgba(255,255,255,0.16)',
                  padding: `${22 * s}px 0`,
                  fontFamily: poppins,
                  fontSize: 42 * s,
                  fontWeight: 500,
                  color: colors.appWhite,
                }}
              >
                {term}
              </div>
            ))}
            <div
              style={{
                ...reveal(at(4), BEATS[4].duration, 24),
                borderTop: '1px solid rgba(255,255,255,0.16)',
                paddingTop: 30 * s,
                marginTop: 4 * s,
                fontFamily: poppins,
                fontSize: 34 * s,
                color: 'rgba(255,255,255,0.62)',
                lineHeight: 1.5,
              }}
            >
              {announcement.worked.label}{' '}
              <span style={{color: colors.appWhite, fontWeight: 600}}>
                {announcement.worked.price}
              </span>{' '}
              {announcement.worked.middle}{' '}
              <span style={{color: colors.primary, fontWeight: 700}}>
                {announcement.worked.earn}
              </span>
              .
            </div>
          </div>
        ) : null}

        {showing(5) ? (
          <div style={reveal(at(5), BEATS[5].duration)}>
            <LogoMark variant="bare" size={150 * s} speed={2.4} />
            <div
              style={{
                fontFamily: playfair,
                fontSize: 64 * s,
                fontWeight: 700,
                color: colors.appWhite,
                letterSpacing: -1,
                marginTop: 22 * s,
              }}
            >
              {announcement.cta.site}
            </div>
            <div
              style={{
                fontFamily: poppins,
                fontSize: 32 * s,
                color: 'rgba(255,255,255,0.6)',
                marginTop: 12 * s,
                lineHeight: 1.5,
                whiteSpace: 'pre-line',
              }}
            >
              {announcement.status}
            </div>
          </div>
        ) : null}
      </AbsoluteFill>

      {/* Footer: the address to write to, and a dateline. Metadata, set
          small — the things a notice carries and an advert usually does not. */}
      <div
        style={{
          position: 'absolute',
          bottom: MARGIN * s,
          left: MARGIN * s,
          right: MARGIN * s,
          display: 'flex',
          justifyContent: 'space-between',
          fontFamily: poppins,
          fontSize: 22 * s,
          color: 'rgba(255,255,255,0.42)',
        }}
      >
        <span>{announcement.cta.email}</span>
        <span>{announcement.colophon}</span>
      </div>
    </AbsoluteFill>
  );
};
