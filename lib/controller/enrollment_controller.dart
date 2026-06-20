import 'package:padi_learn/services/supabase.dart';

/// Handles course enrolment for a given user against Supabase.
class EnrollmentController {
  final String userId;

  EnrollmentController({required this.userId});

  /// Whether [userId] already has an enrolment for [courseId].
  Future<bool> isUserEnrolled(String courseId) async {
    final row = await supabase
        .from('enrollments')
        .select('id')
        .eq('user_id', userId)
        .eq('course_id', courseId)
        .maybeSingle();
    return row != null;
  }

  /// Enrols the user in a course. Idempotent — a duplicate (user, course)
  /// enrolment is ignored, so the course's enrolment count isn't double-counted.
  Future<void> enrollUser({
    required String courseId,
    required String title,
    required String image,
    required String videoUrl,
    bool isFree = false,
  }) async {
    await supabase.from('enrollments').upsert(
      {
        'user_id': userId,
        'course_id': courseId,
        'title': title,
        'image': image,
        'video_url': videoUrl,
        'progress': 0,
        'is_free': isFree,
      },
      onConflict: 'user_id,course_id',
      ignoreDuplicates: true,
    );
  }
}
