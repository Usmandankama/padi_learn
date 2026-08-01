import 'package:padi_learn/services/supabase.dart';
import 'package:padi_learn/services/supabase_storage_service.dart';

/// Write operations a teacher performs on their own courses.
///
/// Every call here is additionally gated by RLS — the policies only permit the
/// course's owner — so these methods are about intent and cleanup, not access
/// control.
class CourseService {
  /// Loads a single course row. Owners can always read their own courses, even
  /// once archived.
  static Future<Map<String, dynamic>?> fetch(String courseId) async {
    final row = await supabase
        .from('courses')
        .select()
        .eq('id', courseId)
        .maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  /// Saves edited course details. Only the columns a teacher is allowed to
  /// write are sent; the trigger-maintained counters are not among them.
  static Future<void> updateDetails({
    required String courseId,
    required String title,
    required String description,
    required double price,
    required String? category,
    required String author,
    String? videoPath,
    String? thumbnailUrl,
  }) async {
    await supabase.from('courses').update({
      'title': title,
      'description': description,
      'price': price,
      'category': category,
      'author': author,
      if (videoPath != null) 'video_url': videoPath,
      if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
    }).eq('id', courseId);
  }

  /// Hides a course from the marketplace without touching anyone's access.
  ///
  /// Students who already enrolled keep the course — the SELECT policy still
  /// resolves it for them — which is why this exists instead of deleting.
  static Future<void> archive(String courseId) async {
    await supabase
        .from('courses')
        .update({'archived_at': DateTime.now().toIso8601String()})
        .eq('id', courseId);
  }

  /// Puts an archived course back on the marketplace.
  static Future<void> unarchive(String courseId) async {
    await supabase
        .from('courses')
        .update({'archived_at': null}).eq('id', courseId);
  }

  /// Permanently removes a course and its media.
  ///
  /// Only safe when nobody is enrolled: `enrollments.course_id` cascades, so
  /// deleting a course with students would revoke access they paid for. The UI
  /// only offers this at zero enrollments, and this re-checks before acting.
  ///
  /// Note the enrollment count is read from the trigger-maintained
  /// `courses.enrollments` counter rather than the `enrollments` table — RLS
  /// only lets a user read their *own* enrollment rows, so a teacher cannot
  /// count their students directly.
  static Future<void> delete(Map<String, dynamic> course) async {
    final courseId = course['id'] as String;
    final enrolled = (course['enrollments'] as num?)?.toInt() ?? 0;
    if (enrolled > 0) {
      throw Exception(
        'This course has $enrolled student${enrolled == 1 ? '' : 's'}. '
        'Archive it instead so they keep their access.',
      );
    }

    await supabase.from('courses').delete().eq('id', courseId);

    // Row is gone; clean the media up afterwards so a storage hiccup can't
    // leave a course the teacher believes they deleted.
    await removeStoredObject(
      course['video_url'] as String?,
      fallbackBucket: kCourseMediaBucket,
    );
    await removeStoredObject(
      course['thumbnail_url'] as String?,
      fallbackBucket: kCourseThumbnailBucket,
    );
  }
}
