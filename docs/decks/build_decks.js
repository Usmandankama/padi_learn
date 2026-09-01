/**
 * Builds the two PadiLearn decks.
 *
 * Everything asserted about the product here is drawn from the codebase — the
 * commission maths comes out of lib/utils/pricing.dart and the verify-payment
 * edge function, not from marketing copy. Anything that would need real
 * business data we do not have (market size, traction, team, raise) is written
 * as a visibly-marked placeholder rather than invented.
 */
const pptxgen = require("pptxgenjs");
const path = require("path");

const ROOT = "C:/Users/USMAN/Desktop/Github projects/padi_learn";
const LOGO = path.join(ROOT, "assets/branding/icon_light.png");
const PHONE_MKT = path.join(ROOT, "video/out/deck/phone-marketplace.png");
const PHONE_LES = path.join(ROOT, "video/out/deck/phone-lesson.png");

// Brand palette, taken from lib/utils/colors.dart. Green dominates, ink is the
// dark ground for section breaks, amber is the single sharp accent.
const GREEN = "32936F";
const GREEN_DEEP = "236B50";
const INK = "0D1B2A";
const WHITE = "FFFFFF";
const PAPER = "F7F9F8";
const MIST = "E6F2ED";
const GREY = "6A7278";
const AMBER = "E8A33D";

const H = "Cambria";
const B = "Calibri";

const TITLE = { fontFace: H, fontSize: 40, bold: true, color: INK };
const SUB = { fontFace: B, fontSize: 15, color: GREY };
const BODY = { fontFace: B, fontSize: 14, color: INK };

/** Standard slide header. Returns the y to start content at. */
function header(slide, title, sub) {
  slide.addText(title, {
    x: 0.7, y: 0.4, w: 11.9, h: 0.85, isTextBox: true, ...TITLE,
  });
  if (sub) {
    slide.addText(sub, {
      x: 0.7, y: 1.28, w: 11.9, h: 0.42, isTextBox: true, ...SUB,
    });
    return 1.95;
  }
  return 1.55;
}

/** A numbered/iconic bullet: filled circle with a glyph, heading, body. */
function pointRow(slide, { x, y, w, glyph, heading, text, circle = GREEN }) {
  slide.addShape("ellipse", {
    x, y, w: 0.46, h: 0.46, fill: { color: circle },
  });
  slide.addText(glyph, {
    x, y, w: 0.46, h: 0.46, isTextBox: true, align: "center", valign: "middle",
    fontFace: B, fontSize: 17, bold: true, color: WHITE, margin: 0,
  });
  slide.addText(heading, {
    x: x + 0.68, y: y - 0.04, w: w - 0.68, h: 0.34, isTextBox: true, margin: 0,
    fontFace: B, fontSize: 15, bold: true, color: INK,
  });
  slide.addText(text, {
    x: x + 0.68, y: y + 0.3, w: w - 0.68, h: 0.95, isTextBox: true, margin: 0,
    fontFace: B, fontSize: 12.5, color: GREY, lineSpacingMultiple: 1.15,
  });
}

/** Soft card. No edge stripes — a tint plus a shadow. */
function card(slide, { x, y, w, h, fill = PAPER }) {
  slide.addShape("roundRect", {
    x, y, w, h, rectRadius: 0.1, fill: { color: fill },
    shadow: { type: "outer", color: "000000", blur: 10, offset: 2, angle: 90, opacity: 0.08 },
  });
}

function statBlock(slide, { x, y, w, value, label, color = GREEN }) {
  slide.addText(value, {
    x, y, w, h: 0.85, isTextBox: true, margin: 0,
    fontFace: H, fontSize: 46, bold: true, color,
  });
  slide.addText(label, {
    x, y: y + 0.85, w, h: 0.6, isTextBox: true, margin: 0,
    fontFace: B, fontSize: 12.5, color: GREY, lineSpacingMultiple: 1.1,
  });
}

/** Marks a slide whose numbers the founder must supply. */
function placeholderBadge(slide, x, y) {
  slide.addShape("roundRect", {
    x, y, w: 3.25, h: 0.34, rectRadius: 0.17, fill: { color: AMBER },
  });
  slide.addText("YOUR NUMBERS GO HERE", {
    x, y, w: 3.25, h: 0.34, isTextBox: true, align: "center", valign: "middle",
    margin: 0, fontFace: B, fontSize: 10.5, bold: true, color: INK,
  });
}

function titleSlide(pres, { kicker, title, tagline, footer }) {
  const s = pres.addSlide();
  s.background = { color: INK };
  s.addImage({ path: LOGO, x: 0.85, y: 1.5, w: 1.25, h: 1.25 });
  s.addText(kicker, {
    x: 0.85, y: 3.0, w: 9, h: 0.35, isTextBox: true, margin: 0,
    fontFace: B, fontSize: 13, bold: true, color: GREEN, charSpacing: 2,
  });
  s.addText(title, {
    x: 0.85, y: 3.42, w: 11, h: 1.15, isTextBox: true, margin: 0,
    fontFace: H, fontSize: 54, bold: true, color: WHITE,
  });
  s.addText(tagline, {
    x: 0.85, y: 4.72, w: 9.5, h: 0.85, isTextBox: true, margin: 0,
    fontFace: B, fontSize: 17, color: "B8C4CC", lineSpacingMultiple: 1.2,
  });
  s.addText(footer, {
    x: 0.85, y: 6.55, w: 11, h: 0.35, isTextBox: true, margin: 0,
    fontFace: B, fontSize: 11.5, color: "6B7A85",
  });
  return s;
}

