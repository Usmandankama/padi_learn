import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:padi_learn/services/supabase.dart';

/// Resolves playable URLs for lesson videos.
///
/// Videos live in a private storage bucket, so the app never holds a durable
/// link. It asks the `get-course-video` edge function, which verifies the
/// lesson is a free preview, or that the caller owns the course or has an
/// enrollment row, before signing a short-lived URL. That check — not the UI —
/// is the paywall.
class VideoService {
  /// Returns a temporary playback URL for [lessonId].
  ///
  /// Throws with a user-presentable message when the caller has no access, the
  /// lesson has no video yet, or the request fails.
  static Future<String> playbackUrl(String lessonId) async {
    try {
      final res = await supabase.functions.invoke(
        'get-course-video',
        body: {'lessonId': lessonId},
      );
      final data = res.data as Map?;
      final url = data?['url'] as String?;
      if (url == null) {
        throw Exception(data?['error'] ?? 'Could not load this video.');
      }
      return url;
    } on FunctionException catch (e) {
      throw Exception(_message(e.details) ?? 'Could not load this video.');
    }
  }

  static String? _message(dynamic details) {
    if (details is Map) {
      return (details['error'] ?? details['message'])?.toString();
    }
    return null;
  }
}
