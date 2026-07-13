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
      .select("id, title, thumbnail_url, video_url, price")
      .eq("id", courseId)
      .maybeSingle();
    if (!course) return json({ success: false, message: "Course not found." }, 404);

    // Guard against amount tampering.
    const expectedKobo = Math.round(Number(course.price ?? 0) * 100);
    if (Number(vData.data.amount) < expectedKobo) {
      return json({
        success: false,
        message: "Amount paid is less than the course price.",
      });
    }

    // Idempotent enrollment (the DB trigger bumps the course's enrollment count).
    const { error: enrollErr } = await admin.from("enrollments").upsert(
      {
        user_id: payerId,
        course_id: courseId,
        title: course.title,
        image: course.thumbnail_url,
        video_url: course.video_url,
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
