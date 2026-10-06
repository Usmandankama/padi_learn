// Shared between `verify-payment` (the buyer's device asks) and
// `paystack-webhook` (Paystack tells us). Both end in the same place: a ledger
// row and an enrolment. Keeping that in one file is not tidiness — the fee
// split below is easy to get subtly wrong, and two drifting copies would mean
// the amount a teacher earns depends on which path happened to run first.
import { createClient, type SupabaseClient } from "jsr:@supabase/supabase-js@2";

export type Fulfilment =
  | { ok: true }
  // `retry` separates "try again later" (a database blip, worth another
  // delivery attempt) from "this will never work" (metadata missing, course
  // deleted), so the webhook can ask Paystack to resend only when resending
  // could actually help.
  | { ok: false; message: string; retry: boolean };


// Paystack local-card pricing. VERIFY AGAINST CURRENT PAYSTACK RATES.
// Mirrors the constants in `lib/utils/pricing.dart` — change both together.
const PAYSTACK_PERCENT = 0.015;
const PAYSTACK_FLAT_FEE = 100;
const PAYSTACK_FLAT_FEE_WAIVED_BELOW = 2500;
const PAYSTACK_FEE_CAP = 2000;

/// What a student must be charged for `listPrice` to settle in full.
///
/// The card fee is fronted to the customer: a teacher's price is what settles,
/// and Paystack's cut is added on top. Because that fee is a percentage of the
/// amount *charged*, adding it grows it, so this solves for the total rather
/// than adding a fee to the price and landing short.
///
/// Must agree exactly with `customerTotalFor` in `lib/utils/pricing.dart`:
/// `initialize-payment` charges this and `grantEntitlement` rejects anything
/// under it, so a discrepancy between the two would reject genuine payments.
export function customerTotalNaira(listPrice: number): number {
  if (listPrice <= 0) return 0;

  // Each branch assumes a fee regime, then only accepts its answer if the
  // regime still holds at that total. Rounding up can nudge a total across
  // Paystack's threshold, which would re-introduce the flat fee and underpay
  // the teacher, so the check comes after the rounding.
  const waived = Math.ceil(listPrice / (1 - PAYSTACK_PERCENT));
  if (waived < PAYSTACK_FLAT_FEE_WAIVED_BELOW) return waived;

  const withFlat = Math.ceil(
    (listPrice + PAYSTACK_FLAT_FEE) / (1 - PAYSTACK_PERCENT),
  );
  if (withFlat * PAYSTACK_PERCENT + PAYSTACK_FLAT_FEE <= PAYSTACK_FEE_CAP) {
    return withFlat;
  }

  // Past the cap the fee stops growing, so it is simply added on.
  return Math.ceil(listPrice + PAYSTACK_FEE_CAP);
}
export function adminClient(): SupabaseClient {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
}

/// Asks Paystack what really happened, rather than trusting anything the
/// caller said. Used by both entry points so the two always read identical
/// numbers — a webhook payload and a verify response are not quite the same
/// shape, and `fees` in particular is not always present on the former.
export async function fetchTransaction(reference: string) {
  const key = Deno.env.get("PAYSTACK_SECRET_KEY");
  if (!key) throw new Error("Missing PAYSTACK_SECRET_KEY.");

  const res = await fetch(
    `https://api.paystack.co/transaction/verify/${encodeURIComponent(reference)}`,
    { headers: { Authorization: `Bearer ${key}` } },
  );
  const body = await res.json();
  return { ok: Boolean(body.status) && body.data?.status === "success", data: body.data };
}

/// Records the money and grants access, in that order.
///
/// Both writes are idempotent — keyed on the Paystack reference and on
/// (user, course) — so running this twice for the same payment is harmless.
/// That is what makes it safe for the app and the webhook to race.
export async function grantEntitlement(
  admin: SupabaseClient,
  tx: Record<string, any>,
): Promise<Fulfilment> {
  const meta = tx.metadata ?? {};
  const courseId = meta.course_id;
  const payerId = meta.user_id;
  if (!courseId || !payerId) {
    return { ok: false, message: "Missing payment metadata.", retry: false };
  }

  const { data: course, error: courseErr } = await admin
    .from("courses")
    .select("id, title, thumbnail_url, price, user_id")
    .eq("id", courseId)
    .maybeSingle();
  if (courseErr) return { ok: false, message: courseErr.message, retry: true };
  if (!course) return { ok: false, message: "Course not found.", retry: false };

  // Guard against amount/currency tampering. The expected figure is the
  // grossed-up total the student owes, not the list price — they carry the
  // card fee, so a payment of exactly the list price is short.
  const expectedKobo = Math.round(
    customerTotalNaira(Number(course.price ?? 0)) * 100,
  );
  const amountKobo = Number(tx.amount);
  if (amountKobo < expectedKobo) {
    return { ok: false, message: "Amount paid is less than the amount due.", retry: false };
  }
  if (tx.currency && tx.currency !== "NGN") {
    return { ok: false, message: "Unexpected payment currency.", retry: false };
  }

  // Paystack deducts its fee before settlement. Because the student was
  // charged a grossed-up total, what arrives *is* the teacher's list price,
  // so the platform's 15% is 15% of the price they actually set.
  //
  // It is still taken from the real settled figure rather than recomputed
  // from the list price: if Paystack's true fee ever differs from the
  // estimate above, the split follows the money instead of an assumption.
  //
  // The three parts always reconstruct the total:
  //   amount = paystack_fee + platform_fee + teacher_earning
  const paystackFeeKobo = Number(tx.fees ?? 0) || 0;
  const netKobo = Math.max(0, amountKobo - paystackFeeKobo);

  // Defaults to the agreed 15% so a missing secret cannot silently hand over
  // 100% of every sale. Override per-environment if it ever changes; past
  // rows keep whatever split they were written with.
  const feePercent = Math.min(
    100,
    Math.max(0, Number(Deno.env.get("PLATFORM_FEE_PERCENT") ?? "15") || 0),
  );
  const platformFeeKobo = Math.round((netKobo * feePercent) / 100);

  // Recorded before the entitlement, so a retry can never grant access
  // without leaving a financial record.
  const { error: ledgerErr } = await admin.from("transactions").upsert(
    {
      reference: tx.reference,
      buyer_id: payerId,
      teacher_id: course.user_id,
      course_id: course.id,
      // Denormalised so the record still reads correctly if the course is
      // later deleted.
      course_title: course.title,
      amount_kobo: amountKobo,
      currency: tx.currency ?? "NGN",
      paystack_fee_kobo: paystackFeeKobo,
      platform_fee_kobo: platformFeeKobo,
      teacher_earning_kobo: netKobo - platformFeeKobo,
      status: "success",
      channel: tx.channel ?? null,
      paid_at: tx.paid_at ?? null,
    },
    { onConflict: "reference", ignoreDuplicates: true },
  );
  if (ledgerErr) return { ok: false, message: ledgerErr.message, retry: true };

  // Idempotent enrollment (the DB trigger bumps the course's enrollment count).
  // The enrollment row itself is the entitlement: `get-course-video` checks
  // for it before signing a playback URL, so no media link is stored here.
  const { error: enrollErr } = await admin.from("enrollments").upsert(
    {
      user_id: payerId,
      course_id: courseId,
      title: course.title,
      image: course.thumbnail_url,
      progress: 0,
      is_free: false,
    },
    { onConflict: "user_id,course_id", ignoreDuplicates: true },
  );
  if (enrollErr) return { ok: false, message: enrollErr.message, retry: true };

  return { ok: true };
}
