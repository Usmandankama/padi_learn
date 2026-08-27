import React from 'react';
import {interpolate, useCurrentFrame} from 'remotion';
import {colors} from '../theme';
import {StatusBar} from './Phone';

const lessons = [
  {title: 'Simultaneous equations', mins: 8, done: true},
  {title: 'Quadratic equations', mins: 12, done: true},
  {title: 'Indices and logarithms', mins: 10, done: false},
  {title: 'Sequences and series', mins: 14, done: false},
  {title: 'Probability basics', mins: 9, done: false},
];

/**
 * A course's lesson list mid-playback, with the progress bar filling.
 *
 * The point of the scene is the resume behaviour, so the third row is shown
 * part-watched rather than the list being uniformly untouched.
 */
export const LessonMock: React.FC<{
  poppins: string;
  playfair: string;
  startFrame?: number;
}> = ({poppins, playfair, startFrame = 0}) => {
  const frame = useCurrentFrame() - startFrame;

  const progress = interpolate(frame, [12, 70], [0.18, 0.46], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const scrub = interpolate(frame, [12, 70], [0.22, 0.63], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

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
          background: `linear-gradient(135deg, ${colors.primary}, #1F6B4F)`,
          position: 'relative',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <div
          style={{
            width: 54,
            height: 54,
            borderRadius: 999,
            background: 'rgba(255,255,255,0.22)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            fontSize: 20,
            color: colors.appWhite,
            paddingLeft: 4,
          }}
        >
          ▶
        </div>
        <div style={{position: 'absolute', left: 14, right: 14, bottom: 12}}>
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
          }}
        >
          JAMB Mathematics
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

        <div style={{marginTop: 16, display: 'flex', flexDirection: 'column', gap: 9}}>
          {lessons.map((lesson, i) => {
            const active = i === 2;
            return (
              <div
                key={lesson.title}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: 10,
                  padding: '10px 12px',
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
                    background: lesson.done ? colors.primary : 'transparent',
                    border: lesson.done ? 'none' : `1.5px solid ${colors.lightGrey}`,
                    color: colors.appWhite,
                    fontSize: 11,
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                  }}
                >
                  {lesson.done ? '✓' : ''}
                </div>
                <div style={{flex: 1}}>
                  <div
                    style={{
                      fontSize: 12,
                      fontWeight: active ? 600 : 500,
                      color: colors.richBlack,
                    }}
                  >
                    {lesson.title}
                  </div>
                  {active ? (
                    <div style={{fontSize: 9.5, color: colors.primary, marginTop: 2}}>
                      Resume from 4:12
                    </div>
                  ) : null}
                </div>
                <div style={{fontSize: 10.5, color: colors.fontGrey}}>
                  {lesson.mins} min
                </div>
              </div>
            );
          })}
        </div>

        {/* The list alone left the bottom third of the screen blank, which read
            as an unfinished screen rather than a real one. */}
        <div
          style={{
            marginTop: 18,
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
            marginTop: 16,
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
            IY
          </div>
          <div style={{flex: 1}}>
            <div
              style={{
                fontSize: 12,
                fontWeight: 600,
                color: colors.richBlack,
              }}
            >
              Ibrahim Yusuf
            </div>
            <div style={{fontSize: 10, color: colors.fontGrey, marginTop: 1}}>
              1.2k students · 4.8 ★
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
