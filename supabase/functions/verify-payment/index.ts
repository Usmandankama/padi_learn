// The buyer's device asks whether its payment went through, and gets the
// course if it did.
//
// This is the fast path: it runs while the student is still looking at the
// screen, so they see the course unlock immediately. It is no longer the
// *only* path — `paystack-webhook` performs the same fulfilment from
// Paystack's side, for the times this call never happens because the app was
// killed or the network dropped. Both are idempotent and may run in either
// order, or both at once.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import {
  adminClient,
  fetchTransaction,
  grantEntitlement,
} from "../_shared/paystack.ts";

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
    const admin = adminClient();

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

    const tx = await fetchTransaction(reference);
    if (!tx.ok) {
      return json({ success: false, message: "Payment was not successful." });
    }

    // The verified payer must match the caller. Checked here and not in the
    // shared module because the webhook has no caller to compare against —
    // Paystack's signature is what vouches for that path.
    const payerId = tx.data?.metadata?.user_id;
    if (payerId && payerId !== user.id) {
      return json(
        { success: false, message: "Payment does not belong to this user." },
        403,
      );
    }

    const result = await grantEntitlement(admin, tx.data);
    if (result.ok) return json({ success: true });
    return json({ success: false, message: result.message }, result.retry ? 500 : 200);
  } catch (e) {
    return json({ success: false, message: String(e) }, 500);
  }
});
