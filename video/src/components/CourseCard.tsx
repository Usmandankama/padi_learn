import React from 'react';
import {Img, staticFile} from 'remotion';
import {colors} from '../theme';
import {Course, DEMO_ENROLMENTS, priceLabel, studentCount} from '../catalogue';

/**
 * A React recreation of the app's `CourseCard`.
 *
 * Follows `course_card.dart` as closely as a mock can: 18px radius, the 11:10
 * thumbnail-to-body split, Poppins 13.5 w600 for the title, and the real
 * widget's chrome — category pill top-left in brand green on white, rating
 * pill bottom-left over a bottom-weighted scrim, price always in green.
 *
 * Three of those were wrong in the previous cut (the rating pill sat top-right
 * in navy, the category pill printed in ink rather than green, and a paid
 * course's price printed in ink instead of green), which is the failure mode
 * the README warns about: the mock drifting from the screen it claims to show.
 */

const initials = (name: string) =>
  name
    .split(' ')
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase() ?? '')
    .join('');

export const CourseCard: React.FC<{course: Course; poppins: string}> = ({
  course,
  poppins,
}) => {
  return (
    <div
      style={{
        background: colors.appWhite,
        borderRadius: 18,
        border: '1px solid rgba(0,0,0,0.04)',
        boxShadow: '0 6px 14px rgba(0,0,0,0.07)',
        overflow: 'hidden',
        display: 'flex',
        flexDirection: 'column',
        height: '100%',
        fontFamily: poppins,
      }}
    >
      <div style={{flex: 11, position: 'relative', overflow: 'hidden'}}>
        {/* The real thumbnail the seeded catalogue points at, not a gradient
            standing in for one: `course-thumbnails/demo/<slug>.jpg` and
            `video/public/thumbs/<slug>.jpg` are the same image. */}
        <Img
          src={staticFile(`thumbs/${course.slug}.jpg`)}
          style={{
            position: 'absolute',
            inset: 0,
            width: '100%',
            height: '100%',
            objectFit: 'cover',
          }}
        />
        {/* Bottom scrim, for the rating pill's legibility. */}
        <div
          style={{
            position: 'absolute',
            inset: 0,
            background:
              'linear-gradient(to bottom, transparent 55%, rgba(0,0,0,0.45) 100%)',
          }}
        />
        {course.category ? (
          <div
            style={{
              position: 'absolute',
              top: 10,
              left: 10,
              background: 'rgba(255,255,255,0.88)',
              color: colors.primary,
              fontSize: 9.5,
              fontWeight: 600,
              padding: '4px 10px',
              borderRadius: 20,
            }}
          >
            {course.category}
          </div>
        ) : null}
        <div
          style={{
            position: 'absolute',
            bottom: 10,
            left: 10,
            display: 'flex',
            alignItems: 'center',
            gap: 3,
            background: 'rgba(0,0,0,0.55)',
            color: colors.appWhite,
            fontSize: 10,
            fontWeight: 600,
            padding: '3px 8px',
            borderRadius: 20,
          }}
        >
          {/* No star, and the word "New": that is what every seeded course
              shows, because `rating_count` is trigger-derived and the seed
              leaves it at zero. The star only appears once a course has a
              real rating to print. */}
          New
        </div>
      </div>

      <div
        style={{
          flex: 10,
          padding: '10px 12px 12px',
          display: 'flex',
          flexDirection: 'column',
          justifyContent: 'space-between',
        }}
      >
        <div
          style={{
            fontSize: 13.5,
            lineHeight: 1.25,
            fontWeight: 600,
            color: colors.richBlack,
            display: '-webkit-box',
            WebkitLineClamp: 2,
            WebkitBoxOrient: 'vertical',
            overflow: 'hidden',
          }}
        >
          {course.title}
        </div>

        <div style={{display: 'flex', alignItems: 'center', gap: 6}}>
          <div
            style={{
              width: 18,
              height: 18,
              borderRadius: 999,
              background: colors.primaryAccent,
              color: colors.primary,
              fontSize: 8,
              fontWeight: 700,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              flexShrink: 0,
            }}
          >
            {initials(course.author)}
          </div>
          <div
            style={{
              fontSize: 11,
              color: colors.fontGrey,
              whiteSpace: 'nowrap',
              overflow: 'hidden',
              textOverflow: 'ellipsis',
              flex: 1,
            }}
          >
            {course.author}
          </div>
        </div>

        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
          }}
        >
          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: 3,
              fontSize: 11,
              color: colors.fontGrey,
            }}
          >
            {/* Stands in for Icons.people_alt_outlined. */}
            <svg width={12} height={12} viewBox="0 0 24 24" fill="none">
              <circle cx={9} cy={8} r={3.2} stroke={colors.fontGrey} strokeWidth={1.8} />
              <path
                d="M3.4 19c0-3 2.5-4.6 5.6-4.6s5.6 1.6 5.6 4.6"
                stroke={colors.fontGrey}
                strokeWidth={1.8}
                strokeLinecap="round"
              />
              <path
                d="M16.4 6.2a3 3 0 0 1 0 5.6M17.4 14.8c2.1.5 3.4 1.9 3.4 4.2"
                stroke={colors.fontGrey}
                strokeWidth={1.8}
                strokeLinecap="round"
              />
            </svg>
            {studentCount(DEMO_ENROLMENTS)}
          </div>
          {/* Green whether the course is free or paid — the real widget only
              changes this colour for a course you already own. */}
          <div style={{fontSize: 13, fontWeight: 700, color: colors.primary}}>
            {priceLabel(course.price)}
          </div>
        </div>
      </div>
    </div>
  );
};
