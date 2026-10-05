import React from 'react';
import {OffthreadVideo, interpolate, staticFile, useCurrentFrame} from 'remotion';
import {colors, FPS} from '../theme';
import {bySlug, filmedPosition} from '../catalogue';
import {StatusBar} from './Phone';

/** The course the demo student is part-way through, per the seed. */
const COURSE = bySlug('waec-mathematics');

/** Its one filmed lesson — number 7, as printed in the footage. */
const ACTIVE = filmedPosition(COURSE);

/**
 * Where the seeded `lesson_progress` row left them, in seconds.
 *
 * Nine rather than seven so the board already carries its figure when the
 * scene opens and the formula arrives during it. Resuming at seven put two of
 * the scene's three and a half seconds on a half-drawn square.
 */
const RESUME_AT = 9;

/** Five rows around the active lesson, which is as many as the screen holds. */
const WINDOW_START = ACTIVE - 3;
const VISIBLE = COURSE.lessons
  .map((lesson, index) => ({...lesson, position: index + 1}))
  .slice(WINDOW_START, WINDOW_START + 5);

const clock = (seconds: number) =>
  `${Math.floor(seconds / 60)}:${String(Math.floor(seconds % 60)).padStart(2, '0')}`;

const initials = (name: string) =>
  name.split(' ').slice(0, 2).map((part) => part[0]).join('');

/**
 * A course open mid-playback, with the real lesson video running in the
 * player.
 *
 * Everything on this screen comes from `catalogue.ts` and matches what the
 * seed puts in the database: the course, its lesson titles, which six are
 * finished, and that the student stopped seven seconds into lesson 7. That
 * lesson is the one with real footage, which is why the seed resumes there —
 * the player can then show the actual clip rather than a play triangle on a
 * green rectangle, and the "LESSON 7" burned into the video agrees with the
 * row highlighted beneath it.
 */
