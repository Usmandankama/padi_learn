import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { platformFeePercent, splitFor } from "../_shared/paystack.ts";

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
      return json(
        { error: "Payment is not configured. Missing PAYSTACK_SECRET_KEY." },
        500,
      );
    }

    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // Identify the caller from their JWT.
    const jwt = (req.headers.get("Authorization") ?? "").replace("Bearer ", "");
    const { data: userData, error: userErr } = await admin.auth.getUser(jwt);
    if (userErr || !userData?.user) return json({ error: "Unauthorized" }, 401);
    const user = userData.user;

    const { courseId, callbackUrl } = await req.json();
    if (!courseId) return json({ error: "courseId is required" }, 400);

    // Authoritative price comes from the DB, never the client.
    const { data: course, error: courseErr } = await admin
      .from("courses")
      .select("id, title, price, user_id, archived_at, removed_at, published_at")
      .eq("id", courseId)
      .maybeSingle();
    if (courseErr || !course) return json({ error: "Course not found" }, 404);

    // A draft is not for sale to anyone, its owner included: to a buyer it
    // does not exist. Needs the column from 20261010000001_course_drafts.sql,
    // so deploy this after that has run.
    if (course.published_at === null) {
      return json({ error: "Course not found" }, 404);
    }

    // The service role sees courses RLS hides, so an archived or taken-down
    // course would still sell to anyone holding its id. Refuse both before
    // Paystack is involved.
    if (course.archived_at || course.removed_at) {
      return json({ error: "This course is no longer available." }, 410);
    }

    // Same reason, for suspensions: a suspended buyer cannot buy, and a
    // suspended teacher's courses are off sale.
    const { data: suspensions, error: suspensionErr } = await admin
      .from("suspensions")
      .select("user_id")
      .in("user_id", [user.id, course.user_id]);
    if (suspensionErr) {
      return json({ error: "Could not check this purchase." }, 500);
    }
    if ((suspensions ?? []).some((s) => s.user_id === user.id)) {
      return json({
        error: "Your account is suspended. Email hello@padilearn.com to appeal.",
      }, 403);
    }
    if ((suspensions ?? []).length > 0) {
      return json({ error: "This course is no longer available." }, 410);
    }

    const price = Number(course.price ?? 0);
    if (price <= 0) return json({ error: "This course is free." }, 400);

    // Where the teacher's share goes. A house course settles wholly to
    // PadiLearn; anyone else's is split to their Paystack subaccount, and
    // cannot be sold until they have one.
    const { data: terms, error: termsErr } = await admin.rpc("checkout_terms", {
      p_teacher_id: course.user_id,
    });
    if (termsErr || !terms) {
      return json({ error: "Could not check this purchase." }, 500);
    }
    const subaccountCode = terms.house ? null : terms.subaccount_code;
    if (!terms.house && !subaccountCode) {
      return json({
        error: "This teacher hasn't finished setting up payouts, so the " +
          "course can't be bought yet. Please try again later.",
      }, 409);
    }

    // The student covers Paystack's fee, so the charge is grossed up and the
    // teacher's list price settles in full. `grantEntitlement` re-derives the
    // total identically and rejects anything short, so the two must never
    // diverge.
    const split = splitFor(
      price,
      Number(terms.debt_kobo ?? 0),
      platformFeePercent(),
    );

    // Only split when the teacher has something to receive: a sale that goes
    // entirely to repaying their debt settles to PadiLearn like a house sale.
    const splitParams = subaccountCode && split.subaccountKobo > 0
      ? {
        subaccount: subaccountCode,
        transaction_charge: split.transactionChargeKobo,
        // PadiLearn's account pays Paystack's fee, out of what the student
        // paid on top, so the teacher's share arrives whole.
        bearer: "account",
      }
      : {};

    const initRes = await fetch("https://api.paystack.co/transaction/initialize", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${paystackKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        email: user.email,
        amount: split.chargeKobo,
        currency: "NGN",
        // Every current client sends this URL. The fallback matches it, so an
        // older client still lands on the app's callback route, which
        // verifies the payment, and not on the marketing site.
        callback_url: callbackUrl ?? "https://app.padilearn.com/payment-callback",
        ...splitParams,
        metadata: {
          user_id: user.id,
          course_id: course.id,
          course_title: course.title,
          // Recorded so support can see what was added on top, and why.
          list_price_kobo: Math.round(price * 100),
          card_fee_kobo: split.chargeKobo - Math.round(price * 100),
          // The split as decided here; `grantEntitlement` records the
          // teacher's share from it.
          teacher_share_kobo: split.teacherShareKobo,
          recover_kobo: split.recoverKobo,
          transaction_charge_kobo: "subaccount" in splitParams
            ? split.transactionChargeKobo
            : split.chargeKobo,
        },
      }),
    });

    const initData = await initRes.json();
    if (!initData.status) {
      return json(
        { error: initData.message ?? "Failed to initialize payment" },
        502,
      );
    }

    return json({
      authorization_url: initData.data.authorization_url,
      access_code: initData.data.access_code,
      reference: initData.data.reference,
    });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
