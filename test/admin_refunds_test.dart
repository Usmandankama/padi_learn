// Refunds move real money, in the Paystack dashboard; this screen only records
// them. The tests pin the split shown (computed by the database, decision 4,
// never typed), that recording needs both Paystack's reference and a reason,
// and exactly what is sent.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:padi_learn/admin/screens/refunds_screen.dart';

import 'admin_fakes.dart';

/// The one live sale, as admin_refunds_owed() would return it once its course
/// is taken down. Buyer and teacher are invented.
Map<String, dynamic> owed() => {
      'transaction_id': 'tx1',
      'reference': 'T512345678',
      'paid_at': '2026-10-06T16:06:48+00:00',
      'buyer_id': 'u-bola',
      'buyer_name': 'Bola Student',
      'buyer_email': 'bola@example.com',
      'course_id': 'c1',
      'course_title': 'Excel for Small Businesses',
      'removed_at': '2026-10-07T09:00:00+00:00',
      'removed_reason': 'copyright',
      'teacher_id': 'u-ada',
      'teacher_name': 'Ada Teacher',
      'amount_kobo': 517767,
      'teacher_clawback_kobo': 425000,
      'platform_cost_kobo': 92767,
    };

FakeAdminApi ledger() => FakeAdminApi()
  ..owedRows = [owed()]
  ..refundRows = [
    {
      ...owed(),
      'id': 'rf1',
      'created_at': '2026-10-07T10:00:00+00:00',
      'paystack_reference': 'RF_998877',
      'enrollment_revoked': true,
      'reason': 'takedown refund',
      'recorded_by': 'a1',
      'recorded_by_name': 'PadiLearn Admin',
    },
  ]
  ..recordRefundResult = const {
    'refund_id': 'rf2',
    'amount_kobo': 517767,
    'teacher_clawback_kobo': 425000,
    'platform_cost_kobo': 92767,
    'enrollment_revoked': true,
  };

void main() {
  testWidgets('shows who is owed and how the refund splits', (tester) async {
    await pumpAdminScreen(tester, RefundsScreen(api: ledger()));

    expect(tester.takeException(), isNull);
    expect(find.textContaining('bola@example.com'), findsOneWidget);
    expect(find.textContaining('T512345678'), findsOneWidget);
    expect(find.text('NGN 5,177.67'), findsOneWidget);
    expect(find.text('NGN 4,250.00'), findsOneWidget);
    expect(find.text('NGN 927.67'), findsOneWidget);
  });

  testWidgets('recording needs both the Paystack reference and a reason',
      (tester) async {
    final api = ledger();
    await pumpAdminScreen(tester, RefundsScreen(api: api));

    await tester.tap(find.widgetWithText(FilledButton, 'Record refund'));
    await tester.pumpAndSettle();

    final dialog = find.byType(AlertDialog);
    final confirm = find.descendant(
        of: dialog, matching: find.widgetWithText(FilledButton, 'Record refund'));
    final fields = find.descendant(of: dialog, matching: find.byType(TextField));

    await tester.enterText(fields.first, 'RF_123456');
    await tester.pump();
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull,
        reason: 'reason still missing');

    await tester.enterText(fields.last, 'course taken down for copyright');
    await tester.pump();
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(api.calls,
        contains('recordRefund:tx1:RF_123456:course taken down for copyright'));
    expect(find.textContaining('Refund recorded: NGN 5,177.67 back'),
        findsOneWidget);
    expect(find.textContaining('Their enrolment was removed.'), findsOneWidget);
    expect(api.count('refundsOwed'), 2, reason: 'reloaded after recording');
  });

  testWidgets('the recorded tab shows the Paystack reference and who recorded',
      (tester) async {
    await pumpAdminScreen(tester, RefundsScreen(api: ledger()));

    await tester.tap(find.text('Recorded'));
    await tester.pumpAndSettle();

    expect(find.textContaining('RF_998877'), findsOneWidget);
    expect(find.textContaining('PadiLearn Admin'), findsOneWidget);
    expect(find.textContaining('Enrolment removed.'), findsOneWidget);
  });
}
