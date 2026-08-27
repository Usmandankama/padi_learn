/**
 * Brand tokens, mirrored from `lib/utils/colors.dart`.
 *
 * Kept as a straight copy rather than anything clever: if the app's palette
 * changes, this file is the one place the video needs to follow, and a diff
 * against colors.dart should be readable at a glance.
 */
export const colors = {
  primary: '#32936F',
  /** 0x1832936F — the app's 9.4% primary tint. */
  primaryAccent: 'rgba(50, 147, 111, 0.094)',
  richBlack: '#0D1B2A',
  appWhite: '#FFFFFF',
  fontGrey: '#707070',
  beige: '#253031',
  lightGrey: '#D9D9D9',
} as const;

/**
 * The app's ScreenUtil design size (`main.dart`), so mock screens are laid out
 * in the same coordinate space the real widgets are written against.
 */
export const DEVICE = {width: 393, height: 852} as const;

export const FPS = 30;

/**
 * Ad copy, all in one place.
 *
 * This is the point of building the ad in code rather than a timeline: to
 * reword the whole thing you edit these strings and re-render — no re-timing,
 * no reflowing, no starting over. Line breaks are deliberate.
 */
export const script = {
  hook: {
    line1: 'Everybody sabi',
    line2: 'something.',
    sub: 'Somebody dey wait to learn am.',
  },
  browse: {
    title: 'Find your course',
    sub: 'Exam prep, coding, business, fashion — from teachers like you.',
  },
  learn: {
    title: 'Learn at your pace',
    sub: 'Download once. Pick up exactly where you stopped.',
  },
  teach: {
    title: 'Teach what you know',
    sub: 'Publish a course. Get paid straight to your account.',
  },
  cta: {
    wordmark: 'PadiLearn',
    tagline: 'Your padi for learning.',
  },
} as const;
