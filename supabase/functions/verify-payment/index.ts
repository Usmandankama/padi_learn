import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const paystackKey = Deno.env.get("PAYSTACK_SECRET_KEY");
    if (!paystackKey) {
      return json({ success: false, message: "Missing PAYSTACK_SECRET_KEY." }, 500);
    }

    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const jwt = (req.headers.get("Authorization") ?? "").replace("Bearer ", "");
    const { data: userData, error: userErr } = await admin.auth.getUser(jwt);
    if (userErr || !userData?.user) {
      return json({ success: false, message: "Unauthorized" }, 401);
    }
    const user = userData.user;

    const { reference } = await req.json();
    if (!reference) {
      return json({ success: false, message: "reference is required" }, 400);
    }

    // Verify the transaction with Paystack.
    const vRes = await fetch(
      `https://api.paystack.co/transaction/verify/${encodeURIComponent(reference)}`,
      { headers: { Authorization: `Bearer ${paystackKey}` } },
    );
    const vData = await vRes.json();
    if (!vData.status || vData.data?.status !== "success") {
      return json({ success: false, message: "Payment was not successful." });
    }

    const meta = vData.data.metadata ?? {};
    const courseId = meta.course_id;
    const payerId = meta.user_id;
    if (!courseId || !payerId) {
      return json({ success: false, message: "Missing payment metadata." });
    }
    // The verified payer must match the caller.
    if (payerId !== user.id) {
      return json(
        { success: false, message: "Payment does not belong to this user." },
        403,
      );
    }

    const { data: course } = await admin
      .from("courses")
      .select("id, title, thumbnail_url, price, user_id")
      .eq("id", courseId)
      .maybeSingle();
    if (!course) return json({ success: false, message: "Course not found." }, 404);

    // Guard against amount/currency tampering.
    const expectedKobo = Math.round(Number(course.price ?? 0) * 100);
    if (Number(vData.data.amount) < expectedKobo) {
      return json({
        success: false,
        message: "Amount paid is less than the course price.",
      });
    }
    if (vData.data.currency && vData.data.currency !== "NGN") {
      return json({ success: false, message: "Unexpected payment currency." });
    }

    // --- Ledger ------------------------------------------------------------
    // Recorded before the entitlement, so a retry can never grant access
    // without leaving a financial record. Both writes are idempotent, keyed on
    // the Paystack reference and (user, course) respectively.
    const amountKobo = Number(vData.data.amount);

    // Paystack deducts its fee before settlement, so it is recorded and the
    // platform's commission is taken on what actually *arrives*, not on the
    // list price. Taking 15% of gross would mean paying out more than was
    // received on low-priced courses, where the flat fee dominates.
    //
    // The three parts always reconstruct the total:
    //   amount = paystack_fee + platform_fee + teacher_earning
    const paystackFeeKobo = Number(vData.data.fees ?? 0) || 0;
    const netKobo = Math.max(0, amountKobo - paystackFeeKobo);

    // Defaults to the agreed 15% so a missing secret cannot silently hand over
    // 100% of every sale. Override per-environment if it ever changes; past
    // rows keep whatever split they were written with.
    const feePercent = Math.min(
      100,
      Math.max(0, Number(Deno.env.get("PLATFORM_FEE_PERCENT") ?? "15") || 0),
    );
    const platformFeeKobo = Math.round((netKobo * feePercent) / 100);

    const { error: ledgerErr } = await admin.from("transactions").upsert(
      {
        reference,
        buyer_id: payerId,
        teacher_id: course.user_id,
        course_id: course.id,
        // Denormalised so the record still reads correctly if the course is
        // later deleted.
        course_title: course.title,
        amount_kobo: amountKobo,
        currency: vData.data.currency ?? "NGN",
        paystack_fee_kobo: paystackFeeKobo,
        platform_fee_kobo: platformFeeKobo,
        teacher_earning_kobo: netKobo - platformFeeKobo,
        status: "success",
        channel: vData.data.channel ?? null,
        paid_at: vData.data.paid_at ?? null,
      },
      { onConflict: "reference", ignoreDuplicates: true },
    );
    if (ledgerErr) {
      return json({ success: false, message: ledgerErr.message }, 500);
    }

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
    if (enrollErr) return json({ success: false, message: enrollErr.message }, 500);

    return json({ success: true });
  } catch (e) {
    return json({ success: false, message: String(e) }, 500);
  }
});
