import React from 'react';
import {
  AbsoluteFill,
  Easing,
  Img,
  OffthreadVideo,
  interpolate,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from 'remotion';
import {colors, FPS, script} from '../theme';
import {bySlug, filmedPosition, priceLabel} from '../catalogue';

/**
 * Two lesson videos, played large enough to actually watch.
 *
 * The browse scene already sells breadth — eleven courses scrolling past. This
 * one has to sell that a lesson is worth paying for, which needs the footage
 * at a size where the figure is legible, so the phone is set aside here and
 * the player fills the frame. It is still the app's player: the same chrome,
 * the same scrub bar, the same green.
 *
 * The two clips are cut to show the two halves of a lesson's arc. The physics
 * one is joined while its trajectory is still drawing itself; the pricing one
 * is joined later, as the formula resolves and the takeaway lands. Between
 * them you see a lesson build an idea and then close it, which one 2.7-second
 * window of a single clip could not do.
 */

type Beat = {
  slug: string;
  /** Seconds into the clip to join at. */
  from: number;
};

const REEL: Beat[] = [
  // Joined with the trajectory already climbing, so the curve completes
  // within the beat. Joining at 4s instead opened on a bare pair of axes —
  // two seconds of nearly empty board at the exact moment the ad is trying to
  // prove there is something here.
  {slug: 'waec-physics', from: 6.2},
  // The formula resolves and the break-even takeaway lands.
  {slug: 'pricing-and-margins', from: 10.2},
];

/** Frames per clip, and the cross-dissolve between them. */
const BEAT = 82;
const DISSOLVE = 12;

export const REEL_DURATION = REEL.length * BEAT;

const Clip: React.FC<{
  beat: Beat;
  width: number;
  vertical: boolean;
  poppins: string;
  /** Frames since this clip's own beat began. */
  local: number;
}> = ({beat, width, vertical, poppins, local}) => {
  const course = bySlug(beat.slug);
  const position = filmedPosition(course);
  const lesson = course.lessons[position - 1];

  // Held at full opacity through the body of the beat and dissolved at both
  // ends, so the two clips cross rather than cutting hard. The first clip's
  // lead-in and the last one's tail are covered by the scene's own fade.
  const opacity = interpolate(
    local,
    [0, DISSOLVE, BEAT - DISSOLVE, BEAT],
    [0, 1, 1, 0],
    {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'},
  );

  // A very slow push in. The lesson boards hold still for seconds at a time,
  // and without it a held frame looks like the render has stalled.
  const zoom = interpolate(local, [0, BEAT], [1, 1.035], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: Easing.out(Easing.quad),
  });

  const played = beat.from + Math.max(0, local) / FPS;

  return (
    <div
      style={{
        position: 'absolute',
        inset: 0,
        opacity,
        fontFamily: poppins,
      }}
    >
      {/* The app's player chrome, so this still reads as the product rather
          than as footage dropped into an ad. */}
      <div
        style={{
          display: 'flex',
          alignItems: 'baseline',
          justifyContent: 'space-between',
          gap: 24,
          marginBottom: 16,
        }}
      >
        <div
          style={{
            fontSize: vertical ? 30 : 26,
            fontWeight: 600,
            color: colors.richBlack,
            whiteSpace: 'nowrap',
          }}
        >
          {lesson.title}
        </div>
        <div
          style={{
            fontSize: vertical ? 22 : 19,
            color: colors.fontGrey,
            whiteSpace: 'nowrap',
          }}
        >
          {course.title.split(':')[0]} · Lesson {position}
        </div>
      </div>

      <div
        style={{
          width,
          height: Math.round((width * 9) / 16),
          borderRadius: 20,
          overflow: 'hidden',
          background: colors.richBlack,
          boxShadow: '0 30px 70px rgba(0,0,0,0.22)',
          position: 'relative',
        }}
      >
        <OffthreadVideo
          src={staticFile(`lessons/${course.slug}.mp4`)}
          trimBefore={Math.round(beat.from * FPS)}
          muted
          style={{
            width: '100%',
            height: '100%',
            objectFit: 'cover',
            transform: `scale(${zoom})`,
          }}
        />
        <div style={{position: 'absolute', left: 26, right: 26, bottom: 20}}>
          <div
            style={{height: 4, borderRadius: 999, background: 'rgba(13,27,42,0.16)'}}
          >
            <div
              style={{
                width: `${(played / 18) * 100}%`,
                height: '100%',
                borderRadius: 999,
                background: colors.primary,
              }}
            />
          </div>
        </div>
      </div>

      {/* Vertical only. A 16:9 player inside a 9:16 frame cannot fill it, and
          the space underneath read as the scene having stopped early. This
          puts the course the lesson belongs to — and its price — in the gap,
          which is the one thing the scene was otherwise not saying. There is
          no room for it in landscape, where the player is already most of the
          frame; the copy is identical either way. */}
      {vertical ? (
        <div
          style={{
            marginTop: 40,
            display: 'flex',
            alignItems: 'center',
            gap: 24,
            padding: 24,
            borderRadius: 22,
            background: colors.appWhite,
            boxShadow: '0 14px 36px rgba(0,0,0,0.08)',
          }}
        >
          <Img
            src={staticFile(`thumbs/${course.slug}.jpg`)}
            style={{
              width: 176,
              height: 99,
              objectFit: 'cover',
              borderRadius: 12,
              flexShrink: 0,
            }}
          />
          <div style={{flex: 1, minWidth: 0}}>
            <div
              style={{
                fontSize: 27,
                fontWeight: 600,
                color: colors.richBlack,
                lineHeight: 1.25,
              }}
            >
              {course.title}
            </div>
            <div style={{fontSize: 21, color: colors.fontGrey, marginTop: 7}}>
              {course.author} · Lesson {position} of {course.lessons.length}
            </div>
          </div>
          <div
            style={{
              fontSize: 30,
              fontWeight: 700,
              color: colors.primary,
              whiteSpace: 'nowrap',
            }}
          >
            {priceLabel(course.price)}
          </div>
        </div>
      ) : null}
    </div>
  );
};

export const LessonReel: React.FC<{poppins: string; playfair: string}> = ({
  poppins,
  playfair,
}) => {
  const frame = useCurrentFrame();
  const {width: frameWidth, height} = useVideoConfig();
  const vertical = height > frameWidth;

  const playerWidth = vertical ? 1000 : 1120;
  // Chrome row plus its margin, and the course strip where there is one, so
  // the centred stack reserves the clip's true height instead of letting it
  // overflow below centre.
  const chrome = vertical ? 52 : 48;
  const strip = vertical ? 187 : 0;
  const blockHeight = Math.round((playerWidth * 9) / 16) + chrome + strip;

  return (
    <AbsoluteFill
      style={{
        // Warm off-white rather than the app white the other scenes use. The
        // lesson boards are themselves near-white (#FBFAF7), and on a pure
        // white page the player had no edge — only its shadow separated the
        // footage from the frame around it.
        background: '#F2F0EB',
        alignItems: 'center',
        justifyContent: 'center',
        flexDirection: 'column',
        gap: vertical ? 64 : 44,
      }}
    >
      <div style={{textAlign: 'center', padding: '0 80px'}}>
        <div
          style={{
            fontFamily: playfair,
            fontSize: vertical ? 72 : 58,
            fontWeight: 700,
            color: colors.richBlack,
            letterSpacing: -1,
            lineHeight: 1.08,
          }}
        >
          {script.lesson.title}
        </div>
        <div
          style={{
            fontFamily: poppins,
            fontSize: vertical ? 30 : 25,
            color: colors.fontGrey,
            marginTop: 14,
          }}
        >
          {script.lesson.sub}
        </div>
      </div>

      {/* Both clips are mounted and cross-faded in place rather than being
          sequenced, so the layout never reflows between them and the dissolve
          is a true cross rather than one element replacing another. */}
      <div style={{position: 'relative', width: playerWidth, height: blockHeight}}>
        {REEL.map((beat, i) => (
          <Clip
            key={beat.slug}
            beat={beat}
            width={playerWidth}
            vertical={vertical}
            poppins={poppins}
            local={frame - i * BEAT}
          />
        ))}
      </div>
    </AbsoluteFill>
  );
};
