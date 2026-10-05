/**
 * Copy for the "first teachers" announcement — the flyer and the short video.
 *
 * Separate from `theme.ts`'s `script`, which belongs to the product ad. This
 * is a different piece with a different job: the ad explains PadiLearn to
 * someone who might learn on it, this asks someone who already teaches to put
 * a course on it before there is one.
 *
 *
 * WHAT IS TRUE, AND THEREFORE WHAT THIS MAY SAY
 * ---------------------------------------------
 * Checked against `docs/PRODUCT_OVERVIEW.md` rather than written from
 * impression, because a recruitment pitch is a promise to a person who may
 * act on it:
 *
 *   - Teacher keeps 85% of the list price, platform 15%.           TRUE
 *   - The list price is what settles; the card fee is added on top
 *     at checkout and paid by the student.                         TRUE
 *   - One-off payment per course, no subscription, NGN only.       TRUE
 *   - A NGN 5,000 course: student pays 5,178, teacher earns 4,250. TRUE
 *   - Teachers set their own price.                                TRUE
 *
 * And what it must NOT say, which is most of what a recruitment ad would
 * normally reach for:
 *
 *   - "Start earning today" — there is nothing to earn from yet. The app has
 *     never been on a store, no real sale has been made, and the closed beta
 *     ships free courses only (`kPaidCheckoutEnabled` is off).
 *   - "Get paid straight to your account" — the product ad says this, and it
 *     is ahead of itself here. Payouts are not built: `payout_accounts` and
 *     the ledger exist, moving money to a teacher is manual and undesigned.
 *     So this piece talks about the split and never about the mechanism.
 *   - "Join thousands of teachers" — there are two teacher accounts, both
 *     ours.
 *
 * The honest pitch is the one below: the terms are real, the product is not
 * open yet, and that is exactly the offer — come in before it is.
 */

export const announcement = {
  eyebrow: 'Calling first teachers',

  /**
   * One per beat of the video, in order.
   *
   * Line breaks are set by hand, not left to wrapping. At display size a
   * 1080-wide frame fits about fifteen characters a line, and a statement
   * that breaks where the measure runs out rather than where the sense does
   * reads as a paragraph that got too big. Broken deliberately, each line is
   * a phrase and the stack reads as a statement.
   */
  beats: [
    'You already\nteach.',
    'For free.\nIn your DMs.\nEvery week.',
    'Put it in a\ncourse instead.',
  ],

  /** The figure the whole piece is built around. */
  share: {
    figure: '85%',
    of: 'of every sale is yours.',
  },

  /** Plain terms. No adjectives — the numbers are the argument. */
  terms: [
    'You set the price.',
    'Students pay once. Not monthly.',
    'The card fee is theirs, not yours.',
  ],

  /** Worked from the real split in `lib/utils/pricing.dart`. */
  worked: {
    label: 'A course you list at',
    price: '₦5,000',
    middle: 'pays you',
    earn: '₦4,250',
  },

  /**
   * The status line, which is the part that keeps this honest. It says
   * plainly that nothing is open yet.
   */
  status: "PadiLearn launches on Android soon.\nWe're building the first catalogue now.",

  /**
   * Flyer body. Short sentences, no em-dashes: a long dash in the middle of a
   * line is the current tell for copy nobody wrote, and this piece cannot
   * afford to read as generated when it is asking a stranger to trust it with
   * their work.
   */
  blurb:
    'You explain it for free every week anyway. To an apprentice, a cousin, somebody in your DMs. Record it once and sell it for as long as people need it.',

  cta: {
    site: 'padilearn.com',
    email: 'hello@padilearn.com',
  },

  /** Dateline. Real metadata, not decoration — it dates the offer. */
  colophon: 'Lagos · 2026',
} as const;
