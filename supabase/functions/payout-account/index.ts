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

async function paystack(path: string, key: string) {
  const res = await fetch(`https://api.paystack.co${path}`, {
    headers: { Authorization: `Bearer ${key}` },
  });
  return await res.json();
}

/// Owns everything about a teacher's payout destination:
///
///   { action: "banks" }                                  -> the bank list
///   { action: "resolve", bankCode, accountNumber }       -> the account name
///   { action: "save",    bankCode, accountNumber }       -> verify then store
///
/// Saving goes through here rather than straight to the table so the stored
/// `account_name` provably came from the bank. Nigerian transfers are
/// irreversible; a typo'd digit must not silently become a stranger's account.
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const paystackKey = Deno.env.get("PAYSTACK_SECRET_KEY");
    if (!paystackKey) {
      return json({ error: "Payouts are not configured yet." }, 500);
    }

    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const jwt = (req.headers.get("Authorization") ?? "").replace("Bearer ", "");
    const { data: userData, error: userErr } = await admin.auth.getUser(jwt);
    if (userErr || !userData?.user) return json({ error: "Unauthorized" }, 401);
    const user = userData.user;

    const body = await req.json();
    const action = body?.action;

    // --- Bank list ---------------------------------------------------------
    if (action === "banks") {
      const data = await paystack("/bank?country=nigeria&perPage=200", paystackKey);
      if (!data.status) {
        return json({ error: data.message ?? "Could not load banks." }, 502);
      }
      // Trimmed to what the picker needs, and de-duplicated: Paystack lists
      // some institutions more than once under different channels.
      const seen = new Set<string>();
      const banks = (data.data ?? [])
        .filter((b: { code?: string }) => {
          if (!b.code || seen.has(b.code)) return false;
          seen.add(b.code);
          return true;
        })
        .map((b: { name: string; code: string }) => ({
          name: b.name,
          code: b.code,
        }))
        .sort((a: { name: string }, b: { name: string }) =>
          a.name.localeCompare(b.name)
        );

      return json({ banks });
    }

    // --- Resolve / save ----------------------------------------------------
    if (action !== "resolve" && action !== "save") {
      return json({ error: "Unknown action" }, 400);
    }

    const bankCode = String(body?.bankCode ?? "").trim();
    const accountNumber = String(body?.accountNumber ?? "").trim();

    if (!/^[0-9]{10}$/.test(accountNumber)) {
      return json({ error: "Account number must be 10 digits." }, 400);
    }
    if (!bankCode) return json({ error: "Please choose a bank." }, 400);

    const resolved = await paystack(
      `/bank/resolve?account_number=${encodeURIComponent(accountNumber)}` +
        `&bank_code=${encodeURIComponent(bankCode)}`,
      paystackKey,
    );

    if (!resolved.status || !resolved.data?.account_name) {
      // Paystack's own message is the useful one here ("Could not resolve
      // account name. Check parameters or try again.").
      return json(
        { error: resolved.message ?? "Could not verify that account." },
        422,
      );
    }

    const accountName = String(resolved.data.account_name);

    if (action === "resolve") {
      return json({ account_name: accountName });
    }

    // Bank name is looked up rather than trusted from the client, so the
    // stored record is internally consistent.
    const bankList = await paystack("/bank?country=nigeria&perPage=200", paystackKey);
    const bank = (bankList.data ?? []).find(
      (b: { code?: string }) => b.code === bankCode,
    );

    const { error: saveErr } = await admin.from("payout_accounts").upsert(
      {
        user_id: user.id,
        bank_code: bankCode,
        bank_name: bank?.name ?? "Unknown bank",
        account_number: accountNumber,
        account_name: accountName,
        verified_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
        // Changing the destination invalidates any existing Paystack
        // recipient; it is recreated when payouts are automated.
        recipient_code: null,
      },
      { onConflict: "user_id" },
    );

    if (saveErr) return json({ error: saveErr.message }, 500);

    return json({
      saved: true,
      account_name: accountName,
      bank_name: bank?.name ?? "Unknown bank",
    });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
