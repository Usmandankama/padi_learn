import React from 'react';
import {interpolate, spring, useCurrentFrame, useVideoConfig} from 'remotion';
import {colors} from '../theme';
import {CourseCard, demoCourses} from './CourseCard';
import {StatusBar} from './Phone';

/**
 * The marketplace grid, with cards springing in one after another.
 *
 * `delay` staggers each card by two frames rather than animating the grid as a
 * block — the eye reads the former as content arriving and the latter as a
 * slide transition.
 */
export const MarketplaceMock: React.FC<{
  poppins: string;
  playfair: string;
  startFrame?: number;
}> = ({poppins, playfair, startFrame = 0}) => {
  const frame = useCurrentFrame() - startFrame;
  const {fps} = useVideoConfig();

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
          {demoCourses.length * 34} courses available
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
          {['All', 'Exam Prep', 'Programming', 'Business'].map((chip, i) => (
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

        <div
          style={{
            marginTop: 16,
            display: 'grid',
            gridTemplateColumns: '1fr 1fr',
            gap: 13,
          }}
        >
          {demoCourses.map((course, i) => {
            const entrance = spring({
              frame: frame - 10 - i * 2,
              fps,
              config: {damping: 200, mass: 0.6},
            });
            return (
              <div
                key={course.title}
                style={{
                  height: 186,
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
  );
};
