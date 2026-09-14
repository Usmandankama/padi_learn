import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:padi_learn/services/supabase.dart';

/// Why something was reported. The `value` strings are the database's check
/// constraint on `content_reports.reason` — change both together.
enum ReportReason {
  spam('spam', 'Spam or scam'),
  harassment('harassment', 'Harassment or bullying'),
  hate('hate', 'Hate speech'),
  sexual('sexual', 'Sexual content'),
  violence('violence', 'Violence or dangerous acts'),
  copyright('copyright', 'Copied or stolen content'),
  misleading('misleading', 'Misleading or false'),
  other('other', 'Something else');

  final String value;
  final String label;
  const ReportReason(this.value, this.label);
}

enum ReportOutcome { filed, alreadyReported }

/// Files reports on courses and comments.
///
/// Write-only from the app: who reported, the status and a snapshot of the
/// content are all filled in by a database trigger, and nobody reads reports
/// back through the API. See
/// `supabase/migrations/20260914000001_account_deletion_and_reports.sql`.
class ReportService {
  static Future<ReportOutcome> reportCourse(
    String courseId,
    ReportReason reason, {
    String? details,
  }) =>
      _file({
        'target_type': 'course',
        'course_id': courseId,
      }, reason, details);

  static Future<ReportOutcome> reportComment(
    String commentId,
    ReportReason reason, {
    String? details,
  }) =>
      _file({
        'target_type': 'comment',
        'comment_id': commentId,
      }, reason, details);

  static Future<ReportOutcome> _file(
    Map<String, dynamic> target,
    ReportReason reason,
    String? details,
  ) async {
    final trimmed = details?.trim();
    try {
      // No `.select()`: clients have no SELECT grant on this table, so asking
      // for the inserted row back would fail the whole request.
      await supabase.from('content_reports').insert({
        ...target,
        'reason': reason.value,
        if (trimmed != null && trimmed.isNotEmpty) 'details': trimmed,
      });
      return ReportOutcome.filed;
    } on PostgrestException catch (e) {
      // Unique violation: this person already reported this thing. Telling
      // them so is kinder than an error, and nothing is lost.
      if (e.code == '23505') return ReportOutcome.alreadyReported;
      rethrow;
    }
  }
}
