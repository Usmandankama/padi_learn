import React from 'react';
import {colors} from '../theme';

export type Course = {
  title: string;
  author: string;
  category: string;
  price: number;
  students: number;
  rating: number;
  /** Two-stop gradient standing in for the thumbnail image. */
  thumb: [string, string];
};

/** Mirrors `formatPriceLabel` in course_card.dart. */
const priceLabel = (price: number) =>
  price <= 0 ? 'Free' : `NGN ${Math.round(price)}`;

/** Mirrors `formatStudentCount` in course_card.dart. */
const studentCount = (value: number) =>
  value >= 1000 ? `${(value / 1000).toFixed(1)}k` : String(Math.round(value));

const initials = (name: string) =>
  name
    .split(' ')
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase() ?? '')
    .join('');

/**
 * A React recreation of the app's `CourseCard`.
 *
 * Proportions follow the Flutter widget — 18px radius, the 11:10 thumbnail to
 * body split, Poppins 13.5 at w600 for the title — so footage of "the app"
 * matches what actually ships rather than an idealised redraw of it.
 */
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
      <div
        style={{
          flex: 11,
          position: 'relative',
          background: `linear-gradient(135deg, ${course.thumb[0]}, ${course.thumb[1]})`,
        }}
      >
        <div
          style={{
            position: 'absolute',
            top: 8,
            left: 8,
            background: 'rgba(255,255,255,0.92)',
            color: colors.richBlack,
            fontSize: 8.5,
            fontWeight: 600,
            padding: '3px 7px',
            borderRadius: 999,
          }}
        >
          {course.category}
        </div>
        <div
          style={{
            position: 'absolute',
            top: 8,
            right: 8,
            display: 'flex',
            alignItems: 'center',
            gap: 3,
            background: 'rgba(13,27,42,0.72)',
            color: colors.appWhite,
            fontSize: 8.5,
            fontWeight: 600,
            padding: '3px 7px',
            borderRadius: 999,
          }}
        >
          <span style={{fontSize: 9, lineHeight: 1}}>★</span>
          {course.rating.toFixed(1)}
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
            }}
          >
            {initials(course.author)}
          </div>
          <div
            style={{
              fontSize: 10,
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
          <div style={{fontSize: 9.5, color: colors.fontGrey}}>
            {studentCount(course.students)} students
          </div>
          <div
            style={{
              fontSize: 11.5,
              fontWeight: 700,
              color: course.price <= 0 ? colors.primary : colors.richBlack,
            }}
          >
            {priceLabel(course.price)}
          </div>
        </div>
      </div>
    </div>
  );
};

/** Stand-in catalogue. Swap for your real seed data once it exists. */
export const demoCourses: Course[] = [
  {
    title: 'JAMB Mathematics: Past Questions Solved',
    author: 'Ibrahim Yusuf',
    category: 'Exam Prep',
    price: 3500,
    students: 1240,
    rating: 4.8,
    thumb: ['#32936F', '#1F6B4F'],
  },
  {
    title: 'Flutter for Beginners',
    author: 'Amaka Obi',
    category: 'Programming',
    price: 7500,
    students: 860,
    rating: 4.7,
    thumb: ['#0D1B2A', '#25405C'],
  },
  {
    title: 'Start a Small Business in Nigeria',
    author: 'Tunde Bakare',
    category: 'Business',
    price: 0,
    students: 3120,
    rating: 4.6,
    thumb: ['#C9822F', '#8A5418'],
  },
  {
    title: 'Tailoring: From Measurement to Finish',
    author: 'Grace Eze',
    category: 'Fashion & Tailoring',
    price: 5000,
    students: 640,
    rating: 4.9,
    thumb: ['#7B4B94', '#4A2C59'],
  },
  {
    title: 'Excel for Office Work',
    author: 'Musa Danladi',
    category: 'Business',
    price: 2500,
    students: 1980,
    rating: 4.5,
    thumb: ['#1D6F42', '#0F3D24'],
  },
  {
    title: 'Digital Marketing with WhatsApp',
    author: 'Chioma Nwosu',
    category: 'Marketing',
    price: 4000,
    students: 1450,
    rating: 4.7,
    thumb: ['#2B6CB0', '#1A4272'],
  },
];
