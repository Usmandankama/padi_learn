import React from 'react';
import {Easing, interpolate, spring, useCurrentFrame, useVideoConfig} from 'remotion';
import {colors} from '../theme';
import {CourseCard} from './CourseCard';
import {courses} from '../catalogue';
import {StatusBar} from './Phone';

const CARD_HEIGHT = 186;
const GAP = 13;

/**
 * The marketplace grid, with cards springing in and the list then drifting up.
 *
 * Every course in the seeded catalogue is here, all eleven, rather than the
 * six that used to fit in one screenful — the scene's job is to show that
 * there is a catalogue, and a grid that visibly continues past the fold does
 * that better than a grid that stops. The drift is slow and eased out: it
 * should read as a list being scrolled, not as the screen panning.
 *
 * `delay` staggers each card by two frames rather than animating the grid as a
 * block — the eye reads the former as content arriving and the latter as a
 * slide transition.
 */
export const MarketplaceMock: React.FC<{
  poppins: string;
  playfair: string;
  startFrame?: number;
  /** Frames over which the grid drifts up to reveal the rest of the list. */
  scrollOver?: number;
}> = ({poppins, playfair, startFrame = 0, scrollOver = 150}) => {
  const frame = useCurrentFrame() - startFrame;
  const {fps} = useVideoConfig();

  const rows = Math.ceil(courses.length / 2);
  const hidden = Math.max(0, rows * (CARD_HEIGHT + GAP) - 430);
  const scroll = interpolate(frame, [26, scrollOver], [0, hidden], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: Easing.inOut(Easing.quad),
  });

  return (
    <div
      style={{
        width: '100%',
        height: '100%',
        background: colors.appWhite,
        fontFamily: poppins,
        overflow: 'hidden',
      }}
    >
      <StatusBar poppins={poppins} />

      <div style={{padding: '4px 20px 0'}}>
        <div
          style={{
            fontFamily: playfair,
            fontSize: 26,
            fontWeight: 700,
            color: colors.primary,
          }}
        >
          Marketplace
        </div>
        <div style={{fontSize: 11.5, color: colors.fontGrey, marginTop: 2}}>
          {/* The real number, not a flattering multiple of it. Eleven is what
              is on the shelf; the seed's twelfth row is the welcome tour,
              which is this ad and is not in `catalogue.ts`. Under by one
              rather than over. */}
          {courses.length} courses available
        </div>

        <div
          style={{
            marginTop: 14,
            height: 38,
            borderRadius: 12,
            border: `1px solid ${colors.lightGrey}`,
            display: 'flex',
            alignItems: 'center',
            padding: '0 12px',
            gap: 8,
            color: colors.fontGrey,
            fontSize: 12,
          }}
        >
          <span>⌕</span>
          <span>Search courses</span>
        </div>

        <div style={{display: 'flex', gap: 7, marginTop: 12}}>
          {['All', 'Exam Prep', 'Business', 'Trades'].map((chip, i) => (
            <div
              key={chip}
              style={{
                fontSize: 10.5,
                fontWeight: 600,
                padding: '6px 11px',
                borderRadius: 999,
                background: i === 0 ? colors.primary : colors.primaryAccent,
                color: i === 0 ? colors.appWhite : colors.primary,
                whiteSpace: 'nowrap',
              }}
            >
              {chip}
            </div>
          ))}
        </div>

        {/* Clipped to the screen so the drifting grid runs off the bottom edge
            the way a real scroll view does, instead of spilling over the
            phone's bezel. */}
        <div style={{marginTop: 16, height: 430, overflow: 'hidden'}}>
          <div
            style={{
              display: 'grid',
              gridTemplateColumns: '1fr 1fr',
              gap: GAP,
              transform: `translateY(${-scroll}px)`,
            }}
          >
            {courses.map((course, i) => {
              const entrance = spring({
                frame: frame - 10 - i * 2,
                fps,
                config: {damping: 200, mass: 0.6},
              });
              return (
                <div
                  key={course.slug}
                  style={{
                    height: CARD_HEIGHT,
                    opacity: entrance,
                    transform: `translateY(${interpolate(
                      entrance,
                      [0, 1],
                      [26, 0],
                    )}px)`,
                  }}
                >
                  <CourseCard course={course} poppins={poppins} />
                </div>
              );
            })}
          </div>
        </div>
      </div>
    </div>
  );
};
