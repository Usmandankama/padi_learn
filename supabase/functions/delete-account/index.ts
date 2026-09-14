import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient, SupabaseClient } from "jsr:@supabase/supabase-js@2";

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

/// Buckets that hold per-user files. Every upload path starts with the
/// owner's id (`<uid>/avatar.jpg`, `<uid>/videos/...`, `<uid>/thumbnails/...`)
/// because that prefix is what the storage policies check.
const USER_BUCKETS = ["profile-images", "course-media", "course-thumbnails"];

/// Every object key under `prefix`, walking folders. `list` is one level deep
/// and paged, and a folder comes back as an entry with a null id.
async function listAll(
  admin: SupabaseClient,
  bucket: string,
  prefix: string,
): Promise<string[]> {
  const keys: string[] = [];
  const pageSize = 1000;
  for (let offset = 0;; offset += pageSize) {
    const { data, error } = await admin.storage.from(bucket).list(prefix, {
      limit: pageSize,
      offset,
    });
    if (error) throw new Error(`list ${bucket}/${prefix}: ${error.message}`);
    for (const entry of data ?? []) {
      const path = `${prefix}/${entry.name}`;
      if (entry.id === null) {
        keys.push(...await listAll(admin, bucket, path));
      } else {
        keys.push(path);
      }
    }
    if (!data || data.length < pageSize) break;
  }
  return keys;
}

/// Deletes the caller's account, in the order that fails safe:
///
///   1. Refuse if other people paid for this user's courses.
///   2. Remove the user's files from storage.
///   3. Delete the auth user, which cascades through the database.
///
/// Files go before the user because storage removal is idempotent and the
/// user can simply retry. The other way round, a failure after the user is
/// gone leaves personal files nobody can ask to have removed any more.
///
/// What the cascade does, by table (checked against the live schema
/// 2026-09-14): profiles, enrollments, lesson_progress, course_ratings,
/// course_comments, notifications received, payout_accounts and the user's
/// own courses (with their lessons) are deleted. transactions keep the row
/// with buyer_id/teacher_id set to null. content_reports keep the report.
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  try {
    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const jwt = (req.headers.get("Authorization") ?? "").replace("Bearer ", "");
    const { data: userData, error: userErr } = await admin.auth.getUser(jwt);
    if (userErr || !userData?.user) return json({ error: "Unauthorized" }, 401);
    const uid = userData.user.id;

    // --- 1. Paid students ---------------------------------------------------
    // Deleting a teacher deletes their courses, and with them the access that
    // students paid for. Until refunds exist that has to go through a person.
    const { count: paidStudents, error: paidErr } = await admin
      .from("enrollments")
      .select("id, courses!inner(user_id)", { count: "exact", head: true })
      .eq("courses.user_id", uid)
      .eq("is_free", false)
      .neq("user_id", uid);
    if (paidErr) return json({ error: paidErr.message }, 500);

    if ((paidStudents ?? 0) > 0) {
      return json({
        error:
          "Students have paid for your courses, so your account can't be " +
          "deleted automatically. Contact support and we'll sort out their " +
          "access first.",
        code: "paid_students",
      }, 409);
    }

    // --- 2. Files -----------------------------------------------------------
    for (const bucket of USER_BUCKETS) {
      const keys = await listAll(admin, bucket, uid);
      // `remove` takes a batch; keep batches modest.
      for (let i = 0; i < keys.length; i += 100) {
        const { error } = await admin.storage
          .from(bucket)
          .remove(keys.slice(i, i + 100));
        if (error) {
          return json({ error: `Could not remove files: ${error.message}` }, 500);
        }
      }
    }

    // --- 3. The account -----------------------------------------------------
    const { error: deleteErr } = await admin.auth.admin.deleteUser(uid);
    if (deleteErr) return json({ error: deleteErr.message }, 500);

    return json({ deleted: true });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
