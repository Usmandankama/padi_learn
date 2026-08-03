import 'package:padi_learn/services/supabase.dart';

/// One lesson within a course.
class Lesson {
  final String id;
  final String courseId;
  final String title;
  final int position;

  /// Object key in the private `course-media` bucket. Useless on its own —
  /// playback goes through the `get-course-video` function.
  final String? videoPath;

  final int? durationSeconds;

  /// Preview lessons play for anyone signed in, enrolled or not.
  final bool isPreview;

  const Lesson({
    required this.id,
    required this.courseId,
    required this.title,
    required this.position,
    required this.videoPath,
    required this.durationSeconds,
    required this.isPreview,
  });

  factory Lesson.fromRow(Map<String, dynamic> row) => Lesson(
        id: (row['id'] ?? '').toString(),
        courseId: (row['course_id'] ?? '').toString(),
        title: (row['title'] ?? 'Untitled lesson').toString(),
        position: (row['position'] as num?)?.toInt() ?? 1,
        videoPath: row['video_url'] as String?,
        durationSeconds: (row['duration_seconds'] as num?)?.toInt(),
        isPreview: row['is_preview'] == true,
      );

  bool get hasVideo => (videoPath ?? '').isNotEmpty;

  /// `8:05` or `1:02:30`, or null when the duration was never captured.
  String? get durationLabel {
    final seconds = durationSeconds;
    if (seconds == null || seconds <= 0) return null;
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    final mm = h > 0 ? m.toString().padLeft(2, '0') : m.toString();
    return h > 0
        ? '$h:$mm:${s.toString().padLeft(2, '0')}'
        : '$mm:${s.toString().padLeft(2, '0')}';
  }
}

/// A student's place in one lesson.
class LessonProgress {
  final String lessonId;
  final int positionSeconds;
  final bool completed;

  const LessonProgress({
    required this.lessonId,
    required this.positionSeconds,
    required this.completed,
  });

  factory LessonProgress.fromRow(Map<String, dynamic> row) => LessonProgress(
        lessonId: (row['lesson_id'] ?? '').toString(),
        positionSeconds: (row['position_seconds'] as num?)?.toInt() ?? 0,
        completed: row['completed_at'] != null,
      );
}

/// Reads and writes lessons, and the signed-in student's progress through them.
///
/// RLS does the gatekeeping: anyone signed in can read the curriculum of a
/// course they can see, only the course owner can modify it, and progress rows
/// are private to their owner.
class LessonService {
  static const String _columns =
      'id, course_id, title, position, video_url, duration_seconds, is_preview';

  /// The course's lessons in running order.
  static Future<List<Lesson>> forCourse(String courseId) async {
    final rows = await supabase
        .from('lessons')
        .select(_columns)
        .eq('course_id', courseId)
        .order('position', ascending: true);

    return rows.map((row) => Lesson.fromRow(Map<String, dynamic>.from(row))).toList();
  }

  /// Appends a lesson, taking the next free position.
  static Future<Lesson> add({
    required String courseId,
    required String title,
    required String videoPath,
    int? durationSeconds,
    bool isPreview = false,
  }) async {
    final existing = await forCourse(courseId);
    final nextPosition =
        existing.isEmpty ? 1 : existing.map((l) => l.position).reduce((a, b) => a > b ? a : b) + 1;

    final row = await supabase
        .from('lessons')
        .insert({
          'course_id': courseId,
          'title': title,
          'position': nextPosition,
          'video_url': videoPath,
          'duration_seconds': durationSeconds,
          'is_preview': isPreview,
        })
        .select(_columns)
        .single();

    return Lesson.fromRow(Map<String, dynamic>.from(row));
  }

  /// Updates a lesson's details. Only non-null values are written, so callers
  /// can change the title without touching the video.
  static Future<void> update({
    required String lessonId,
    String? title,
    String? videoPath,
    int? durationSeconds,
    bool? isPreview,
  }) async {
    await supabase.from('lessons').update({
      if (title != null) 'title': title,
      if (videoPath != null) 'video_url': videoPath,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (isPreview != null) 'is_preview': isPreview,
    }).eq('id', lessonId);
  }

  static Future<void> delete(String lessonId) async {
    await supabase.from('lessons').delete().eq('id', lessonId);
  }

  /// Writes the running order back after a drag-and-drop reorder.
  ///
  /// Positions are rewritten wholesale rather than swapped, which is why the
  /// column has no unique constraint.
  static Future<void> reorder(List<Lesson> ordered) async {
    for (var i = 0; i < ordered.length; i++) {
      final lesson = ordered[i];
      if (lesson.position == i + 1) continue; // Already right.
      await supabase
          .from('lessons')
          .update({'position': i + 1}).eq('id', lesson.id);
    }
  }

  // ---------------------------------------------------------------------------
  // Progress
  // ---------------------------------------------------------------------------

  /// The signed-in student's progress across a course, keyed by lesson id.
  static Future<Map<String, LessonProgress>> progressForCourse(
      String courseId) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return const {};

    final rows = await supabase
        .from('lesson_progress')
        .select('lesson_id, position_seconds, completed_at')
        .eq('user_id', uid)
        .eq('course_id', courseId);

    return {
      for (final row in rows)
        (row['lesson_id'] ?? '').toString():
            LessonProgress.fromRow(Map<String, dynamic>.from(row)),
    };
  }

  /// Saves where the student got to. A database trigger recomputes the course
  /// percentage on `enrollments` from these rows, so nothing else needs
  /// updating.
  static Future<void> saveProgress({
    required String lessonId,
    required String courseId,
    required int positionSeconds,
    required bool completed,
  }) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;

    await supabase.from('lesson_progress').upsert(
      {
        'user_id': uid,
        'lesson_id': lessonId,
        'course_id': courseId,
        'position_seconds': positionSeconds,
        if (completed) 'completed_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'user_id,lesson_id',
    );
  }

  /// Total runtime of [lessons], or null when no duration was ever captured.
  static String? totalDurationLabel(List<Lesson> lessons) {
    final total = lessons.fold<int>(
      0,
      (sum, lesson) => sum + (lesson.durationSeconds ?? 0),
    );
    if (total <= 0) return null;

    final hours = total ~/ 3600;
    final minutes = (total % 3600) ~/ 60;
    if (hours > 0) return minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';
    return '${minutes}m';
  }
}
