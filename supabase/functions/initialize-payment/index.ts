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
      .select("id, title, price")
      .eq("id", courseId)
      .maybeSingle();
    if (courseErr || !course) return json({ error: "Course not found" }, 404);

    const price = Number(course.price ?? 0);
    if (price <= 0) return json({ error: "This course is free." }, 400);

    const initRes = await fetch("https://api.paystack.co/transaction/initialize", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${paystackKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        email: user.email,
        amount: Math.round(price * 100), // NGN -> kobo
        currency: "NGN",
        callback_url: callbackUrl ?? "https://padilearn.com/payment-callback",
        metadata: {
          user_id: user.id,
          course_id: course.id,
          course_title: course.title,
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
