// Shared by the admin screen tests: an AdminApi that answers from memory and
// records what it was asked, plus the frame every admin screen is pumped in.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:padi_learn/admin/data/admin_api.dart';
import 'package:padi_learn/utils/colors.dart';

class FakeAdminApi extends AdminApi {
  FakeAdminApi({
    this.overviewDoc,
    Map<String, List<Map<String, dynamic>>>? reports,
    this.removeCourseResult = const {
      'paid_sales': 0,
      'paid_kobo': 0,
      'closed_reports': 1,
    },
  }) : reportsByStatus = reports ?? {};

  Map<String, dynamic> Function()? overviewDoc;
  final Map<String, List<Map<String, dynamic>>> reportsByStatus;
  final Map<String, dynamic> removeCourseResult;

  /// Thrown by the next load, when set.
  Object? loadError;

  /// Thrown by the next action, when set.
  Object? actionError;

  /// Every call, in order, as `name:arg:arg`.
  final calls = <String>[];

  int count(String prefix) => calls.where((c) => c.startsWith(prefix)).length;

  @override
  Future<Map<String, dynamic>> overview() async {
    calls.add('overview');
    if (loadError != null) throw loadError!;
    return overviewDoc!();
  }

  @override
  Future<List<Map<String, dynamic>>> reports(String status) async {
    calls.add('reports:$status');
    if (loadError != null) throw loadError!;
    return [...?reportsByStatus[status]];
  }

  @override
  Future<void> setReportStatus(
      String reportId, String status, String reason) async {
    calls.add('setReportStatus:$reportId:$status:$reason');
    if (actionError != null) throw actionError!;
  }

  @override
  Future<Map<String, dynamic>> deleteComment(
      String commentId, String reason) async {
    calls.add('deleteComment:$commentId:$reason');
    if (actionError != null) throw actionError!;
    return {'closed_reports': 2};
  }

  @override
  Future<Map<String, dynamic>> removeCourse(
      String courseId, String reason) async {
    calls.add('removeCourse:$courseId:$reason');
    if (actionError != null) throw actionError!;
    return removeCourseResult;
  }

  // --- Users -----------------------------------------------------------------

  List<Map<String, dynamic>> users = [];
  Map<String, Map<String, dynamic>> userDetails = {};
  Map<String, dynamic> suspendResult = const {'courses_hidden': 0};

  @override
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    calls.add('searchUsers:$query');
    if (loadError != null) throw loadError!;
    return [...users];
  }

  @override
  Future<Map<String, dynamic>> userDetail(String userId) async {
    calls.add('userDetail:$userId');
    if (loadError != null) throw loadError!;
    return Map.of(userDetails[userId]!);
  }

  @override
  Future<void> setRole(String userId, String? role, String reason) async {
    calls.add('setRole:$userId:$role:$reason');
    if (actionError != null) throw actionError!;
  }

  @override
  Future<Map<String, dynamic>> suspendUser(String userId, String reason) async {
    calls.add('suspendUser:$userId:$reason');
    if (actionError != null) throw actionError!;
    return suspendResult;
  }

  @override
  Future<void> liftSuspension(String userId, String reason) async {
    calls.add('liftSuspension:$userId:$reason');
    if (actionError != null) throw actionError!;
  }

  // --- Courses ---------------------------------------------------------------

  List<Map<String, dynamic>> courseRows = [];

  @override
  Future<List<Map<String, dynamic>>> courses() async {
    calls.add('courses');
    if (loadError != null) throw loadError!;
    return [for (final c in courseRows) Map.of(c)];
  }

  @override
  Future<void> restoreCourse(String courseId, String reason) async {
    calls.add('restoreCourse:$courseId:$reason');
    if (actionError != null) throw actionError!;
  }

  // --- Refunds ---------------------------------------------------------------

  List<Map<String, dynamic>> owedRows = [];
  List<Map<String, dynamic>> refundRows = [];
  Map<String, dynamic> recordRefundResult = const {};

  @override
  Future<List<Map<String, dynamic>>> refundsOwed() async {
    calls.add('refundsOwed');
    if (loadError != null) throw loadError!;
    return [...owedRows];
  }

  @override
  Future<Map<String, dynamic>> recordRefund(
      String transactionId, String paystackReference, String reason) async {
    calls.add('recordRefund:$transactionId:$paystackReference:$reason');
    if (actionError != null) throw actionError!;
    return recordRefundResult;
  }

  @override
  Future<List<Map<String, dynamic>>> refunds() async {
    calls.add('refunds');
    if (loadError != null) throw loadError!;
    return [...refundRows];
  }

  // --- Payouts ---------------------------------------------------------------

  List<Map<String, dynamic>> balanceRows = [];
  List<Map<String, dynamic>> payoutRows = [];

  @override
  Future<List<Map<String, dynamic>>> teacherBalances() async {
    calls.add('teacherBalances');
    if (loadError != null) throw loadError!;
    return [...balanceRows];
  }

  @override
  Future<void> declinePayoutRequest(String requestId, String reason) async {
    calls.add('declinePayoutRequest:$requestId:$reason');
    if (actionError != null) throw actionError!;
  }

  @override
  Future<Map<String, dynamic>> recordPayout({
    required String teacherId,
    required int amountKobo,
    required String transferReference,
    String? note,
  }) async {
    calls.add('recordPayout:$teacherId:$amountKobo:$transferReference:$note');
    if (actionError != null) throw actionError!;
    return {'payout_id': 'p1', 'amount_kobo': amountKobo, 'available_after_kobo': 50000};
  }

  @override
  Future<List<Map<String, dynamic>>> payouts() async {
    calls.add('payouts');
    if (loadError != null) throw loadError!;
    return [...payoutRows];
  }

  // --- Categories ------------------------------------------------------------

  List<Map<String, dynamic>> categoryRows = [];

  @override
  Future<List<Map<String, dynamic>>> categories() async {
    calls.add('categories');
    if (loadError != null) throw loadError!;
    return [for (final c in categoryRows) Map.of(c)];
  }

  @override
  Future<void> setCategoryActive(String id, bool active,
      {String? reason}) async {
    calls.add('setCategoryActive:$id:$active');
    if (actionError != null) throw actionError!;
  }

  @override
  Future<void> updateCategory(String id,
      {String? name, int? position, String? reason}) async {
    calls.add('updateCategory:$id:$name:$position');
    if (actionError != null) throw actionError!;
  }

  @override
  Future<Map<String, dynamic>> deleteCategory(String id,
      {String? moveTo, String? reason}) async {
    calls.add('deleteCategory:$id:$moveTo');
    if (actionError != null) throw actionError!;
    return {'courses_moved': moveTo == null ? 0 : 1};
  }

  // --- Audit log -------------------------------------------------------------

  List<Map<String, dynamic>> auditRows = [];

  @override
  Future<List<Map<String, dynamic>>> auditLog() async {
    calls.add('auditLog');
    if (loadError != null) throw loadError!;
    return [...auditRows];
  }
}

/// Pumps [screen] at laptop size, which is what the admin app is for.
Future<void> pumpAdminScreen(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(1440, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(extensions: const [AppPalette.light]),
    home: Scaffold(body: screen),
  ));
  await tester.pumpAndSettle();
}