export const LessonMock: React.FC<{
  poppins: string;
  playfair: string;
  startFrame?: number;
}> = ({poppins, playfair, startFrame = 0}) => {
  const frame = useCurrentFrame() - startFrame;

  const done = ACTIVE - 1;
  const progress = interpolate(
    frame,
    [12, 70],
    [done / COURSE.lessons.length, (done + 0.55) / COURSE.lessons.length],
    {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'},
  );

  // The scrub bar tracks the clip the player is actually showing, so the head
  // and the picture cannot disagree.
  const played = RESUME_AT + Math.max(0, frame) / FPS;
  const scrub = Math.min(1, played / 18);

  return (
    <div
      style={{
        width: '100%',
        height: '100%',
        background: colors.appWhite,
        fontFamily: poppins,
      }}
    >
      <StatusBar poppins={poppins} />

      {/* Player */}
      <div
        style={{
          margin: '0 16px',
          height: 196,
          borderRadius: 16,
          overflow: 'hidden',
          background: colors.richBlack,
          position: 'relative',
        }}
      >
        <OffthreadVideo
          src={staticFile(`lessons/${COURSE.slug}.mp4`)}
          // Picks up where the seeded progress row stopped.
          trimBefore={RESUME_AT * FPS}
          muted
          style={{width: '100%', height: '100%', objectFit: 'cover'}}
        />
        <div style={{position: 'absolute', left: 14, right: 14, bottom: 12}}>
          <div
            style={{
              display: 'flex',
              justifyContent: 'space-between',
              fontSize: 9,
              color: 'rgba(255,255,255,0.85)',
              marginBottom: 5,
            }}
          >
            <span>{clock(played)}</span>
            <span>{clock(18)}</span>
          </div>
          <div
            style={{
              height: 3,
              borderRadius: 999,
              background: 'rgba(255,255,255,0.3)',
            }}
          >
            <div
              style={{
                width: `${scrub * 100}%`,
                height: '100%',
                borderRadius: 999,
                background: colors.appWhite,
              }}
            />
          </div>
        </div>
      </div>

      <div style={{padding: '16px 20px 0'}}>
        <div
          style={{
            fontFamily: playfair,
            fontSize: 20,
            fontWeight: 700,
            color: colors.richBlack,
            lineHeight: 1.2,
            display: '-webkit-box',
            WebkitLineClamp: 2,
            WebkitBoxOrient: 'vertical',
            overflow: 'hidden',
          }}
        >
          {COURSE.title}
        </div>

        <div style={{display: 'flex', alignItems: 'center', gap: 8, marginTop: 12}}>
          <div
            style={{
              flex: 1,
              height: 6,
              borderRadius: 999,
              background: colors.lightGrey,
            }}
          >
            <div
              style={{
                width: `${progress * 100}%`,
                height: '100%',
                borderRadius: 999,
                background: colors.primary,
              }}
            />
          </div>
          <div style={{fontSize: 11, fontWeight: 600, color: colors.primary}}>
            {Math.round(progress * 100)}%
          </div>
        </div>

        <div style={{marginTop: 14, display: 'flex', flexDirection: 'column', gap: 8}}>
          {VISIBLE.map((lesson) => {
            const active = lesson.position === ACTIVE;
            const finished = lesson.position < ACTIVE;
            return (
              <div
                key={lesson.position}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: 10,
                  padding: '9px 12px',
                  borderRadius: 12,
                  background: active ? colors.primaryAccent : 'transparent',
                  border: `1px solid ${active ? colors.primary : colors.lightGrey}`,
                }}
              >
                <div
                  style={{
                    width: 22,
                    height: 22,
                    borderRadius: 999,
                    flexShrink: 0,
                    background: finished ? colors.primary : 'transparent',
                    border: finished ? 'none' : `1.5px solid ${colors.lightGrey}`,
                    color: finished ? colors.appWhite : colors.fontGrey,
                    fontSize: finished ? 11 : 9.5,
                    fontWeight: 600,
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                  }}
                >
                  {finished ? '✓' : lesson.position}
                </div>
                <div style={{flex: 1, minWidth: 0}}>
                  <div
                    style={{
                      fontSize: 12,
                      fontWeight: active ? 600 : 500,
                      color: colors.richBlack,
                      whiteSpace: 'nowrap',
                      overflow: 'hidden',
                      textOverflow: 'ellipsis',
                    }}
                  >
                    {lesson.position}. {lesson.title}
                  </div>
                  {active ? (
                    <div style={{fontSize: 9.5, color: colors.primary, marginTop: 2}}>
                      Resume from {clock(RESUME_AT)}
                    </div>
                  ) : null}
                </div>
                <div style={{fontSize: 10.5, color: colors.fontGrey}}>
                  {clock(18)}
                </div>
              </div>
            );
          })}
        </div>

        {/* The list alone left the bottom third of the screen blank, which read
            as an unfinished screen rather than a real one. */}
        <div
          style={{
            marginTop: 16,
            height: 46,
            borderRadius: 14,
            background: colors.primary,
            color: colors.appWhite,
            fontSize: 13,
            fontWeight: 600,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            gap: 8,
          }}
        >
          <span style={{fontSize: 12}}>▼</span>
          Download for offline
        </div>

        <div
          style={{
            marginTop: 14,
            display: 'flex',
            alignItems: 'center',
            gap: 10,
            padding: '12px 4px',
            borderTop: `1px solid ${colors.lightGrey}`,
          }}
        >
          <div
            style={{
              width: 34,
              height: 34,
              borderRadius: 999,
              background: colors.primaryAccent,
              color: colors.primary,
              fontSize: 12,
              fontWeight: 700,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            {initials(COURSE.author)}
          </div>
          <div style={{flex: 1}}>
            <div style={{fontSize: 12, fontWeight: 600, color: colors.richBlack}}>
              {COURSE.author}
            </div>
            <div style={{fontSize: 10, color: colors.fontGrey, marginTop: 1}}>
              {COURSE.lessons.length} lessons · New
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
