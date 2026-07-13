import 'package:padi_learn/services/supabase.dart';

/// Data access for lecturer notifications (new comments + new enrollments).
///
/// Rows are written server-side by SECURITY DEFINER triggers; the client only
/// reads them, marks them read, and deletes them. Notification rows are
/// denormalized (they carry [actor_name] / [course_title] / [message]) so the
/// UI and the realtime unread badge need no joins.
class NotificationService {
  /// Loads the signed-in user's notifications, newest first.
  static Future<List<Map<String, dynamic>>> fetch() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return [];

    final rows = await supabase
        .from('notifications')
        .select()
        .eq('recipient_id', uid)
        .order('created_at', ascending: false)
        .limit(100);

    return List<Map<String, dynamic>>.from(rows);
  }

  /// Realtime stream of the user's notifications (newest first). Drives both the
  /// notifications list and the unread badge so they stay live.
  static Stream<List<Map<String, dynamic>>> stream() {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return Stream.value(<Map<String, dynamic>>[]);

    return supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('recipient_id', uid)
        .order('created_at', ascending: false);
  }

  /// Marks a single notification as read.
  static Future<void> markRead(String id) async {
    await supabase.from('notifications').update({'is_read': true}).eq('id', id);
  }

  /// Marks every unread notification for the current user as read.
  static Future<void> markAllRead() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    await supabase
        .from('notifications')
        .update({'is_read': true})
        .eq('recipient_id', uid)
        .eq('is_read', false);
  }

  /// Deletes a notification.
  static Future<void> delete(String id) async {
    await supabase.from('notifications').delete().eq('id', id);
  }
}
