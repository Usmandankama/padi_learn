import React from 'react';
import {
  AbsoluteFill,
  Audio,
  Easing,
  Sequence,
  interpolate,
  spring,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from 'remotion';
import {loadFont as loadPoppins} from '@remotion/google-fonts/Poppins';
import {loadFont as loadPlayfair} from '@remotion/google-fonts/PlayfairDisplay';
import {colors, script} from './theme';
import {courses} from './catalogue';
import {Phone} from './components/Phone';
import {MarketplaceMock} from './components/MarketplaceMock';
import {LessonMock} from './components/LessonMock';
import {LessonReel, REEL_DURATION} from './components/LessonReel';
import {LogoMark} from './components/LogoMark';

const {fontFamily: poppins} = loadPoppins();
const {fontFamily: playfair} = loadPlayfair();

/**
 * Scene boundaries, in frames at 30fps.
 *
 * Declared as one table rather than scattered through the JSX so retiming the
 * ad means editing five numbers, and so the total duration is derived from the
 * scenes instead of being a constant that drifts out of sync with them.
 */
const DURATIONS = {
  hook: 90,
  browse: 135,
  // However long the reel's clips add up to, so retiming a beat in
  // `LessonReel` cannot leave this table claiming otherwise.
  lesson: REEL_DURATION,
  learn: 105,
  // Carries the remainder that keeps the cut at exactly 720 frames. If you
  // lengthen another scene, take it out of this one.
  teach: 106,
  cta: 120,
} as const;

/**
 * The scene order, and the only place it is written down. Everything that
 * walks the ad — the notes overlay included — reads this rather than
 * restating it, so a scene cannot be added in one place and missed in another.
 */
export const SCENE_ORDER = Object.keys(DURATIONS) as (keyof typeof DURATIONS)[];

/**
 * Scene boundaries, in frames at 30fps.
 *
 * Only durations are declared; each scene's start is accumulated from the ones
 * before it. Retiming the ad is then editing one number, with nothing to keep
 * in sync by hand.
 */
export const SCENES = (() => {
  let at = 0;
  const table = {} as Record<
    keyof typeof DURATIONS,
    {from: number; duration: number}
  >;
  for (const key of SCENE_ORDER) {
    table[key] = {from: at, duration: DURATIONS[key]};
    at += DURATIONS[key];
  }
  return table;
})();

/** 720 frames — 24s at 30fps. */
export const AD_DURATION = SCENE_ORDER.reduce(
  (total, key) => total + DURATIONS[key],
  0,
);

/** True when the composition is taller than it is wide. */
const useIsVertical = () => {
  const {width, height} = useVideoConfig();
  return height > width;
};

/** Fades and lifts its children in, then back out before the scene ends. */
const SceneFade: React.FC<{
  duration: number;
  children: React.ReactNode;
}> = ({duration, children}) => {
  const frame = useCurrentFrame();
  const opacity = interpolate(
    frame,
    [0, 12, duration - 14, duration],
    [0, 1, 1, 0],
    {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'},
  );
  const lift = interpolate(frame, [0, 18], [16, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: Easing.out(Easing.cubic),
  });

  return (
    <AbsoluteFill style={{opacity, transform: `translateY(${lift}px)`}}>
      {children}
    </AbsoluteFill>
  );
};

const Caption: React.FC<{
  title: string;
  sub: string;
  align: 'left' | 'center';
}> = ({title, sub, align}) => {
  const vertical = useIsVertical();
  return (
    <div style={{textAlign: align, maxWidth: vertical ? 820 : 620}}>
      <div
        style={{
          fontFamily: playfair,
          fontSize: vertical ? 76 : 62,
          fontWeight: 700,
          color: colors.richBlack,
          lineHeight: 1.08,
          letterSpacing: -1,
        }}
      >
        {title}
      </div>
      <div
        style={{
          fontFamily: poppins,
          fontSize: vertical ? 32 : 26,
          color: colors.fontGrey,
          marginTop: 18,
          lineHeight: 1.45,
        }}
      >
        {sub}
      </div>
    </div>
  );
};

/**
 * Lays a caption beside the phone in landscape, and above it when vertical.
 *
 * One component covering both orientations rather than two compositions with
 * duplicated copy — the reason to render this in code at all is that the 9:16
 * cut cannot drift out of sync with the 16:9 one.
 */
const PhoneScene: React.FC<{
  title: string;
  sub: string;
  screen: React.ReactNode;
}> = ({title, sub, screen}) => {
  const vertical = useIsVertical();
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();

  const rise = spring({frame, fps, config: {damping: 200, mass: 0.9}});
  const drift = interpolate(frame, [0, 160], [0, -22]);

  return (
    <AbsoluteFill
      style={{
        background: colors.appWhite,
        alignItems: 'center',
        justifyContent: 'center',
      }}
    >
      {/* The caption and phone are centred as one bounded pair. Letting the
          caption flex to fill the frame instead pushed the two to opposite
          edges and left a dead gap down the middle of every landscape scene. */}
      <div
        style={{
          display: 'flex',
          flexDirection: vertical ? 'column' : 'row',
          alignItems: 'center',
          gap: vertical ? 40 : 72,
        }}
      >
        <div style={{width: vertical ? 'auto' : 600, flexShrink: 0}}>
          <Caption
            title={title}
            sub={sub}
            align={vertical ? 'center' : 'left'}
          />
        </div>
        <div
          style={{
            flexShrink: 0,
            transform: `translateY(${
              interpolate(rise, [0, 1], [70, 0]) + drift
            }px)`,
            opacity: rise,
          }}
        >
          <Phone scale={vertical ? 0.92 : 0.74}>{screen}</Phone>
        </div>
      </div>
    </AbsoluteFill>
  );
};

const Hook: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const vertical = useIsVertical();
  const pop = spring({frame, fps, config: {damping: 200}});

  return (
    <AbsoluteFill
      style={{
        background: colors.primary,
        alignItems: 'center',
        justifyContent: 'center',
        padding: '0 100px',
      }}
    >
      <div
        style={{
          textAlign: 'center',
          transform: `scale(${interpolate(pop, [0, 1], [0.92, 1])})`,
        }}
      >
        <div
          style={{
            fontFamily: playfair,
            fontSize: vertical ? 104 : 92,
            fontWeight: 700,
            color: colors.appWhite,
            lineHeight: 1.02,
            letterSpacing: -2,
          }}
        >
          {script.hook.line1}
          <br />
          {script.hook.line2}
        </div>
        <div
          style={{
            fontFamily: poppins,
            fontSize: vertical ? 34 : 29,
            color: 'rgba(255,255,255,0.86)',
            marginTop: 26,
          }}
        >
          {script.hook.sub}
        </div>
      </div>
    </AbsoluteFill>
  );
};

/** The teacher-side pitch. The payout figure counting up is the whole scene. */
const Teach: React.FC = () => {
  const frame = useCurrentFrame();
  const vertical = useIsVertical();
  const earned = Math.round(
    interpolate(frame, [18, 96], [0, 184500], {
      extrapolateLeft: 'clamp',
      extrapolateRight: 'clamp',
      easing: Easing.out(Easing.cubic),
    }),
  );

  return (
    <AbsoluteFill
      style={{
        background: colors.richBlack,
        alignItems: 'center',
        justifyContent: 'center',
        flexDirection: 'column',
        padding: '0 110px',
        textAlign: 'center',
      }}
    >
      <div
        style={{
          fontFamily: playfair,
          fontSize: vertical ? 76 : 64,
          fontWeight: 700,
          color: colors.appWhite,
          lineHeight: 1.08,
        }}
      >
        {script.teach.title}
      </div>
      <div
        style={{
          fontFamily: poppins,
          fontSize: vertical ? 30 : 25,
          color: 'rgba(255,255,255,0.62)',
          marginTop: 16,
          maxWidth: 760,
        }}
      >
        {script.teach.sub}
      </div>

      <div
        style={{
          marginTop: 52,
          padding: vertical ? '30px 54px' : '26px 48px',
          borderRadius: 22,
          background: 'rgba(50,147,111,0.16)',
          border: `1px solid ${colors.primary}`,
        }}
      >
        <div
          style={{
            fontFamily: poppins,
            fontSize: 18,
            color: 'rgba(255,255,255,0.6)',
            letterSpacing: 1.5,
          }}
        >
          PAID OUT THIS MONTH
        </div>
        <div
          style={{
            fontFamily: poppins,
            fontSize: vertical ? 74 : 64,
            fontWeight: 700,
            color: colors.primary,
            marginTop: 6,
            fontVariantNumeric: 'tabular-nums',
          }}
        >
          {`₦${earned.toLocaleString('en-NG')}`}
        </div>
      </div>
    </AbsoluteFill>
  );
};

const Cta: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const vertical = useIsVertical();
  // The type is held back until the mark has finished growing (the build runs
  // at speed 2, so ~55 frames) — otherwise the wordmark races the logo and
  // both land in a muddle. Only the type is gated; the mark needs to be on
  // screen from frame 0 to have something to build.
  const pop = spring({frame: frame - 50, fps, config: {damping: 180, mass: 0.7}});

  return (
    <AbsoluteFill
      style={{
        background: colors.primary,
        alignItems: 'center',
        justifyContent: 'center',
        flexDirection: 'column',
      }}
    >
      <div
        style={{
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
        }}
      >
        {/* The animated mark rather than the flat PNG this used to show, so
            the ad closes on the same growth build as the standalone sting.
            `bare` because the card is already brand green. */}
        <div style={{marginBottom: 10}}>
          <LogoMark variant="bare" size={vertical ? 300 : 250} speed={2} />
        </div>
        <div
          style={{
            fontFamily: playfair,
            fontSize: vertical ? 96 : 84,
            fontWeight: 700,
            color: colors.appWhite,
            letterSpacing: -2,
            opacity: pop,
            transform: `translateY(${interpolate(pop, [0, 1], [26, 0])}px)`,
          }}
        >
          {script.cta.wordmark}
        </div>
        <div
          style={{
            fontFamily: poppins,
            fontSize: vertical ? 34 : 29,
            color: 'rgba(255,255,255,0.9)',
            marginTop: 14,
            opacity: interpolate(frame, [66, 80], [0, 1], {
              extrapolateLeft: 'clamp',
              extrapolateRight: 'clamp',
            }),
          }}
        >
          {script.cta.tagline}
        </div>
      </div>
    </AbsoluteFill>
  );
};

