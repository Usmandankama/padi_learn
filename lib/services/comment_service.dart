import 'package:padi_learn/services/supabase.dart';

/// Data access for the per-course comment section.
///
/// Comments are read with the author's profile embedded (name / avatar / role)
/// so the UI can render who said what without extra round-trips. Pinned
/// comments float to the top; the rest are newest-first.
class CommentService {
  /// Loads the comments for [courseId], pinned first then newest-first.
  static Future<List<Map<String, dynamic>>> fetch(String courseId) async {
    final rows = await supabase
        .from('course_comments')
        .select(
          'id, course_id, user_id, body, is_pinned, pinned_at, created_at, '
          'author:profiles!course_comments_user_id_fkey(name, profile_image_url, role)',
        )
        .eq('course_id', courseId)
        .order('is_pinned', ascending: false)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(rows);
  }

  /// Posts a new comment as the signed-in user and returns the created row
  /// (with the author profile embedded). The DB trigger notifies the lecturer.
  static Future<Map<String, dynamic>> add({
    required String courseId,
    required String body,
  }) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) {
      throw Exception('You must be signed in to comment.');
    }

    final row = await supabase
        .from('course_comments')
        .insert({
          'course_id': courseId,
          'user_id': uid,
          'body': body.trim(),
        })
        .select(
          'id, course_id, user_id, body, is_pinned, pinned_at, created_at, '
          'author:profiles!course_comments_user_id_fkey(name, profile_image_url, role)',
        )
        .single();

    return Map<String, dynamic>.from(row);
  }

  /// Pins or unpins a comment. Only the course owner (lecturer) is allowed by
  /// RLS — callers should still gate the UI on ownership.
  static Future<void> setPinned(String commentId, bool pinned) async {
    await supabase.from('course_comments').update({
      'is_pinned': pinned,
      'pinned_at': pinned ? DateTime.now().toIso8601String() : null,
    }).eq('id', commentId);
  }

  /// Deletes a comment. RLS permits the author or the course owner.
  static Future<void> delete(String commentId) async {
    await supabase.from('course_comments').delete().eq('id', commentId);
  }
}
