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

  // --- Users -----------------------------------------------------------------

  /// Accounts matching part of an email or name, or an exact id. An empty
  /// [query] lists the newest accounts.
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final q = query.trim();
    return _rows(await supabase.rpc('admin_search_users', params: {
      'p_query': q.isEmpty ? null : q,
      'p_limit': userPageSize,
    }));
  }

  /// The most accounts one search returns.
  static const userPageSize = 50;

  /// Everything about one account, as one document. Shape in 20261006000010,
  /// `admin_user_detail`.
  Future<Map<String, dynamic>> userDetail(String userId) async {
    return _object(await supabase.rpc('admin_user_detail', params: {
      'p_user_id': userId,
    }));
  }

  /// Sets the role to `Student` or `Teacher`, or clears it (null) so the user
  /// picks again on their next launch.
  Future<void> setRole(String userId, String? role, String reason) async {
    await supabase.rpc('admin_set_role', params: {
      'p_user_id': userId,
      'p_role': role,
      'p_reason': reason,
    });
  }

  /// Suspends an account. Returns `{courses_hidden}`.
  Future<Map<String, dynamic>> suspendUser(String userId, String reason) async {
    return _object(await supabase.rpc('admin_suspend_user', params: {
      'p_user_id': userId,
      'p_reason': reason,
    }));
  }

  Future<void> liftSuspension(String userId, String reason) async {
    await supabase.rpc('admin_lift_suspension', params: {
      'p_user_id': userId,
      'p_reason': reason,
    });
  }

  // --- Courses ---------------------------------------------------------------

  /// Every course, newest first, including archived and taken-down ones, with
  /// its teacher's name as `owner_name`.
  ///
  /// Read straight from the table: the "Admins can see every course" policy
  /// (20261006000002) lets an admin session see all of them. The names come
  /// from a second query because `courses.user_id` points at auth.users, not
  /// profiles, so PostgREST cannot embed them.
  Future<List<Map<String, dynamic>>> courses() async {
    final rows = _rows(await supabase
        .from('courses')
        .select('id, title, price, category, user_id, enrollments, '
            'created_at, archived_at, removed_at, removed_reason')
        .order('created_at', ascending: false)
        .limit(coursePageSize));
    await _attachNames(rows, idKey: 'user_id', nameKey: 'owner_name');
    return rows;
  }

  static const coursePageSize = 500;

  /// Puts a taken-down course back.
  Future<void> restoreCourse(String courseId, String reason) async {
    await supabase.rpc('admin_restore_course', params: {
      'p_course_id': courseId,
      'p_reason': reason,
    });
  }

  // --- Refunds ---------------------------------------------------------------

  /// Paid sales of taken-down courses with no refund recorded yet.
  Future<List<Map<String, dynamic>>> refundsOwed() async {
    return _rows(await supabase.rpc('admin_refunds_owed'));
  }

  /// Records a refund already issued in the Paystack dashboard. The split is
  /// computed by the database. Returns `{refund_id, amount_kobo,
  /// teacher_clawback_kobo, platform_cost_kobo, enrollment_revoked}`.
  Future<Map<String, dynamic>> recordRefund(
      String transactionId, String paystackReference, String reason) async {
    return _object(await supabase.rpc('admin_record_refund', params: {
      'p_transaction_id': transactionId,
      'p_paystack_reference': paystackReference,
      'p_reason': reason,
    }));
  }

  Future<List<Map<String, dynamic>>> refunds() async {
    return _rows(await supabase.rpc('admin_list_refunds', params: {
      'p_limit': 200,
    }));
  }

  // --- Payouts ---------------------------------------------------------------

  /// Every teacher with a sale or a payout, most payable first, with the bank
  /// account a transfer goes to.
  Future<List<Map<String, dynamic>>> teacherBalances() async {
    return _rows(await supabase.rpc('admin_teacher_balances'));
  }

  /// Records a transfer already made. Returns `{payout_id, amount_kobo,
  /// available_after_kobo}`.
  Future<Map<String, dynamic>> recordPayout({
    required String teacherId,
    required int amountKobo,
    required String transferReference,
    String? note,
  }) async {
    return _object(await supabase.rpc('admin_record_payout', params: {
      'p_teacher_id': teacherId,
      'p_amount_kobo': amountKobo,
      'p_transfer_reference': transferReference,
      'p_note': note,
    }));
  }

  Future<List<Map<String, dynamic>>> payouts() async {
    return _rows(await supabase.rpc('admin_list_payouts', params: {
      'p_limit': 200,
    }));
  }

  // --- Categories ------------------------------------------------------------

  /// Pending suggestions first, then the approved list in display order.
  Future<List<Map<String, dynamic>>> categories() async {
    return _rows(await supabase.rpc('admin_list_categories'));
  }

  Future<void> setCategoryActive(String id, bool active, {String? reason}) async {
    await supabase.rpc('admin_set_category_active', params: {
      'p_category_id': id,
      'p_active': active,
      'p_reason': reason,
    });
  }

  /// Renames and/or reorders. A null field is left as it is.
  Future<void> updateCategory(String id,
      {String? name, int? position, String? reason}) async {
    await supabase.rpc('admin_update_category', params: {
      'p_category_id': id,
      'p_name': name,
      'p_position': position,
      'p_reason': reason,
    });
  }

  /// Deletes a category, moving its courses to [moveTo] first. Returns
  /// `{courses_moved}`.
  Future<Map<String, dynamic>> deleteCategory(String id,
      {String? moveTo, String? reason}) async {
    return _object(await supabase.rpc('admin_delete_category', params: {
      'p_category_id': id,
      'p_move_to': moveTo,
      'p_reason': reason,
    }));
  }

  // --- Audit log -------------------------------------------------------------

  /// Admin actions, newest first, with the acting admin's name as
  /// `admin_name`. Read through "Admins can read the audit log"
  /// (20261006000001).
  Future<List<Map<String, dynamic>>> auditLog() async {
    final rows = _rows(await supabase
        .from('admin_actions')
        .select('id, admin_id, action, target_type, target_id, reason, '
            'details, created_at')
        .order('created_at', ascending: false)
        .limit(auditPageSize));
    await _attachNames(rows, idKey: 'admin_id', nameKey: 'admin_name');
    return rows;
  }

  static const auditPageSize = 300;

  // ---------------------------------------------------------------------------

  /// Adds `profiles.name` to each row under [nameKey], looked up by the user
  /// id in [idKey]. Profiles are readable by any signed-in user.
  static Future<void> _attachNames(List<Map<String, dynamic>> rows,
      {required String idKey, required String nameKey}) async {
    final ids = {
      for (final row in rows)
        if (row[idKey] is String) row[idKey] as String,
    };
    if (ids.isEmpty) return;
    final profiles = await supabase
        .from('profiles')
        .select('id, name')
        .inFilter('id', ids.toList());
    final names = {
      for (final p in profiles) p['id'] as String: p['name'] as String?,
    };
    for (final row in rows) {
      row[nameKey] = names[row[idKey]];
    }
  }

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