/** Frames over which the bed fades up, and back down at the end. */
const MUSIC_FADE_IN = 24;
const MUSIC_FADE_OUT = 50;

/**
 * Frame the music enters on.
 *
 * One second into the browse scene rather than at its start. Two reasons: the
 * hook keeps its silence a beat longer, and at 120bpm this puts the closing
 * card exactly eight bars later, so the logo build lands on a bar line
 * instead of halfway through one. `scripts/make_audio.py` writes the bed
 * against this same number.
 */
const BED_FROM = 120;

/**
 * One spot effect, at one frame.
 *
 * `layout="none"` because these place sound, not pixels — a Sequence that
 * also laid out a div would push the scene it sits beside around.
 */
const Cue: React.FC<{at: number; src: string; volume?: number}> = ({
  at,
  src,
  volume = 1,
}) => (
  <Sequence from={at} layout="none">
    <Audio src={staticFile(`audio/${src}.wav`)} volume={volume} />
  </Sequence>
);

export const AppAd: React.FC = () => {
  const musicFrames = AD_DURATION - BED_FROM;

  return (
    // Grayscale antialiasing throughout: Chrome's default subpixel rendering
    // put visible colour fringes on light text over the dark scenes.
    <AbsoluteFill
      style={{
        background: colors.appWhite,
        WebkitFontSmoothing: 'antialiased',
      }}
    >
      {/* ---- score ----
          The bed enters a second into the browse scene, not at frame 0: the
          hook plays dry so the opening line lands in silence, which is the
          direction in `directions.hook`. Frame 120 rather than 90 because the
          bed is 120bpm and its tenth bar then falls exactly on the closing
          card, so the logo build resolves on a bar line.

          Its arrangement — which parts play in which scene — is baked into
          the file by `scripts/make_audio.py`, because that is a musical
          decision and belongs with the music. Only the master fade is here. */}
      <Sequence from={BED_FROM}>
        <Audio
          src={staticFile('audio/bed-ad-v2.mp3')}
          volume={(f) =>
            interpolate(
              f,
              [0, MUSIC_FADE_IN, musicFrames - MUSIC_FADE_OUT, musicFrames],
              [0, 0.62, 0.62, 0],
              {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'},
            )
          }
        />
      </Sequence>

      {/* One low hit as the title lands, over silence. */}
      <Cue at={8} src="sfx-sub" volume={0.55} />

      {/* A tick per course card. `MarketplaceMock` springs card i at local
          frame 10 + 2i, so these are those frames, and the flurry is the
          grid filling. Very low individually — eleven of them inside
          two-thirds of a second is a texture, not eleven sounds. */}
      {courses.map((course, i) => (
        <Cue
          key={course.slug}
          at={SCENES.browse.from + 10 + i * 2}
          src="sfx-tick"
          volume={0.12}
        />
      ))}

      {/* Barely-there texture under each lesson figure drawing itself. It
          should register as the room the board is in. */}
      <Cue at={SCENES.lesson.from + 5} src="sfx-chalk" volume={0.1} />
      <Cue at={SCENES.lesson.from + 87} src="sfx-chalk" volume={0.1} />

      {/* The progress bar finishes filling at local frame 70. */}
      <Cue at={SCENES.learn.from + 62} src="sfx-chime" volume={0.28} />

      {/* The naira figure counts over local frames 18–96. The rise runs under
          it and deliberately stops short, so the landing is its own cue and
          retiming one does not drag the other out of place. The number
          stopping is the beat — `sfx-land` is on the exact frame it does. */}
      <Cue at={SCENES.teach.from + 18} src="sfx-rise" volume={0.3} />
      <Cue at={SCENES.teach.from + 96} src="sfx-land" volume={0.45} />

      {/* `LogoMark` runs at speed 2 here, so its internal bowlSweep (26) and
          leafPop (56) land on scene frames 13 and 28. The whoosh leads the
          sweep by three frames because a movement is heard starting, not
          finishing. */}
      <Cue at={SCENES.cta.from + 11} src="sfx-whoosh" volume={0.42} />
      <Cue at={SCENES.cta.from + 28} src="sfx-pluck" volume={0.4} />
      <Sequence from={SCENES.hook.from} durationInFrames={SCENES.hook.duration}>
        <SceneFade duration={SCENES.hook.duration}>
          <Hook />
        </SceneFade>
      </Sequence>

      <Sequence
        from={SCENES.browse.from}
        durationInFrames={SCENES.browse.duration}
      >
        <SceneFade duration={SCENES.browse.duration}>
          <PhoneScene
            title={script.browse.title}
            sub={script.browse.sub}
            screen={
              <MarketplaceMock
                poppins={poppins}
                playfair={playfair}
                scrollOver={SCENES.browse.duration}
              />
            }
          />
        </SceneFade>
      </Sequence>

      {/* The proof beat: a lesson, at a size you can read. */}
      <Sequence
        from={SCENES.lesson.from}
        durationInFrames={SCENES.lesson.duration}
      >
        <SceneFade duration={SCENES.lesson.duration}>
          <LessonReel poppins={poppins} playfair={playfair} />
        </SceneFade>
      </Sequence>

      <Sequence
        from={SCENES.learn.from}
        durationInFrames={SCENES.learn.duration}
      >
        <SceneFade duration={SCENES.learn.duration}>
          <PhoneScene
            title={script.learn.title}
            sub={script.learn.sub}
            screen={<LessonMock poppins={poppins} playfair={playfair} />}
          />
        </SceneFade>
      </Sequence>

      <Sequence
        from={SCENES.teach.from}
        durationInFrames={SCENES.teach.duration}
      >
        <SceneFade duration={SCENES.teach.duration}>
          <Teach />
        </SceneFade>
      </Sequence>

      <Sequence from={SCENES.cta.from} durationInFrames={SCENES.cta.duration}>
        <SceneFade duration={SCENES.cta.duration}>
          <Cta />
        </SceneFade>
      </Sequence>
    </AbsoluteFill>
  );
};