// ===========================================================================
// DECK 1 — Product and differentiation
// ===========================================================================
function buildProductDeck() {
  const pres = new pptxgen();
  pres.layout = "LAYOUT_WIDE";
  pres.author = "PadiLearn";
  pres.title = "PadiLearn — Product & Differentiation";

  // --- 1. Title
  const t = titleSlide(pres, {
    kicker: "COURSE MARKETPLACE",
    title: "PadiLearn",
    tagline: "A learning marketplace built around how Nigeria actually buys,\npays and learns — not a global platform with naira bolted on.",
    footer: "Product and differentiation overview",
  });
  t.addNotes("Opening frame: this is not another Udemy clone. Every differentiator in this deck is a decision that only makes sense if you are building for this market specifically.");

  // --- 2. Problem
  {
    const s = pres.addSlide();
    const y = header(s, "Why another learning platform",
      "Three frictions that global platforms do not feel, and local sellers work around badly.");
    pointRow(s, {
      x: 0.7, y, w: 3.6, glyph: "1", heading: "Price points don't fit",
      text: "Global catalogues price in dollars. A ₦2,500 course is below the floor most platforms are built to handle — and that is the price the market actually bears.",
    });
    pointRow(s, {
      x: 4.75, y, w: 3.6, glyph: "2", heading: "Payment rails don't reach",
      text: "Card-first checkout and foreign payout rails exclude most Nigerian teachers. Getting paid is harder than getting students.",
    });
    pointRow(s, {
      x: 8.8, y, w: 3.8, glyph: "3", heading: "Data is expensive",
      text: "Streaming a course twice costs more than the course. Anything that assumes cheap, constant bandwidth quietly excludes the buyer.",
    });

    card(s, { x: 0.7, y: y + 2.05, w: 11.9, h: 2.1, fill: MIST });
    s.addText("So teachers sell courses over WhatsApp instead.", {
      x: 1.1, y: y + 2.35, w: 11.1, h: 0.4, isTextBox: true, margin: 0,
      fontFace: H, fontSize: 21, bold: true, color: GREEN_DEEP,
    });
    s.addText("It works — no fees, instant payment, a channel buyers already trust. What it cannot do is discovery, structured progress, refunds, or proof that a teacher is any good. That is the gap.",
      { x: 1.1, y: y + 2.9, w: 11.1, h: 0.9, isTextBox: true, margin: 0, ...BODY, fontSize: 13.5, color: INK });
    s.addNotes("The real competitor is not Udemy. It is a WhatsApp group and a bank transfer. Anything we build has to beat that on trust and discovery, because it will never beat it on fees.");
  }

  // --- 3. What it is
  {
    const s = pres.addSlide();
    header(s, "What PadiLearn is", "A two-sided marketplace. Anyone can learn; anyone can teach and be paid.");
    s.addImage({ path: PHONE_MKT, x: 0.9, y: 1.6, w: 2.5, h: 4.93 });
    const rows = [
      ["Learners", "Browse a categorised catalogue, pay in naira, and keep their place across sessions and devices."],
      ["Teachers", "Publish a course, upload lessons, set a price, and receive money into a Nigerian bank account."],
      ["The platform", "Takes a commission only when a sale settles. No listing fee, no subscription, no upfront cost to teach."],
    ];
    let y = 1.85;
    rows.forEach(([h1, t1], i) => {
      pointRow(s, { x: 4.3, y, w: 8.3, glyph: String(i + 1), heading: h1, text: t1 });
      y += 1.55;
    });
    s.addNotes("Keep this slide short. The interesting material is what follows — the decisions that make this different rather than the feature list, which any competitor could copy.");
  }

  // --- 4. Commission on net (the strongest differentiator)
  {
    const s = pres.addSlide();
    s.background = { color: INK };
    s.addText("We take our cut of what arrives, not what was charged", {
      x: 0.7, y: 0.45, w: 11.9, h: 0.75, isTextBox: true,
      fontFace: H, fontSize: 34, bold: true, color: WHITE,
    });
    s.addText("Almost every marketplace takes its percentage on the gross price. On low-value courses, where a flat processing fee dominates, that quietly overcharges the seller.",
      { x: 0.7, y: 1.25, w: 11.2, h: 0.6, isTextBox: true, fontFace: B, fontSize: 14, color: "AFBCC4" });

    // Two columns of maths on a ₦2,500 sale.
    const cols = [
      { x: 0.9, title: "Commission on gross", lines: ["Course price   ₦2,500", "Processing fee   −₦138", "Platform 15% of ₦2,500   −₦375", "", "Teacher receives   ₦1,987"], accent: "E5645E" },
      { x: 7.0, title: "Commission on net  (ours)", lines: ["Course price   ₦2,500", "Processing fee   −₦138", "Platform 15% of ₦2,362   −₦354", "", "Teacher receives   ₦2,008"], accent: GREEN },
    ];
    cols.forEach((c) => {
      s.addShape("roundRect", { x: c.x, y: 2.1, w: 5.4, h: 3.35, rectRadius: 0.1, fill: { color: "16293A" } });
      s.addText(c.title, {
        x: c.x + 0.35, y: 2.3, w: 4.7, h: 0.4, isTextBox: true, margin: 0,
        fontFace: B, fontSize: 14, bold: true, color: c.accent,
      });
      s.addText(c.lines.map((l) => ({ text: l, options: { breakLine: true } })), {
        x: c.x + 0.35, y: 2.78, w: 4.75, h: 2.4, isTextBox: true, margin: 0,
        fontFace: B, fontSize: 14, color: WHITE, lineSpacingMultiple: 1.35,
      });
    });

    s.addText("The gap widens as prices fall. On a ₦1,000 course, gross-basis commission costs the teacher roughly a fifth of their margin — which is exactly the price band this market lives in.",
      { x: 0.9, y: 5.75, w: 11.5, h: 0.8, isTextBox: true, fontFace: B, fontSize: 13.5, color: "AFBCC4", lineSpacingMultiple: 1.2 });
    s.addNotes("This is the differentiator to lead with in any teacher conversation. It is a real accounting decision, enforced server-side in the verify-payment function, and it is checkable.");
  }

  // --- 5. Fee dead zone (chart)
  {
    const s = pres.addSlide();
    header(s, "Teachers can't price themselves into a loss",
      "Nigerian card processing waives its flat fee below ₦2,500. Cross that line and earnings fall off a cliff.");
    const data = [{
      name: "Teacher earns",
      labels: ["₦2,300", "₦2,400", "₦2,499", "₦2,500", "₦2,600", "₦2,700", "₦2,800"],
      values: [1925, 2009, 2093, 2008, 2092, 2175, 2259],
    }];
    s.addChart(pres.ChartType.line, data, {
      x: 0.7, y: 1.95, w: 7.4, h: 4.2,
      showTitle: false, showLegend: false,
      chartColors: [GREEN], lineSize: 3, lineSmooth: false,
      showValue: true, dataLabelPosition: "t", dataLabelFontSize: 10,
      dataLabelColor: INK, dataLabelFormatCode: "#,##0",
      catAxisLabelColor: GREY, valAxisLabelColor: GREY,
      catAxisLabelFontSize: 11, valAxisLabelFontSize: 11,
      valAxisMinVal: 1850, valAxisMaxVal: 2350,
      valGridLine: { color: "E3E8E6", size: 1 },
      catGridLine: { style: "none" },
    });
    card(s, { x: 8.4, y: 1.95, w: 4.2, h: 2.1, fill: MIST });
    s.addText("Price it at ₦2,499 and the teacher earns ₦2,093.\nPrice it at ₦2,600 — ₦101 more — and they earn ₦2,092.", {
      x: 8.7, y: 2.2, w: 3.65, h: 1.6, isTextBox: true, margin: 0,
      fontFace: B, fontSize: 13.5, color: INK, lineSpacingMultiple: 1.25,
    });
    s.addText([
      { text: "No other course platform does this.", options: { bold: true, breakLine: true } },
      { text: "The course form calculates the split live and warns when a price lands in the dead zone, suggesting the better one. It costs us commission to tell them — which is the point.", options: {} },
    ], { x: 8.4, y: 4.3, w: 4.2, h: 1.9, isTextBox: true, fontFace: B, fontSize: 13, color: GREY, lineSpacingMultiple: 1.2 });
    s.addNotes("Numbers computed from lib/utils/pricing.dart against current Paystack local-card rates. The estimate mirrors the server-side split; the server remains authoritative.");
  }

  // --- 6. Built for the network
  {
    const s = pres.addSlide();
    const y = header(s, "Built for the network people actually have",
      "Assumptions about bandwidth are assumptions about who gets to use the product.");
    s.addImage({ path: PHONE_LES, x: 9.6, y: 1.55, w: 2.55, h: 5.03 });
    const items = [
      ["Courses cached on device", "The learner's course list is stored locally, so a cold start with no signal opens to their courses rather than a spinner or an error."],
      ["Resume to the second", "Playback position is written back while watching and restored on return — across sessions, and across devices."],
      ["Progress computed server-side", "Completion is derived from lesson records by a database trigger, so it cannot drift between what the app shows and what the platform believes."],
    ];
    let yy = y;
    items.forEach(([h1, t1], i) => {
      pointRow(s, { x: 0.7, y: yy, w: 8.5, glyph: String(i + 1), heading: h1, text: t1 });
      yy += 1.5;
    });
    s.addNotes("Offline is not a feature bullet here, it is a market-access decision. The same argument applies to why lesson files are kept small.");
  }

  // --- 7. Money
  {
    const s = pres.addSlide();
    const y = header(s, "Money that arrives, and can be trusted",
      "Payments and payouts are the part a marketplace cannot afford to get almost right.");
    const items = [
      ["Local rails, not cards alone", "Paystack checkout — cards, bank transfer, USSD — in naira, through a processor Nigerian buyers already recognise."],
      ["Payout names come from the bank", "A teacher enters their 10-digit NUBAN; the account name is resolved through the bank and never typed. Nigerian transfers are irreversible, so the name has to be verified, not asserted."],
      ["Enrolment is server-authoritative", "Access is granted by an edge function after the payment is verified with the processor — never by the app saying the payment succeeded."],
      ["Every sale reconstructable", "Each transaction stores the processing fee, the platform fee and the teacher's earning separately, and the three always sum to the amount paid."],
    ];
    let yy = y;
    items.forEach(([h1, t1], i) => {
      const col = i % 2, row = Math.floor(i / 2);
      pointRow(s, { x: 0.7 + col * 6.1, y: yy + row * 2.35, w: 5.6, glyph: String(i + 1), heading: h1, text: t1 });
    });
    s.addNotes("The payout verification detail matters more than it sounds: a mistyped account number that resolves to a real stranger's name is an unrecoverable loss in this market.");
  }

  // --- 8. Content protection + onboarding
  {
    const s = pres.addSlide();
    const y = header(s, "Two more things teachers and learners notice", null);

    card(s, { x: 0.7, y: y, w: 5.8, h: 4.5 });
    s.addShape("ellipse", { x: 1.1, y: y + 0.35, w: 0.55, h: 0.55, fill: { color: GREEN } });
    s.addText("A", { x: 1.1, y: y + 0.35, w: 0.55, h: 0.55, isTextBox: true, align: "center", valign: "middle", margin: 0, fontFace: B, fontSize: 18, bold: true, color: WHITE });
    s.addText("Course video is not public", { x: 1.85, y: y + 0.42, w: 4.4, h: 0.45, isTextBox: true, margin: 0, fontFace: B, fontSize: 17, bold: true, color: INK });
    s.addText("Lesson files live in a private bucket. The app never holds a permanent link — it asks the server for a short-lived signed URL each time, and only for a lesson the viewer is entitled to.\n\nFor a teacher deciding whether to put their livelihood on a platform, this is the question they ask first.",
      { x: 1.1, y: y + 1.15, w: 5.1, h: 2.5, isTextBox: true, margin: 0, fontFace: B, fontSize: 13, color: GREY, lineSpacingMultiple: 1.25 });

    card(s, { x: 6.8, y: y, w: 5.8, h: 4.5 });
    s.addShape("ellipse", { x: 7.2, y: y + 0.35, w: 0.55, h: 0.55, fill: { color: AMBER } });
    s.addText("B", { x: 7.2, y: y + 0.35, w: 0.55, h: 0.55, isTextBox: true, align: "center", valign: "middle", margin: 0, fontFace: B, fontSize: 18, bold: true, color: INK });
    s.addText("Signing up asks almost nothing", { x: 7.95, y: y + 0.42, w: 4.4, h: 0.45, isTextBox: true, margin: 0, fontFace: B, fontSize: 17, bold: true, color: INK });
    s.addText("Google and Apple sign-in, then one question: are you here to learn or to teach? Asked after the account exists, not before — so the form is a tap, not five fields and a decision.\n\nThe role is claimed once, server-side, and cannot be self-escalated afterwards.",
      { x: 7.2, y: y + 1.15, w: 5.1, h: 2.5, isTextBox: true, margin: 0, fontFace: B, fontSize: 13, color: GREY, lineSpacingMultiple: 1.25 });
    s.addNotes("The role question deliberately comes after identity, because no provider can supply it and asking it up front is friction before any value has been shown.");
  }

  // --- 9. Comparison
  {
    const s = pres.addSlide();
    header(s, "Where this sits", "Against the two things a Nigerian teacher is actually choosing between.");
    const rows = [
      [{ text: "", options: { fill: { color: INK } } },
       { text: "Global platforms", options: { bold: true, color: WHITE, fill: { color: INK } } },
       { text: "Selling over WhatsApp", options: { bold: true, color: WHITE, fill: { color: INK } } },
       { text: "PadiLearn", options: { bold: true, color: WHITE, fill: { color: GREEN } } }],
      ["Priced for ₦1,000–₦5,000 courses", "No", "Yes", "Yes"],
      ["Commission taken on net, not gross", "No", "n/a", "Yes"],
      ["Payout to a Nigerian bank account", "Rarely", "Direct", "Yes, name-verified"],
      ["Works on a poor connection", "Partly", "Yes", "Cached offline"],
      ["Discovery beyond your own contacts", "Yes", "No", "Yes"],
      ["Structured progress and completion", "Yes", "No", "Yes"],
      ["Content protected from resharing", "Yes", "No", "Signed URLs"],
    ].map((r, i) => i === 0 ? r : r.map((c, j) => ({
      text: c,
      options: { color: j === 3 ? GREEN_DEEP : INK, bold: j === 3, fill: { color: i % 2 ? WHITE : PAPER } },
    })));

    s.addTable(rows, {
      x: 0.7, y: 1.75, w: 11.9, colW: [4.4, 2.4, 2.4, 2.7],
      rowH: 0.56, fontFace: B, fontSize: 12.5, valign: "middle",
      border: { type: "solid", color: "E3E8E6", pt: 1 },
    });
    s.addNotes("Be honest in the room that global platforms beat us on catalogue depth and brand. We are not competing on those.");
  }

  // --- 10. Under the hood
  {
    const s = pres.addSlide();
    const y = header(s, "What is built", "A small stack, deliberately — one mobile codebase and a managed backend.");
    const items = [
      ["Flutter", "One codebase, Android and iOS."],
      ["Supabase", "Auth, Postgres, storage and edge functions. Row-level security enforces who may read and write what."],
      ["Paystack", "Checkout and payouts, driven from server-side functions so the client can never mark itself as paid."],
    ];
    let yy = y;
    items.forEach(([h1, t1], i) => {
      pointRow(s, { x: 0.7, y: yy, w: 5.7, glyph: String(i + 1), heading: h1, text: t1 });
      yy += 1.45;
    });
    card(s, { x: 6.9, y: y, w: 5.7, h: 4.3, fill: MIST });
    s.addText("Working today", { x: 7.3, y: y + 0.3, w: 4.9, h: 0.4, isTextBox: true, margin: 0, fontFace: B, fontSize: 15, bold: true, color: GREEN_DEEP });
    s.addText([
      "Catalogue, search and categories",
      "Paid enrolment end to end",
      "Lesson playback with resume",
      "Progress tracked and recomputed server-side",
      "Teacher publishing and lesson upload",
      "Payout account capture, bank-verified",
      "Course comments and teacher notifications",
      "Offline course list",
    ].map((t1, i, a) => ({ text: t1, options: { bullet: true, breakLine: i < a.length - 1 } })), {
      x: 7.3, y: y + 0.8, w: 4.9, h: 3.3, isTextBox: true, margin: 0,
      fontFace: B, fontSize: 12.5, color: INK, paraSpaceAfter: 6,
    });
    s.addNotes("Resist over-claiming here. Everything on this list is implemented; the honest gaps belong on the next slide.");
  }

  // --- 11. Honest status
  {
    const s = pres.addSlide();
    const y = header(s, "What is not done yet", "Worth saying out loud before someone finds it.");
    const items = [
      ["Pre-launch", "No real users and no revenue. The catalogue currently on the app is seeded demo content, and its instructor names and ratings are placeholders."],
      ["Payments tested, not proven", "The full paid flow works against the processor's test mode. It has not run at volume, and refunds and disputes are not built."],
      ["Nothing has been through a security review", "Access rules are written and enforced at the database, but no external audit has been done."],
      ["No content moderation", "There is no review step between a teacher publishing and a course appearing."],
    ];
    let yy = y;
    items.forEach(([h1, t1], i) => {
      const col = i % 2, row = Math.floor(i / 2);
      pointRow(s, { x: 0.7 + col * 6.1, y: yy + row * 2.35, w: 5.6, glyph: String(i + 1), heading: h1, text: t1, circle: AMBER });
    });
    s.addNotes("Including this slide is a choice. It buys credibility for every claim on the other slides, and everything on it is discoverable anyway.");
  }

  // --- 12. Close
  {
    const s = pres.addSlide();
    s.background = { color: GREEN };
    s.addImage({ path: LOGO, x: 5.9, y: 1.75, w: 1.5, h: 1.5 });
    s.addText("The bet", {
      x: 1, y: 3.5, w: 11.3, h: 0.55, isTextBox: true, align: "center",
      fontFace: B, fontSize: 14, bold: true, color: "CFE7DC", charSpacing: 2,
    });
    s.addText("A marketplace wins here by being cheaper to sell on\nand easier to get paid from — not by having more courses.", {
      x: 1, y: 4.05, w: 11.3, h: 1.3, isTextBox: true, align: "center",
      fontFace: H, fontSize: 27, bold: true, color: WHITE, lineSpacingMultiple: 1.2,
    });
    s.addText("padilearn", {
      x: 1, y: 6.3, w: 11.3, h: 0.4, isTextBox: true, align: "center",
      fontFace: B, fontSize: 13, color: "CFE7DC",
    });
  }

  return pres;
}

