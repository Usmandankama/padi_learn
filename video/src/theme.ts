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

/**
 * Direction for whoever finishes this — sound designer, VO artist, editor.
 *
 * Lives here beside the copy rather than in a separate document so the notes
 * and the thing they describe cannot drift apart: retime a scene in `SCENES`
 * and the notes overlay follows automatically, because it reads the same table.
 *
 * Rendered only by the `EditorsNotes` composition, never by the ad itself.
 */
export const directions = {
  hook: {
    vo: '"Everybody sabi something. Somebody dey wait to learn am."',
    sound:
      'Room tone from frame 1. One low sub hit as the title lands — no music yet. The silence is doing work; do not fill it.',
    vibe: 'Direct address. Someone talking to you across a table, not an announcer reading copy.',
  },
  browse: {
    vo: '"Find your course. Exam prep, coding, business, fashion — from teachers like you."',
    sound:
      'Music enters HERE, not earlier. Mid-tempo, warm, Afrobeats-adjacent but understated. Soft UI tick per card as it lands — six of them, ~2 frames apart, low in the mix.',
    vibe: 'Bright and curious. This is the widest the world gets; let it feel like a lot of choice.',
  },
  learn: {
    vo: '"Learn at your pace. Download once, pick up exactly where you stopped."',
    sound:
      'Pull the music back a notch — this is the reassurance beat. One soft chime as the progress bar fills.',
    vibe: 'Calmer, focused, unhurried. The pace of the cut should drop even though the visuals keep moving.',
  },
  teach: {
    vo: '"Teach what you know. Publish a course, get paid straight to your account."',
    sound:
      'Music lifts. Ascending ticks under the naira figure while it counts, landing on one resolved note as it stops. The number stopping is the beat — hit it exactly.',
    vibe: 'The turn. Dark card, different register: this is addressing a different person than the last three scenes were.',
  },
  cta: {
    vo: '"PadiLearn. Your padi for learning."',
    sound:
      'Whoosh on the bowl sweep, soft organic note on the leaf pop (wood or plucked string, not a synth ping). Music resolves on the wordmark. Let the last second ring out.',
    vibe: 'Clean landing. Do not rush the end card — the logo build is the payoff and it needs its full beat.',
  },
} as const;

/** Notes that apply across the whole cut. */
export const globalDirections = [
  'Music must be licensed or original. Avoiding a rights problem is the reason this was built rather than assembled from clips — do not reintroduce one at the last step.',
  'Burn captions for anything going to social. Most of it is watched muted, and the VO carries the argument.',
  'Total runtime 24s. If a 15s cut is needed, drop the "Learn at your pace" scene — it is the most self-contained, and browse → teach still tells the whole story.',
  'The naira figure in the teach scene is illustrative. Replace it with a real number or reword the label before this goes anywhere public.',
] as const;
