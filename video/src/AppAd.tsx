import React from 'react';
import {
  AbsoluteFill,
  Easing,
  Sequence,
  interpolate,
  spring,
  useCurrentFrame,
  useVideoConfig,
} from 'remotion';
import {loadFont as loadPoppins} from '@remotion/google-fonts/Poppins';
import {loadFont as loadPlayfair} from '@remotion/google-fonts/PlayfairDisplay';
import {colors, script} from './theme';
import {Phone} from './components/Phone';
import {MarketplaceMock} from './components/MarketplaceMock';
import {LessonMock} from './components/LessonMock';
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
export const SCENES = {
  hook: {from: 0, duration: 105},
  browse: {from: 105, duration: 165},
  learn: {from: 270, duration: 165},
  teach: {from: 435, duration: 150},
  cta: {from: 585, duration: 135},
} as const;

/** 720 frames — 24s at 30fps. */
export const AD_DURATION = SCENES.cta.from + SCENES.cta.duration;

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

export const AppAd: React.FC = () => {
  return (
    // Grayscale antialiasing throughout: Chrome's default subpixel rendering
    // put visible colour fringes on light text over the dark scenes.
    <AbsoluteFill
      style={{
        background: colors.appWhite,
        WebkitFontSmoothing: 'antialiased',
      }}
    >
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
            screen={<MarketplaceMock poppins={poppins} playfair={playfair} />}
          />
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
