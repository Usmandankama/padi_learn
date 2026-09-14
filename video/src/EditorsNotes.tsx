import React from 'react';
import {AbsoluteFill, useCurrentFrame} from 'remotion';
import {loadFont as loadPoppins} from '@remotion/google-fonts/Poppins';
import {colors, directions, globalDirections, FPS} from './theme';
import {AppAd, SCENES, AD_DURATION} from './AppAd';

const {fontFamily: poppins} = loadPoppins();

/**
 * The ad with direction laid over it, for handing to a sound designer, a VO
 * artist or an editor.
 *
 * A SEPARATE composition rather than an overlay switched on inside the ad. The
 * notes can then never survive into the deliverable by accident — there is no
 * flag to leave set, and `AppAdLandscape` has no code path that draws them. It
 * also carries a standing watermark, so a stray copy of this file is obviously
 * not the finished thing even with the sound off and no context.
 *
 * The scene table is imported from `AppAd`, not restated, so retiming the ad
 * moves these notes with it instead of quietly desynchronising them.
 */

const SCENE_ORDER = ['hook', 'browse', 'learn', 'teach', 'cta'] as const;
type SceneKey = (typeof SCENE_ORDER)[number];

const timecode = (frames: number) => {
  const total = Math.max(0, frames);
  const s = Math.floor(total / FPS);
  const f = total % FPS;
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}.${String(
    f,
  ).padStart(2, '0')}`;
};

const currentScene = (frame: number): SceneKey => {
  let active: SceneKey = SCENE_ORDER[0];
  for (const key of SCENE_ORDER) {
    if (frame >= SCENES[key].from) active = key;
  }
  return active;
};

const Label: React.FC<{children: React.ReactNode}> = ({children}) => (
  <div
    style={{
      fontSize: 15,
      fontWeight: 700,
      letterSpacing: 2.4,
      color: 'rgba(255,255,255,0.42)',
      marginBottom: 7,
    }}
  >
    {children}
  </div>
);

const Note: React.FC<{label: string; text: string; accent?: string}> = ({
  label,
  text,
  accent,
}) => (
  <div style={{flex: 1, minWidth: 0}}>
    <Label>{label}</Label>
    <div
      style={{
        fontSize: 19,
        lineHeight: 1.45,
        color: accent ?? 'rgba(255,255,255,0.9)',
      }}
    >
      {text}
    </div>
  </div>
);

export const EditorsNotes: React.FC = () => {
  const frame = useCurrentFrame();
  const key = currentScene(frame);
  const scene = SCENES[key];
  const note = directions[key];

  // The ad is inset rather than full-bleed so the notes sit beside it instead
  // of over it — covering the frame you are being asked to score would defeat
  // the point.
  const adScale = 0.56;

  return (
    <AbsoluteFill
      style={{
        background: '#0A0E13',
        fontFamily: poppins,
        WebkitFontSmoothing: 'antialiased',
      }}
    >
      {/* ---- the cut itself ---- */}
      <div
        style={{
          position: 'absolute',
          top: 46,
          left: 60,
          width: 1920 * adScale,
          height: 1080 * adScale,
          borderRadius: 10,
          overflow: 'hidden',
          border: '1px solid rgba(255,255,255,0.14)',
        }}
      >
        <div
          style={{
            width: 1920,
            height: 1080,
            transform: `scale(${adScale})`,
            transformOrigin: 'top left',
          }}
        >
          <AppAd />
        </div>
      </div>

      {/* ---- running state, beside the picture ---- */}
      <div
        style={{
          position: 'absolute',
          top: 46,
          left: 60 + 1920 * adScale + 46,
          right: 60,
        }}
      >
        <div
          style={{
            display: 'flex',
            alignItems: 'baseline',
            gap: 16,
            marginBottom: 26,
          }}
        >
          <div
            style={{
              fontSize: 40,
              fontWeight: 700,
              color: colors.appWhite,
              fontVariantNumeric: 'tabular-nums',
            }}
          >
            {timecode(frame)}
          </div>
          <div style={{fontSize: 17, color: 'rgba(255,255,255,0.4)'}}>
            / {timecode(AD_DURATION)}
          </div>
        </div>

        <div
          style={{
            display: 'inline-block',
            padding: '7px 15px',
            borderRadius: 999,
            background: 'rgba(50,147,111,0.2)',
            border: `1px solid ${colors.primary}`,
            color: colors.primary,
            fontSize: 16,
            fontWeight: 700,
            letterSpacing: 1.6,
            marginBottom: 24,
          }}
        >
          {key.toUpperCase()} · {timecode(scene.from)}–
          {timecode(scene.from + scene.duration)}
        </div>

        <div style={{display: 'flex', flexDirection: 'column', gap: 22}}>
          <Note label="VOICEOVER" text={note.vo} accent={colors.appWhite} />
          <Note label="SOUND" text={note.sound} />
          <Note label="VIBE" text={note.vibe} />
        </div>
      </div>

      {/* ---- timeline, with the scene boundaries marked ---- */}
      <div
        style={{
          position: 'absolute',
          left: 60,
          right: 60,
          top: 46 + 1080 * adScale + 34,
        }}
      >
        <div
          style={{
            position: 'relative',
            height: 26,
            borderRadius: 6,
            background: 'rgba(255,255,255,0.07)',
            overflow: 'hidden',
          }}
        >
          {SCENE_ORDER.map((k) => (
            <div
              key={k}
              style={{
                position: 'absolute',
                left: `${(SCENES[k].from / AD_DURATION) * 100}%`,
                width: `${(SCENES[k].duration / AD_DURATION) * 100}%`,
                top: 0,
                bottom: 0,
                borderLeft: '1px solid rgba(255,255,255,0.22)',
                background:
                  k === key ? 'rgba(50,147,111,0.5)' : 'transparent',
                fontSize: 12,
                letterSpacing: 1.4,
                color: 'rgba(255,255,255,0.55)',
                display: 'flex',
                alignItems: 'center',
                paddingLeft: 9,
              }}
            >
              {k.toUpperCase()}
            </div>
          ))}
          {/* Playhead */}
          <div
            style={{
              position: 'absolute',
              left: `${(frame / AD_DURATION) * 100}%`,
              top: 0,
              bottom: 0,
              width: 2,
              background: colors.appWhite,
            }}
          />
        </div>
      </div>

      {/* ---- notes that hold for the whole cut ---- */}
      {/* Sits directly under the timeline rather than pinned to the bottom
          edge, which left a band of dead space across the middle. */}
      <div
        style={{
          position: 'absolute',
          left: 60,
          right: 60,
          top: 46 + 1080 * adScale + 34 + 26 + 44,
        }}
      >
        <Label>ACROSS THE WHOLE CUT</Label>
        <div
          style={{
            display: 'grid',
            gridTemplateColumns: '1fr 1fr',
            gap: '10px 40px',
          }}
        >
          {globalDirections.map((line, i) => (
            <div
              key={i}
              style={{
                fontSize: 16,
                lineHeight: 1.4,
                color: 'rgba(255,255,255,0.62)',
                display: 'flex',
                gap: 10,
              }}
            >
              <span style={{color: colors.primary}}>—</span>
              <span>{line}</span>
            </div>
          ))}
        </div>
      </div>

      {/* ---- standing watermark ----
          Deliberately unmissable. This file exists to be marked up and thrown
          away; nothing about it should read as deliverable if it gets
          forwarded on its own. */}
      <div
        style={{
          position: 'absolute',
          top: 54,
          right: 60,
          fontSize: 13,
          fontWeight: 700,
          letterSpacing: 3,
          color: 'rgba(255,120,120,0.85)',
          border: '1px solid rgba(255,120,120,0.5)',
          borderRadius: 5,
          padding: '5px 11px',
          transform: 'translateY(-6px)',
        }}
      >
        REFERENCE — NOT FOR RELEASE
      </div>
    </AbsoluteFill>
  );
};
