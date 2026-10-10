import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgrestException, SupabaseClient;

import 'package:padi_learn/services/lesson_service.dart';
import 'package:padi_learn/services/supabase.dart';
import 'package:padi_learn/services/supabase_storage_service.dart';

/// Most drafts one teacher may hold. The database is what enforces it
/// (`private.course_draft_limit()` in 20261010000001_course_drafts.sql); this
/// copy only lets the app say no before a video has been sent.
const int kMaxCourseDrafts = 3;

/// The database's own sentence for that refusal, so the early no and the real
/// one read the same.
const String kDraftLimitMessage =
    'You already have $kMaxCourseDrafts drafts. Upload or delete one before '
    'saving another.';

/// Whether [course] is a draft: saved, never uploaded, and visible only to its
/// owner and to admins.
///
/// A draft is a row whose `published_at` is null. A row without the key at all
/// (read before the column existed, or by a query that did not ask for it) is
/// not one: every course was live before drafts.
bool isDraftCourse(Map<dynamic, dynamic> course) =>
    course.containsKey('published_at') && course['published_at'] == null;

/// What [course] still needs before it can be uploaded, in the words the
/// teacher is shown. Empty when it is ready.
///
/// The same list, in the same order, as `private.course_publish_gaps()` in the
/// database, which has the final say. It is what the create screen's "Upload"
/// has always insisted on.
List<String> publishGaps(Map<String, dynamic> course, List<Lesson> lessons) {
  bool blank(Object? value) => (value ?? '').toString().trim().isEmpty;
  return [
    if (blank(course['description'])) 'a description',
    if (blank(course['author'])) 'an author name',
    if (blank(course['category'])) 'a category',
    if (course['price'] == null) 'a price',
    if (blank(course['thumbnail_url'])) 'a cover image',
    if (!lessons.any((lesson) => lesson.hasVideo)) 'a lesson with a video',
  ];
}

/// `a description, a category and a cover image`
String readableList(List<String> items) {
  if (items.isEmpty) return '';
  if (items.length == 1) return items.first;
  return '${items.sublist(0, items.length - 1).join(', ')} and ${items.last}';
}

/// The sentence for a course that cannot be uploaded yet. The database raises
/// the same one.
String publishGapsMessage(List<String> gaps) =>
    'This course cannot be uploaded yet. It still needs ${readableList(gaps)}.';

/// A refused save, in words to show the teacher.
///
/// The rules a teacher can trip (the draft limit, an incomplete course, a
/// paid course without a bank account) are raised by the database with code
/// 22023 and a sentence written to be shown as it is. Anything else keeps the
/// [fallback] in front, as before.
String courseErrorMessage(Object error, {required String fallback}) {
  if (error is PostgrestException) {
    return error.code == '22023' ? error.message : '$fallback: ${error.message}';
  }
  return '$fallback: ${error.toString().replaceFirst('Exception: ', '')}';
}

String? _blankToNull(String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

/// Write operations a teacher performs on their own courses.
///
/// Every call here is additionally gated by RLS — the policies only permit the
/// course's owner — so these methods are about intent and cleanup, not access
/// control.
class CourseService {
  /// Loads a single course row. Owners can always read their own courses, even
  /// once archived, and while still a draft.
  static Future<Map<String, dynamic>?> fetch(String courseId) async {
    final row = await supabase
        .from('courses')
        .select()
        .eq('id', courseId)
        .maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  /// Inserts a course and returns its id.
  ///
  /// [asDraft] decides who can see it. A draft sends `published_at: null`. A
  /// live course leaves the column out and takes the database's default of
  /// now, which is exactly what the apps from before drafts send, so the two
  /// can never come to mean different things.
  ///
  /// Only a draft may leave anything but the title empty; the database refuses
  /// a live course that does.
  static Future<String> create({
    required String userId,
    required String title,
    required bool asDraft,
    String? description,
    double? price,
    String? category,
    String? author,
    String? thumbnailUrl,
    SupabaseClient? client,
  }) async {
    final row = await (client ?? supabase)
        .from('courses')
        .insert({
          'title': title.trim(),
          'description': _blankToNull(description),
          'price': price,
          'category': category,
          'author': _blankToNull(author),
          'thumbnail_url': thumbnailUrl,
          'user_id': userId,
          if (asDraft) 'published_at': null,
        })
        .select('id')
        .single();
    return (row['id'] ?? '').toString();
  }

  /// How many drafts [userId] holds.
  static Future<int> draftCount(String userId, {SupabaseClient? client}) async {
    final rows = await (client ?? supabase)
        .from('courses')
        .select('id')
        .eq('user_id', userId)
        .isFilter('published_at', null);
    return rows.length;
  }

  /// Uploads a draft: it goes live in the marketplace at once.
  ///
  /// The database decides (`publish_course`), and refuses with a sentence that
  /// says what is missing; that sentence is what this throws.
  static Future<void> publish(String courseId, {SupabaseClient? client}) async {
    try {
      await (client ?? supabase)
          .rpc('publish_course', params: {'p_course_id': courseId});
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }

  /// Saves edited course details. Only the columns a teacher is allowed to
  /// write are sent; the trigger-maintained counters are not among them.
  ///
  /// [price] is null only for a draft whose price has not been chosen yet.
  static Future<void> updateDetails({
    required String courseId,
    required String title,
    required String description,
    required double? price,
    required String? category,
    required String author,
    String? thumbnailUrl,
  }) async {
    await supabase.from('courses').update({
      'title': title,
      'description': _blankToNull(description),
      'price': price,
      'category': category,
      'author': _blankToNull(author),
      if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
    }).eq('id', courseId);
  }

  /// Hides a course from the marketplace without touching anyone's access.
  ///
  /// Students who already enrolled keep the course — the SELECT policy still
  /// resolves it for them — which is why this exists instead of deleting.
  static Future<void> archive(String courseId) async {
    await supabase.from('courses').update(
        {'archived_at': DateTime.now().toUtc().toIso8601String()}).eq('id', courseId);
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

    // Collect the lesson videos before the row goes: deleting the course
    // cascades the lessons away, and with them any record of what to clean up.
    List<Lesson> lessons = const [];
    try {
      lessons = await LessonService.forCourse(courseId);
    } catch (_) {
      // Worst case a few objects are orphaned; the delete still proceeds.
    }

    // Asks for the deleted row back. RLS does not fail a delete it refuses, it
    // just matches nothing (a suspended account, see 20261006000010), so an
    // empty answer means the course is still there, and the media must stay.
    final deleted =
        await supabase.from('courses').delete().eq('id', courseId).select('id');
    if (deleted.isEmpty) {
      throw Exception(
        'This course could not be deleted. If your account is suspended, '
        'email hello@padilearn.com.',
      );
    }

    // Row is gone; clean the media up afterwards so a storage hiccup can't
    // leave a course the teacher believes they deleted.
    for (final lesson in lessons) {
      await removeStoredObject(
        lesson.videoPath,
        fallbackBucket: kCourseMediaBucket,
      );
    }
    await removeStoredObject(
      course['thumbnail_url'] as String?,
      fallbackBucket: kCourseThumbnailBucket,
    );
  }
}