// ===========================================================================
// DECK 2 — Investor pitch
// ===========================================================================
function buildInvestorDeck() {
  const pres = new pptxgen();
  pres.layout = "LAYOUT_WIDE";
  pres.author = "PadiLearn";
  pres.title = "PadiLearn — Investor Pitch";

  const t = titleSlide(pres, {
    kicker: "INVESTOR PITCH",
    title: "PadiLearn",
    tagline: "The marketplace for Nigerian teachers who already have students —\nand no good way to charge them.",
    footer: "Amber blocks mark the slides where your own figures are required",
  });
  t.addNotes("This deck ships with placeholders on every slide that needs real data. Do not present it until those are filled — an investor will ask for exactly those numbers first.");

  // --- Problem
  {
    const s = pres.addSlide();
    const y = header(s, "The problem", "Nigeria has no shortage of people teaching. It has a shortage of ways to get paid for it.");
    const items = [
      ["Teaching already happens", "Exam prep, trades, software, tailoring — sold today through WhatsApp groups, in person, and by word of mouth."],
      ["Charging for it is the hard part", "Collecting payment means manual transfers and trust. Chasing it does not scale past a teacher's own contacts."],
      ["Global platforms do not fit", "Built for dollar price points and foreign payout rails. A ₦2,500 course is beneath the floor they are designed for."],
    ];
    let yy = y;
    items.forEach(([h1, t1], i) => {
      pointRow(s, { x: 0.7 + i * 4.05, y: yy, w: 3.7, glyph: String(i + 1), heading: h1, text: t1 });
    });
    card(s, { x: 0.7, y: y + 2.25, w: 11.9, h: 1.9, fill: MIST });
    s.addText("A teacher's ceiling is their contact list. We raise the ceiling and take a cut of the difference.", {
      x: 1.1, y: y + 2.65, w: 11.1, h: 1.1, isTextBox: true, margin: 0,
      fontFace: H, fontSize: 22, bold: true, color: GREEN_DEEP,
    });
  }

  // --- Solution
  {
    const s = pres.addSlide();
    header(s, "The solution", "A marketplace priced and plumbed for this market specifically.");
    s.addImage({ path: PHONE_MKT, x: 0.9, y: 1.6, w: 2.5, h: 4.93 });
    const items = [
      ["Sell without a storefront", "Publish a course, set a naira price, reach buyers beyond your own contacts."],
      ["Get paid into a Nigerian account", "Local checkout in, bank transfer out, account name verified with the bank."],
      ["Keep more of a small sale", "Commission is taken on what settles, not on the list price — which matters most at the low prices this market bears."],
    ];
    let y = 1.85;
    items.forEach(([h1, t1], i) => {
      pointRow(s, { x: 4.3, y, w: 8.3, glyph: String(i + 1), heading: h1, text: t1 });
      y += 1.55;
    });
  }

  // --- Market (placeholder)
  {
    const s = pres.addSlide();
    const y = header(s, "Market", "Sizing must come from sources you can defend in the room.");
    placeholderBadge(s, 0.7, y);
    card(s, { x: 0.7, y: y + 0.55, w: 11.9, h: 3.9 });
    s.addText("What belongs here", { x: 1.1, y: y + 0.8, w: 11.1, h: 0.4, isTextBox: true, margin: 0, fontFace: B, fontSize: 16, bold: true, color: INK });
    s.addText([
      "TAM — Nigerians paying for any form of paid learning today, with the source cited",
      "SAM — those reachable on a smartphone with a means of digital payment",
      "SOM — a defensible three-year share, built bottom-up from teachers onboarded × courses × average price",
      "Adjacent proof points — what the market already spends on exam prep, and on informal skills training",
    ].map((t1, i, a) => ({ text: t1, options: { bullet: true, breakLine: i < a.length - 1 } })), {
      x: 1.1, y: y + 1.3, w: 11.0, h: 2.5, isTextBox: true, margin: 0,
      fontFace: B, fontSize: 13.5, color: INK, paraSpaceAfter: 10,
    });
    s.addText("Build the bottom-up number first and lead with it. A large top-down TAM invites scepticism; a defensible bottom-up model invites the next question.",
      { x: 0.7, y: y + 4.7, w: 11.9, h: 0.6, isTextBox: true, fontFace: B, fontSize: 13, italic: true, color: GREY });
  }

  // --- Business model (real)
  {
    const s = pres.addSlide();
    s.background = { color: INK };
    s.addText("How we make money", { x: 0.7, y: 0.45, w: 11.9, h: 0.75, isTextBox: true, fontFace: H, fontSize: 36, bold: true, color: WHITE });
    s.addText("One revenue line today: commission on a completed sale. No listing fee, no subscription.",
      { x: 0.7, y: 1.2, w: 11.5, h: 0.5, isTextBox: true, fontFace: B, fontSize: 14, color: "AFBCC4" });

    const stats = [
      ["15%", "of the settled amount,\nafter processing fees"],
      ["₦0", "cost to a teacher to\nlist or publish"],
      ["100%", "of payouts to\nverified bank accounts"],
    ];
    stats.forEach(([v, l], i) => {
      const x = 0.9 + i * 4.05;
      s.addShape("roundRect", { x, y: 2.05, w: 3.6, h: 2.35, rectRadius: 0.1, fill: { color: "16293A" } });
      s.addText(v, { x: x + 0.3, y: 2.25, w: 3.0, h: 0.95, isTextBox: true, margin: 0, fontFace: H, fontSize: 46, bold: true, color: GREEN });
      s.addText(l, { x: x + 0.3, y: 3.25, w: 3.0, h: 1.0, isTextBox: true, margin: 0, fontFace: B, fontSize: 13, color: "AFBCC4", lineSpacingMultiple: 1.2 });
    });

    s.addText("On a ₦2,500 sale, ₦138 goes to processing, ₦354 to PadiLearn and ₦2,008 to the teacher. Every transaction stores the three parts separately, so the split is auditable per sale rather than reconstructed from an average.",
      { x: 0.9, y: 4.75, w: 11.5, h: 0.95, isTextBox: true, fontFace: B, fontSize: 14, color: "AFBCC4", lineSpacingMultiple: 1.25 });
    s.addText("Later lines — promoted placement, cohort courses, certification — are deliberately not in this model.",
      { x: 0.9, y: 5.8, w: 11.5, h: 0.5, isTextBox: true, fontFace: B, fontSize: 13, italic: true, color: "7E8D97" });
  }

  // --- Unit economics (placeholder)
  {
    const s = pres.addSlide();
    const y = header(s, "Unit economics", "The revenue side is known. The cost side is yours to fill.");
    card(s, { x: 0.7, y, w: 5.8, h: 4.4, fill: MIST });
    s.addText("Known", { x: 1.1, y: y + 0.3, w: 5.0, h: 0.4, isTextBox: true, margin: 0, fontFace: B, fontSize: 16, bold: true, color: GREEN_DEEP });
    s.addText([
      "Revenue per sale: 15% of settled amount",
      "Processing: 1.5%, plus ₦100 above ₦2,500, capped at ₦2,000",
      "Marginal hosting cost per enrolment is close to zero",
      "No cost of goods — teachers supply the content",
    ].map((t1, i, a) => ({ text: t1, options: { bullet: true, breakLine: i < a.length - 1 } })), {
      x: 1.1, y: y + 0.85, w: 5.0, h: 2.8, isTextBox: true, margin: 0, fontFace: B, fontSize: 13, color: INK, paraSpaceAfter: 8,
    });

    card(s, { x: 6.8, y, w: 5.8, h: 4.4 });
    placeholderBadge(s, 7.2, y + 0.28);
    s.addText([
      "CAC — per learner and per teacher, which will differ sharply",
      "Average order value, and repeat purchase rate",
      "Teacher retention — how many publish a second course",
      "Payback period, and LTV/CAC",
    ].map((t1, i, a) => ({ text: t1, options: { bullet: true, breakLine: i < a.length - 1 } })), {
      x: 7.2, y: y + 0.85, w: 5.0, h: 2.8, isTextBox: true, margin: 0, fontFace: B, fontSize: 13, color: INK, paraSpaceAfter: 8,
    });
    s.addText("Teacher acquisition is the number that decides this business. One teacher who brings their own students is worth many paid learner installs — if that holds, say so with evidence.",
      { x: 0.7, y: y + 4.6, w: 11.9, h: 0.7, isTextBox: true, fontFace: B, fontSize: 13, italic: true, color: GREY });
  }

  // --- Why us / moat
  {
    const s = pres.addSlide();
    const y = header(s, "Why this is defensible", "Not the features — those are copyable. The things that compound.");
    const items = [
      ["Teachers bring their own demand", "A teacher joining brings an existing audience. Acquisition cost falls as the teacher side grows, which a pure content library never gets."],
      ["Payment trust is slow to earn", "Verified payouts and a clean settlement record take time to build and are the first thing a teacher asks about."],
      ["Pricing intelligence", "Knowing what converts at each price band, in this market, is proprietary and accrues from day one."],
      ["Local-first is hard to retrofit", "Offline behaviour, low price points and naira rails are architectural. A global platform cannot bolt them on cheaply."],
    ];
    let yy = y;
    items.forEach(([h1, t1], i) => {
      const col = i % 2, row = Math.floor(i / 2);
      pointRow(s, { x: 0.7 + col * 6.1, y: yy + row * 2.35, w: 5.6, glyph: String(i + 1), heading: h1, text: t1 });
    });
  }

  // --- Traction (placeholder)
  {
    const s = pres.addSlide();
    const y = header(s, "Traction", "Currently pre-launch. This slide is the one investors read first.");
    placeholderBadge(s, 0.7, y);
    card(s, { x: 0.7, y: y + 0.55, w: 11.9, h: 3.7 });
    s.addText("Until there are numbers, show evidence instead", { x: 1.1, y: y + 0.8, w: 11.1, h: 0.4, isTextBox: true, margin: 0, fontFace: B, fontSize: 16, bold: true, color: INK });
    s.addText([
      "Teachers who have committed to publish at launch, by name and subject",
      "Letters of intent, or a waiting list with real sign-ups",
      "A pilot cohort: one teacher, one course, real money collected",
      "Pre-orders — the strongest possible signal before launch",
    ].map((t1, i, a) => ({ text: t1, options: { bullet: true, breakLine: i < a.length - 1 } })), {
      x: 1.1, y: y + 1.3, w: 11.0, h: 2.3, isTextBox: true, margin: 0, fontFace: B, fontSize: 13.5, color: INK, paraSpaceAfter: 10,
    });
    s.addText("One real teacher with ten paying students beats any projection. Get that before raising if you possibly can.",
      { x: 0.7, y: y + 4.5, w: 11.9, h: 0.6, isTextBox: true, fontFace: B, fontSize: 13, italic: true, color: GREY });
  }

  // --- Competition
  {
    const s = pres.addSlide();
    header(s, "Competition", "Honestly placed. We lose on catalogue and brand, and win on economics and reach.");
    const rows = [
      [{ text: "", options: { fill: { color: INK } } },
       { text: "Global platforms", options: { bold: true, color: WHITE, fill: { color: INK } } },
       { text: "Selling over WhatsApp", options: { bold: true, color: WHITE, fill: { color: INK } } },
       { text: "PadiLearn", options: { bold: true, color: WHITE, fill: { color: GREEN } } }],
      ["Catalogue depth", "Wins", "No", "Behind"],
      ["Brand recognition", "Wins", "n/a", "Behind"],
      ["Economics at ₦1,000–₦5,000", "No", "Wins", "Competitive"],
      ["Payout into a Nigerian bank", "Rarely", "Direct", "Yes, verified"],
      ["Discovery beyond own contacts", "Yes", "No", "Yes"],
      ["Works on a poor connection", "Partly", "Yes", "Cached offline"],
      ["Content protection", "Yes", "None", "Signed URLs"],
    ].map((r, i) => i === 0 ? r : r.map((c, j) => ({
      text: c,
      options: { color: j === 3 ? GREEN_DEEP : INK, bold: j === 3, fill: { color: i % 2 ? WHITE : PAPER } },
    })));
    s.addTable(rows, {
      x: 0.7, y: 1.75, w: 11.9, colW: [4.4, 2.4, 2.4, 2.7],
      rowH: 0.56, fontFace: B, fontSize: 12.5, valign: "middle",
      border: { type: "solid", color: "E3E8E6", pt: 1 },
    });
    s.addNotes("Saying plainly where you lose makes the columns where you win believable. Investors discount decks where every row is a win.");
  }

  // --- Roadmap
  {
    const s = pres.addSlide();
    const y = header(s, "Roadmap", "Sequenced by what removes the most risk, not by what is easiest.");
    const phases = [
      ["Now", "Pilot", "One teacher, one paid course, real money end to end. Proves the rails and the appetite together."],
      ["Next", "Teacher supply", "Recruit the first cohort. Teacher acquisition cost is the number that decides the model."],
      ["Then", "Payment breadth", "Refunds and disputes, automated payouts, and the reconciliation a real ledger needs."],
      ["Later", "Trust and scale", "Moderation, ratings that mean something, and a security review before volume."],
    ];
    phases.forEach(([when, what, why], i) => {
      const x = 0.7 + i * 3.05;
      s.addShape("ellipse", { x, y, w: 0.5, h: 0.5, fill: { color: i === 0 ? GREEN : MIST } });
      s.addText(String(i + 1), { x, y, w: 0.5, h: 0.5, isTextBox: true, align: "center", valign: "middle", margin: 0, fontFace: B, fontSize: 17, bold: true, color: i === 0 ? WHITE : GREEN_DEEP });
      s.addText(when, { x, y: y + 0.68, w: 2.8, h: 0.3, isTextBox: true, margin: 0, fontFace: B, fontSize: 11.5, bold: true, color: GREEN, charSpacing: 1.5 });
      s.addText(what, { x, y: y + 1.0, w: 2.8, h: 0.42, isTextBox: true, margin: 0, fontFace: B, fontSize: 16, bold: true, color: INK });
      s.addText(why, { x, y: y + 1.48, w: 2.8, h: 2.0, isTextBox: true, margin: 0, fontFace: B, fontSize: 12.5, color: GREY, lineSpacingMultiple: 1.2 });
    });
  }

  // --- Team + Ask (placeholder)
  {
    const s = pres.addSlide();
    const y = header(s, "Team and the ask", "Both need your real detail before this deck goes anywhere.");
    card(s, { x: 0.7, y, w: 5.8, h: 4.3, fill: MIST });
    s.addText("Team", { x: 1.1, y: y + 0.3, w: 5.0, h: 0.4, isTextBox: true, margin: 0, fontFace: B, fontSize: 17, bold: true, color: GREEN_DEEP });
    placeholderBadge(s, 1.1, y + 0.8);
    s.addText([
      "Who is building it, and what each person has shipped before",
      "Why this team for this market — distribution or teaching relationships count double",
      "Advisers, and any gaps you are hiring for",
    ].map((t1, i, a) => ({ text: t1, options: { bullet: true, breakLine: i < a.length - 1 } })), {
      x: 1.1, y: y + 1.35, w: 5.0, h: 2.2, isTextBox: true, margin: 0, fontFace: B, fontSize: 13, color: INK, paraSpaceAfter: 8,
    });

    card(s, { x: 6.8, y, w: 5.8, h: 4.3 });
    s.addText("The ask", { x: 7.2, y: y + 0.3, w: 5.0, h: 0.4, isTextBox: true, margin: 0, fontFace: B, fontSize: 17, bold: true, color: INK });
    placeholderBadge(s, 7.2, y + 0.8);
    s.addText([
      "Amount, and the runway it buys in months",
      "The split — teacher acquisition, engineering, compliance",
      "The milestone it reaches: the number that makes the next round obvious",
    ].map((t1, i, a) => ({ text: t1, options: { bullet: true, breakLine: i < a.length - 1 } })), {
      x: 7.2, y: y + 1.35, w: 5.0, h: 2.2, isTextBox: true, margin: 0, fontFace: B, fontSize: 13, color: INK, paraSpaceAfter: 8,
    });
    s.addText("Frame the raise as buying a specific proof, not a period of time. \"Enough to get 50 teachers earning\" lands better than \"18 months of runway\".",
      { x: 0.7, y: y + 4.5, w: 11.9, h: 0.6, isTextBox: true, fontFace: B, fontSize: 13, italic: true, color: GREY });
  }

  // --- Close
  {
    const s = pres.addSlide();
    s.background = { color: GREEN };
    s.addImage({ path: LOGO, x: 5.9, y: 1.7, w: 1.5, h: 1.5 });
    s.addText("PadiLearn", { x: 1, y: 3.45, w: 11.3, h: 0.8, isTextBox: true, align: "center", fontFace: H, fontSize: 44, bold: true, color: WHITE });
    s.addText("Your padi for learning.", { x: 1, y: 4.25, w: 11.3, h: 0.5, isTextBox: true, align: "center", fontFace: B, fontSize: 18, color: "CFE7DC" });
    s.addText("Contact details here", { x: 1, y: 6.2, w: 11.3, h: 0.4, isTextBox: true, align: "center", fontFace: B, fontSize: 13, color: "CFE7DC" });
  }

  return pres;
}

(async () => {
  const fs = require("fs");
  const outDir = path.join(ROOT, "docs", "decks");
  fs.mkdirSync(outDir, { recursive: true });
  const jobs = [
    ["PadiLearn-Product-and-Differentiation.pptx", buildProductDeck()],
    ["PadiLearn-Investor-Pitch.pptx", buildInvestorDeck()],
  ];
  for (const [name, deck] of jobs) {
    // Write beside the script first: pptxgenjs has been unreliable writing
    // straight to a path containing spaces on Windows.
    await deck.writeFile({ fileName: name });
    fs.copyFileSync(name, path.join(outDir, name));
    console.log("wrote", name, fs.statSync(name).size, "bytes");
  }
  console.log("copied to", outDir);
})().catch((e) => { console.error("FAILED:", e); process.exit(1); });
