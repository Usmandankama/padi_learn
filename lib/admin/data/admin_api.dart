import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:padi_learn/services/supabase.dart';

/// Every call the admin app makes, in one place.
///
/// Each method is a thin wrapper over one admin function in the database
/// (supabase/migrations/20261006*). The database does all the checking, so
/// nothing here validates or decides anything; it only turns the JSON into
/// the shapes the screens read.
///
/// An instance rather than statics so every screen takes one, and a test can
/// hand it a fake that answers without a signed-in admin.
class AdminApi {
  const AdminApi();

  /// The overview document: `waiting`, `accounts`, `catalogue`, `learning`,
  /// `money`. Shape in 20261006000010, `admin_overview`.
  Future<Map<String, dynamic>> overview() async {
    return _object(await supabase.rpc('admin_overview'));
  }

  // --- Reports ---------------------------------------------------------------

  /// Reports with [status] (`open`, `actioned` or `dismissed`). Open ones come
  /// oldest first, resolved ones most recently resolved first.
  Future<List<Map<String, dynamic>>> reports(String status) async {
    return _rows(await supabase.rpc('admin_list_reports', params: {
      'p_status': status,
      'p_limit': reportPageSize,
    }));
  }

  /// The most reports one call returns.
  static const reportPageSize = 200;

  /// Dismisses, marks actioned, or reopens one report.
  Future<void> setReportStatus(
      String reportId, String status, String reason) async {
    await supabase.rpc('admin_set_report_status', params: {
      'p_report_id': reportId,
      'p_status': status,
      'p_reason': reason,
    });
  }

  /// Deletes a comment and closes every open report on it.
  /// Returns `{closed_reports}`.
  Future<Map<String, dynamic>> deleteComment(
      String commentId, String reason) async {
    return _object(await supabase.rpc('admin_delete_comment', params: {
      'p_comment_id': commentId,
      'p_reason': reason,
    }));
  }

  /// Takes a course down and closes its open course reports.
  /// Returns `{paid_sales, paid_kobo, closed_reports}`.
  Future<Map<String, dynamic>> removeCourse(
      String courseId, String reason) async {
    return _object(await supabase.rpc('admin_remove_course', params: {
      'p_course_id': courseId,
      'p_reason': reason,
    }));
  }

  // ---------------------------------------------------------------------------

  static Map<String, dynamic> _object(Object? result) =>
      Map<String, dynamic>.from(result as Map);

  static List<Map<String, dynamic>> _rows(Object? result) => [
        for (final row in result as List) Map<String, dynamic>.from(row as Map),
      ];
}

/// A failed admin call, in words an admin can act on.
///
/// The admin functions raise three kinds of error on purpose:
///   42501  not an admin, or the second factor has lapsed
///   22023  the request makes no sense (no reason given, already done, ...)
///   P0002  the thing asked about does not exist
/// The last two already carry a readable message from the function. The first
/// almost always means the session should be renewed.
String adminErrorMessage(Object error) {
  if (error is PostgrestException) {
    if (error.code == '42501') {
      return 'Not allowed. Your admin session may have lapsed: sign out and '
          'in again.';
    }
    return error.message;
  }
  if (error is AuthException) return error.message;
  return 'Something went wrong: $error';
}
