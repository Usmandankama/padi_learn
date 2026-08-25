import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const BUCKET = "course-media";

/// How long a playback URL stays valid. Long enough to watch a lesson without
/// interruption, short enough that a leaked link expires quickly.
const SIGNED_URL_TTL_SECONDS = 60 * 60 * 2;

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

/// Resolves a stored `lessons.video_url` to an object key inside [BUCKET].
///
/// New uploads store a bare object path. Lessons migrated from the old
/// single-video `courses.video_url` may still hold a full public URL from
/// before the bucket was made private, so that form is unwrapped too.
function toObjectPath(stored: string | null): string | null {
  if (!stored) return null;

  const marker = `/storage/v1/object/public/${BUCKET}/`;
  const at = stored.indexOf(marker);
  if (at !== -1) {
    return decodeURIComponent(stored.slice(at + marker.length).split("?")[0]);
  }

  // An absolute URL we did not issue - refuse rather than guess.
  if (/^https?:\/\//i.test(stored)) return null;

  return stored.replace(/^\/+/, "");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // Identify the caller from their JWT.
    const jwt = (req.headers.get("Authorization") ?? "").replace("Bearer ", "");
    const { data: userData, error: userErr } = await admin.auth.getUser(jwt);
    if (userErr || !userData?.user) return json({ error: "Unauthorized" }, 401);
    const user = userData.user;

    const { lessonId } = await req.json();
    if (!lessonId) return json({ error: "lessonId is required" }, 400);

    const { data: lesson, error: lessonErr } = await admin
      .from("lessons")
      .select("id, course_id, video_url, is_preview")
      .eq("id", lessonId)
      .maybeSingle();
    if (lessonErr || !lesson) return json({ error: "Lesson not found" }, 404);

    // A preview lesson is the teacher's own advert - playable without buying.
    let allowed = lesson.is_preview === true;

    if (!allowed) {
      const { data: course } = await admin
        .from("courses")
        .select("id, user_id")
        .eq("id", lesson.course_id)
        .maybeSingle();
      if (!course) return json({ error: "Course not found" }, 404);

      allowed = course.user_id === user.id;

      if (!allowed) {
        // Enrollments for paid courses are only ever created by
        // `verify-payment`, so this is the paywall.
        const { data: enrollment } = await admin
          .from("enrollments")
          .select("id")
          .eq("user_id", user.id)
          .eq("course_id", lesson.course_id)
          .maybeSingle();
        allowed = enrollment != null;
      }
    }

    if (!allowed) {
      return json({ error: "You are not enrolled in this course." }, 403);
    }

    const path = toObjectPath(lesson.video_url);
    if (!path) return json({ error: "This lesson has no video yet." }, 404);

    const { data: signed, error: signErr } = await admin.storage
      .from(BUCKET)
      .createSignedUrl(path, SIGNED_URL_TTL_SECONDS);

    if (signErr || !signed?.signedUrl) {
      return json(
        { error: signErr?.message ?? "Could not prepare the video." },
        500,
      );
    }

    return json({
      url: signed.signedUrl,
      expires_in: SIGNED_URL_TTL_SECONDS,
    });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
