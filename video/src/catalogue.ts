/**
 * The demo catalogue, mirrored from `supabase/seed/demo_catalogue.sql`.
 *
 * Kept as a straight copy for the same reason `theme.ts` copies
 * `colors.dart`: the ad has to show the catalogue the app actually serves, and
 * a diff between this file and the seed should be readable at a glance. If the
 * seed changes, this follows.
 *
 * One row of the seed is deliberately not here: `welcome-to-padilearn`, whose
 * lesson video *is this ad*. Listing it would put the ad inside the ad, and
 * would make a render depend on the output of the previous one, since its
 * thumbnail is a frame of the finished cut. The marketplace scene therefore
 * counts eleven where the app counts twelve — under by one, which is the safe
 * direction for a number in an advert.
 *
 * The eleven subject courses each have exactly one lesson with real footage —
 * the one `video/public/lessons/<slug>.mp4` holds. That lesson's number is
 * **burned into the video** ("WAEC PHYSICS · LESSON 14" sits in the top-left of
 * every frame), which is why the courses are as long as they are: the app
 * numbers curriculum rows by their position in the list, so a course whose
 * fourteenth lesson is Projectile Motion has to actually have fourteen.
 */

export type Lesson = {
  title: string;
  /** True for the one lesson whose real video exists. */
  filmed?: boolean;
};

export type Course = {
  slug: string;
  title: string;
  author: string;
  category: string | null;
  /** Naira. 0 renders as "Free". */
  price: number;
  lessons: Lesson[];
};

/**
 * Course titles start with the exact course name the videos print in their
 * own chrome ("WAEC Physics", "Pricing & Margins", "Practical Electrical
 * Work"), so the catalogue and the footage cannot contradict each other.
 */
