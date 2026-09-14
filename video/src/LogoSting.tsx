import React from 'react';
import {
  AbsoluteFill,
  Audio,
  Easing,
  interpolate,
  spring,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from 'remotion';
import {loadFont as loadPoppins} from '@remotion/google-fonts/Poppins';
import {loadFont as loadPlayfair} from '@remotion/google-fonts/PlayfairDisplay';
import {colors, script} from './theme';
import {LogoMark} from './components/LogoMark';

const {fontFamily: poppins} = loadPoppins();
const {fontFamily: playfair} = loadPlayfair();

/** 120 frames — 4s at 30fps. */
export const STING_DURATION = 120;

/** The wordmark builds after the mark has settled. */
const WORDMARK_AT = 88;

/**
 * Standalone logo animation.
 *
 * Useful in more places than the ad: an app splash, a course intro bumper, the
 * top of any future video. It ends on the settled lockup rather than fading
 * out, so it can be held on a freeze frame or cut straight out of.
 */
export const LogoSting: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps, width} = useVideoConfig();
  const compact = width < 1200;

  // Letters rise individually so the wordmark assembles rather than fades.
  const letters = script.cta.wordmark.split('');

  const taglineIn = interpolate(
    frame,
    [WORDMARK_AT + 18, WORDMARK_AT + 32],
    [0, 1],
    {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'},
  );

  return (
    <AbsoluteFill
      style={{
        background: colors.appWhite,
        alignItems: 'center',
        justifyContent: 'center',
        flexDirection: 'column',
        WebkitFontSmoothing: 'antialiased',
      }}
    >
      {/* Placeholder bed. A sting really wants designed sound — a whoosh on
          the bowl sweep, a soft plucked note as the leaf opens — rather than
          music; see `directions.cta`. This is here so the file is not silent,
          not because it is the right answer. */}
      <Audio
        src={staticFile('audio/bed-sting.mp3')}
        volume={(f) =>
          interpolate(
            f,
            [0, 10, STING_DURATION - 26, STING_DURATION],
            [0, 0.5, 0.5, 0],
            {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'},
          )
        }
      />
      {/* A soft bloom that swells as the mark lands, so the tile is sitting in
          light rather than pasted onto flat white. */}
      <div
        style={{
          position: 'absolute',
          width: 900,
          height: 900,
          borderRadius: '50%',
          background:
            'radial-gradient(circle, rgba(50,147,111,0.18) 0%, rgba(50,147,111,0) 68%)',
          transform: `translateY(-60px) scale(${interpolate(
            frame,
            [0, 30, 110],
            [0.4, 1, 1.12],
            {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'},
          )})`,
          opacity: interpolate(frame, [4, 26], [0, 1], {
            extrapolateLeft: 'clamp',
            extrapolateRight: 'clamp',
          }),
        }}
      />

      <div
        style={{
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          transform: `translateY(${interpolate(
            frame,
            [WORDMARK_AT - 10, WORDMARK_AT + 20],
            [0, -26],
            {
              extrapolateLeft: 'clamp',
              extrapolateRight: 'clamp',
              easing: Easing.inOut(Easing.cubic),
            },
          )}px)`,
        }}
      >
        <LogoMark size={compact ? 360 : 430} />

        <div style={{display: 'flex', marginTop: 44}}>
          {letters.map((letter, i) => {
            const rise = spring({
              frame: frame - WORDMARK_AT - i * 2,
              fps,
              config: {damping: 200, mass: 0.5},
            });
            return (
              <span
                key={`${letter}-${i}`}
                style={{
                  fontFamily: playfair,
                  fontSize: compact ? 74 : 92,
                  fontWeight: 700,
                  color: colors.richBlack,
                  letterSpacing: -2,
                  opacity: rise,
                  transform: `translateY(${interpolate(
                    rise,
                    [0, 1],
                    [34, 0],
                  )}px)`,
                }}
              >
                {letter}
              </span>
            );
          })}
        </div>

        <div
          style={{
            fontFamily: poppins,
            fontSize: compact ? 24 : 28,
            color: colors.fontGrey,
            marginTop: 12,
            opacity: taglineIn,
            transform: `translateY(${interpolate(taglineIn, [0, 1], [12, 0])}px)`,
          }}
        >
          {script.cta.tagline}
        </div>
      </div>
    </AbsoluteFill>
  );
};
