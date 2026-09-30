// Paystack tells us a payment succeeded, whether or not the buyer's app is
// still alive to ask.
//
// Without this, the money and the entitlement are joined only by the device
// that happened to be holding the checkout screen: if the app is killed, the
// network drops or the phone dies between paying and calling `verify-payment`,
// Paystack keeps the money and the student never gets the course. The webhook
// closes that window — Paystack retries delivery for days, so fulfilment no
// longer depends on one fragile moment on one handset.
//
// This function is PUBLIC. Paystack has no Supabase JWT, so it must be
// deployed with JWT verification OFF:
//
//   supabase functions deploy paystack-webhook --no-verify-jwt
//
// Authentication is therefore entirely the signature check below. Deploying it
// *with* JWT verification silently breaks every delivery; deploying it without
// the signature check would let anyone grant themselves a course.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import {
  adminClient,
  fetchTransaction,
  grantEntitlement,
} from "../_shared/paystack.ts";

/// Paystack signs the raw request body with HMAC SHA-512 keyed on the secret
/// key. Proving we hold that key is what makes the payload trustworthy.
async function signatureMatches(rawBody: string, header: string | null) {
  if (!header) return false;
  const secret = Deno.env.get("PAYSTACK_SECRET_KEY");
  if (!secret) return false;

  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    enc.encode(secret),
    { name: "HMAC", hash: "SHA-512" },
    false,
    ["sign"],
  );
  const mac = await crypto.subtle.sign("HMAC", key, enc.encode(rawBody));
  const expected = [...new Uint8Array(mac)]
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");

  // Constant-time comparison: a plain `===` leaks how much of the signature
  // was correct through timing, which is enough to forge one byte at a time.
  if (expected.length !== header.length) return false;
  let diff = 0;
  for (let i = 0; i < expected.length; i++) {
    diff |= expected.charCodeAt(i) ^ header.charCodeAt(i);
  }
  return diff === 0;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  // Must be read as raw text: re-serialising the parsed JSON would reorder or
  // reformat it and the signature would never match.
  const rawBody = await req.text();

  if (!await signatureMatches(rawBody, req.headers.get("x-paystack-signature"))) {
    // Deliberately terse. An attacker probing this endpoint learns nothing
    // about why they failed.
    return new Response("Invalid signature", { status: 401 });
  }

  let event: Record<string, any>;
  try {
    event = JSON.parse(rawBody);
  } catch {
    return new Response("Malformed payload", { status: 400 });
  }

  // Paystack sends many event types down one endpoint. Anything else is
  // acknowledged so it is not retried forever.
  if (event.event !== "charge.success") {
    return new Response("Ignored", { status: 200 });
  }

  const reference = event.data?.reference;
  if (!reference) return new Response("No reference", { status: 200 });

  try {
    // Re-asking Paystack rather than trusting the payload's own numbers keeps
    // this path byte-identical to `verify-payment`, and means a replayed old
    // delivery is checked against current reality.
    const tx = await fetchTransaction(reference);
    if (!tx.ok) {
      // Signed, but not a successful charge on Paystack's side. Nothing to do
      // and nothing to retry.
      return new Response("Not a successful transaction", { status: 200 });
    }

    const result = await grantEntitlement(adminClient(), tx.data);
    if (result.ok) return new Response("OK", { status: 200 });

    // A 500 asks Paystack to deliver again later; a 200 closes the matter.
    // Retrying a missing course or absent metadata would never succeed.
    console.error(
      `paystack-webhook: ${reference} failed (retry=${result.retry}): ${result.message}`,
    );
    return new Response(result.message, { status: result.retry ? 500 : 200 });
  } catch (e) {
    // Network trouble reaching Paystack, or a missing secret. Worth retrying.
    console.error(`paystack-webhook: ${reference} errored: ${String(e)}`);
    return new Response("Temporary failure", { status: 500 });
  }
});