export const courses: Course[] = [
  {
    slug: 'waec-physics',
    title: 'WAEC Physics: Motion, Forces and Energy',
    author: 'Ibrahim Yusuf',
    category: 'Exam Prep',
    price: 3000,
    lessons: [
      {title: 'How WAEC physics is marked'},
      {title: 'Measurement and units'},
      {title: 'Scalars and vectors'},
      {title: 'Distance, speed and velocity'},
      {title: 'Acceleration and the equations of motion'},
      {title: "Newton's laws"},
      {title: 'Momentum and collisions'},
      {title: 'Work, energy and power'},
      {title: 'Friction'},
      {title: 'Circular motion'},
      {title: 'Equilibrium and moments'},
      {title: 'Simple harmonic motion'},
      {title: 'Resolving vectors'},
      {title: 'Projectile Motion', filmed: true},
      {title: 'Density and upthrust'},
      {title: 'Past paper walkthrough'},
    ],
  },
  {
    slug: 'waec-mathematics',
    title: 'WAEC Mathematics: Algebra and Quadratics',
    author: 'Ibrahim Yusuf',
    category: 'Exam Prep',
    price: 3500,
    lessons: [
      {title: 'How WAEC maths is marked'},
      {title: 'Number bases'},
      {title: 'Fractions, indices and surds'},
      {title: 'Logarithms'},
      {title: 'Linear equations'},
      {title: 'Simultaneous equations'},
      {title: 'Completing the Square', filmed: true},
      {title: 'The quadratic formula'},
      {title: 'Sequences and series'},
      {title: 'Geometry and circle theorems'},
      {title: 'Trigonometry'},
      {title: 'Statistics and probability'},
    ],
  },
  {
    slug: 'waec-chemistry',
    title: 'WAEC Chemistry: Moles and Calculations',
    author: 'Ngozi Adeyemi',
    category: 'Exam Prep',
    price: 3000,
    lessons: [
      {title: 'States of matter'},
      {title: 'Atomic structure'},
      {title: 'The Mole', filmed: true},
      {title: 'Chemical formulae and equations'},
      {title: 'Stoichiometry'},
      {title: 'Acids, bases and salts'},
      {title: 'Redox reactions'},
      {title: 'Rates of reaction'},
      {title: 'Organic chemistry basics'},
      {title: 'Past paper walkthrough'},
    ],
  },
  {
    slug: 'bookkeeping',
    title: 'Bookkeeping: Keep Books That Balance',
    author: 'Musa Danladi',
    category: 'Business',
    price: 0,
    lessons: [
      {title: 'The Accounting Equation', filmed: true},
      {title: 'Debits and credits'},
      {title: 'The cash book'},
      {title: 'Ledgers and the trial balance'},
      {title: 'Invoices, receipts and keeping records'},
      {title: 'The profit and loss account'},
      {title: 'The balance sheet'},
      {title: 'Closing the month'},
    ],
  },
  {
    slug: 'pricing-and-margins',
    title: 'Pricing & Margins: Price So You Profit',
    author: 'Tunde Bakare',
    category: 'Business',
    price: 4000,
    lessons: [
      {title: 'What your product really costs'},
      {title: 'Fixed cost and variable cost'},
      {title: 'Markup and margin'},
      {title: 'Break-even Point', filmed: true},
      {title: 'Pricing against your competition'},
      {title: 'Discounts that do not kill you'},
      {title: 'Raising your price without losing customers'},
    ],
  },
  {
    slug: 'tailoring',
    title: 'Tailoring: Patterns That Fit',
    author: 'Grace Eze',
    category: 'Fashion & Tailoring',
    price: 5000,
    lessons: [
      {title: 'Tools and your workspace'},
      {title: 'Fabric types and grain'},
      {title: 'Taking measurements'},
      {title: 'Reading a size chart'},
      {title: 'Drafting a basic block'},
      {title: 'Seam allowance'},
      {title: 'Cutting cleanly'},
      {title: 'Darts: what they do'},
      {title: 'The Bust Dart', filmed: true},
      {title: 'Sleeves and armholes'},
      {title: 'Zips, buttons and finishing'},
      {title: 'Pressing and presentation'},
    ],
  },
  {
    slug: 'electrical-work',
    title: 'Practical Electrical Work: Circuits and Wiring',
    author: 'Emeka Okafor',
    category: 'Trades & Vocational',
    price: 6000,
    lessons: [
      {title: 'Safety first'},
      {title: 'Tools and test equipment'},
      {title: 'Voltage, current and resistance'},
      {title: "Ohm's law"},
      {title: 'Series and Parallel', filmed: true},
      {title: 'Reading a circuit diagram'},
      {title: 'Cables and cable sizing'},
      {title: 'Wiring a socket outlet'},
      {title: 'Earthing and protection'},
      {title: 'Fault finding'},
    ],
  },
  {
    slug: 'excel-for-business',
    title: 'Excel for Business: Formulas That Earn',
    author: 'Musa Danladi',
    category: 'Business',
    price: 2500,
    lessons: [
      {title: 'Getting around a spreadsheet'},
      {title: 'Entering and formatting data'},
      {title: 'Cell references'},
      {title: 'SUM, AVERAGE and COUNT'},
      {title: 'IF and nested IF'},
      {title: 'Sorting and filtering'},
      {title: 'Conditional formatting'},
      {title: 'Charts that communicate'},
      {title: 'Named ranges'},
      {title: 'VLOOKUP'},
      {title: "VLOOKUP's One Limitation", filmed: true},
      {title: 'Pivot tables'},
      {title: "Cleaning somebody else's spreadsheet"},
      {title: 'Printing without the mess'},
    ],
  },
  {
    slug: 'programming-fundamentals',
    title: 'Programming Fundamentals: Algorithms That Matter',
    author: 'Amaka Obi',
    category: 'Programming',
    price: 7500,
    lessons: [
      {title: 'What a program is'},
      {title: 'Variables and types'},
      {title: 'Conditions'},
      {title: 'Loops'},
      {title: 'Functions'},
      {title: 'Lists and arrays'},
      {title: 'Linear search'},
      {title: 'Binary Search', filmed: true},
      {title: 'Sorting'},
      {title: 'Big-O notation'},
      {title: 'Dictionaries and maps'},
      {title: 'Reading and writing files'},
    ],
  },
  {
    slug: 'graphic-design',
    title: 'Graphic Design: Type, Scale and Layout',
    author: 'Daniel Effiong',
    category: 'Design',
    price: 4500,
    lessons: [
      {title: 'What design is for'},
      {title: 'The Type Scale', filmed: true},
      {title: 'Choosing typefaces'},
      {title: 'Colour and contrast'},
      {title: 'Grids and alignment'},
      {title: 'White space'},
      {title: 'Logos and marks'},
      {title: 'Designing for print and for screen'},
      {title: 'Preparing files for the printer'},
    ],
  },
  {
    slug: 'broiler-farming',
    title: 'Broiler Farming: Feed, Weight and Margin',
    author: 'Fatima Bello',
    category: 'Agriculture',
    price: 3500,
    lessons: [
      {title: 'Is broiler farming for you?'},
      {title: 'Housing and ventilation'},
      {title: 'Buying day-old chicks'},
      {title: 'Brooding the first two weeks'},
      {title: 'Feed types and schedules'},
      {title: 'Feed Conversion Ratio', filmed: true},
      {title: 'Water and medication'},
      {title: 'Biosecurity and disease'},
      {title: 'Weighing and selling'},
      {title: 'Costing a full cycle'},
    ],
  },
];

/** 1-based position of the course's filmed lesson, as the app numbers them. */
export const filmedPosition = (course: Course) =>
  course.lessons.findIndex((lesson) => lesson.filmed) + 1;

export const bySlug = (slug: string): Course => {
  const found = courses.find((course) => course.slug === slug);
  if (!found) throw new Error(`No course with slug "${slug}" in the catalogue`);
  return found;
};

/** Mirrors `formatPriceLabel` in course_card.dart. */
export const priceLabel = (price: number) =>
  price <= 0 ? 'Free' : `NGN ${Math.round(price)}`;

/** Mirrors `formatStudentCount` in course_card.dart. */
export const studentCount = (value: number) =>
  value >= 1000 ? `${(value / 1000).toFixed(1)}k` : String(Math.round(value));

/**
 * What the cards print for enrolments and rating.
 *
 * Zero and "New", because that is what the seeded app actually renders: the
 * 2026-09-14 migration made both columns trigger-derived and the seed leaves
 * them at zero, so a card for a brand-new course shows no count and the rating
 * pill falls back to "New" (course_card.dart, `rating.count > 0 ? … : 'New'`).
 *
 * The ad could invent traction here — the previous cut did, with figures like
 * "1.2k students" — but a public ad is a worse place to fabricate it than the
 * demo database was, and the database already had it taken out. At card size
 * the line is a few pixels tall and unreadable either way, so the fake bought
 * nothing.
 */
export const DEMO_ENROLMENTS = 0;
