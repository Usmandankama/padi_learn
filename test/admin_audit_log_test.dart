// The audit log is how an admin answers "who did this, and why". These pin
// that every action reads in words, that money in the details is shown to the
// kobo, and that the area filter keeps only its own actions.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:padi_learn/admin/screens/audit_log_screen.dart';

import 'admin_fakes.dart';

Map<String, dynamic> entry(
  int id,
  String action,
  String targetType, {
  String? reason,
  Map<String, dynamic> details = const {},
}) =>
    {
      'id': id,
      'admin_id': 'a1',
      'admin_name': 'PadiLearn Admin',
      'action': action,
      'target_type': targetType,
      'target_id': 'target-$id',
      'reason': reason,
      'details': details,
      'created_at': '2026-10-07T10:0$id:00+00:00',
    };

FakeAdminApi history() => FakeAdminApi()
  ..auditRows = [
    entry(3, 'refund.record', 'transaction',
        reason: 'takedown refund',
        details: {
          'amount_kobo': 517767,
          'teacher_clawback_kobo': 425000,
          'platform_cost_kobo': 92767,
        }),
    entry(2, 'course.remove', 'course',
        reason: 'copyright', details: {'paid_sales': 1, 'paid_kobo': 517767}),
    entry(1, 'category.approve', 'category'),
  ];

void main() {
  testWidgets('every action reads in words, with who and why', (tester) async {
    await pumpAdminScreen(tester, AuditLogScreen(api: history()));

    expect(tester.takeException(), isNull);
    expect(find.text('Recorded a refund'), findsOneWidget);
    expect(find.text('Took a course down'), findsOneWidget);
    expect(find.text('Approved a category'), findsOneWidget);
    expect(find.textContaining('PadiLearn Admin'), findsNWidgets(3));
    expect(find.textContaining('copyright'), findsOneWidget);
  });

  testWidgets('details show money to the kobo', (tester) async {
    await pumpAdminScreen(tester, AuditLogScreen(api: history()));

    await tester.tap(find.text('Recorded a refund'));
    await tester.pumpAndSettle();

    expect(find.textContaining('amount kobo: NGN 5,177.67'), findsOneWidget);
    expect(find.textContaining('platform cost kobo: NGN 927.67'),
        findsOneWidget);
  });

  testWidgets('the area filter keeps only its own actions', (tester) async {
    await pumpAdminScreen(tester, AuditLogScreen(api: history()));

    await tester.tap(find.widgetWithText(ChoiceChip, 'Courses'));
    await tester.pumpAndSettle();

    expect(find.text('Took a course down'), findsOneWidget);
    expect(find.text('Recorded a refund'), findsNothing);
    expect(find.text('Approved a category'), findsNothing);
  });
}
