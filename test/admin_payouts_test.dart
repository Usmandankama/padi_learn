// Payouts record money that has already left PadiLearn's account, so a typo
// here is a teacher's balance wrong. The tests pin the amount parser (refuse,
// never round), that the record button only appears when the database would
// accept the payout (and says why not otherwise), and what is sent.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:padi_learn/admin/screens/payouts_screen.dart';
import 'package:padi_learn/admin/widgets/format.dart';

import 'admin_fakes.dart';

Map<String, dynamic> balance(
  String id,
  String name, {
  int available = 0,
  int pending = 0,
  bool verified = true,
  bool suspended = false,
  bool hasAccount = true,
}) =>
    {
      'teacher_id': id,
      'teacher_name': name,
      'teacher_email': '${name.split(' ').first.toLowerCase()}@example.com',
      'sales_count': 2,
      'earned_kobo': available + pending,
      'clawback_kobo': 0,
      'paid_out_kobo': 0,
      'pending_kobo': pending,
      'balance_kobo': available + pending,
      'available_kobo': available,
      'bank_name': hasAccount ? 'Guaranty Trust Bank' : null,
      'account_number': hasAccount ? '0123456789' : null,
      'account_name': hasAccount ? name.toUpperCase() : null,
      'account_verified': hasAccount && verified,
      'suspended': suspended,
    };

FakeAdminApi books() => FakeAdminApi()
  ..balanceRows = [
    balance('t1', 'Ada Teacher', available: 200000),
    balance('t2', 'Chidi Held', available: 100000, suspended: true),
    balance('t3', 'Dayo New', pending: 425000),
    balance('t4', 'Efe Unbanked', available: 30000, hasAccount: false),
  ]
  ..payoutRows = [
    {
      'id': 'p1',
      'paid_at': '2026-10-07T09:00:00+00:00',
      'created_at': '2026-10-07T09:05:00+00:00',
      'teacher_id': 't1',
      'teacher_name': 'Ada Teacher',
      'amount_kobo': 150000,
      'bank_name': 'Guaranty Trust Bank',
      'account_number': '0123456789',
      'account_name': 'ADA TEACHER',
      'transfer_reference': 'TRF-0001',
      'note': null,
      'recorded_by': 'a1',
      'recorded_by_name': 'PadiLearn Admin',
    },
  ];

void main() {
  group('parseNairaToKobo', () {
    test('reads what an admin types', () {
      expect(parseNairaToKobo('4250'), 425000);
      expect(parseNairaToKobo('4,250.5'), 425050);
      expect(parseNairaToKobo('NGN 4,250.00'), 425000);
      expect(parseNairaToKobo('0.05'), 5);
    });

    test('refuses rather than rounding a typo', () {
      expect(parseNairaToKobo('4250.555'), isNull);
      expect(parseNairaToKobo('4,25o'), isNull);
      expect(parseNairaToKobo('-100'), isNull);
      expect(parseNairaToKobo('0'), isNull);
      expect(parseNairaToKobo(''), isNull);
    });

    test('round-trips with the prefill', () {
      expect(koboToPlainNaira(200000), '2000.00');
      expect(parseNairaToKobo(koboToPlainNaira(517767)), 517767);
    });
  });

  testWidgets('only a payable, banked, unsuspended teacher can be paid',
      (tester) async {
    await pumpAdminScreen(tester, PayoutsScreen(api: books()));

    expect(tester.takeException(), isNull);
    expect(find.widgetWithText(FilledButton, 'Record payout'), findsOneWidget);
    expect(find.text('Payouts held while this teacher is suspended.'),
        findsOneWidget);
    expect(find.text('Nothing payable yet: sales are held for 7 days.'),
        findsOneWidget);
    // The fourth card is below the fold; the list builds lazily.
    await tester.scrollUntilVisible(
      find.textContaining('No verified bank account yet'),
      300,
      scrollable: find
          .descendant(
              of: find.byType(ListView), matching: find.byType(Scrollable))
          .first,
    );
    expect(find.textContaining('No verified bank account yet'), findsOneWidget);
  });

  testWidgets('recording sends the amount in kobo, the reference and a note',
      (tester) async {
    final api = books();
    await pumpAdminScreen(tester, PayoutsScreen(api: api));

    await tester.tap(find.widgetWithText(FilledButton, 'Record payout'));
    await tester.pumpAndSettle();

    final fields = find.descendant(
        of: find.byType(AlertDialog), matching: find.byType(TextField));
    expect(find.text('2000.00'), findsOneWidget, reason: 'prefilled');

    await tester.enterText(fields.at(0), '1,500');
    await tester.enterText(fields.at(1), 'TRF-0002');
    await tester.enterText(fields.at(2), 'first payout');
    await tester.pump();
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, 'Record payout'),
    ));
    await tester.pumpAndSettle();

    expect(api.calls, contains('recordPayout:t1:150000:TRF-0002:first payout'));
    expect(find.textContaining('Payout of NGN 1,500.00 recorded'),
        findsOneWidget);
    expect(api.count('teacherBalances'), 2, reason: 'reloaded after recording');
  });

  testWidgets('more than is payable cannot be confirmed', (tester) async {
    await pumpAdminScreen(tester, PayoutsScreen(api: books()));

    await tester.tap(find.widgetWithText(FilledButton, 'Record payout'));
    await tester.pumpAndSettle();
    final fields = find.descendant(
        of: find.byType(AlertDialog), matching: find.byType(TextField));
    await tester.enterText(fields.at(0), '2000.01');
    await tester.enterText(fields.at(1), 'TRF-0003');
    await tester.pump();

    expect(find.textContaining('More than the NGN 2,000.00 payable'),
        findsOneWidget);
    final confirm = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, 'Record payout'),
    );
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
  });

  testWidgets('payouts made shows where the money went', (tester) async {
    await pumpAdminScreen(tester, PayoutsScreen(api: books()));

    await tester.tap(find.text('Payouts made'));
    await tester.pumpAndSettle();

    expect(find.text('NGN 1,500.00 to Ada Teacher'), findsOneWidget);
    expect(find.textContaining('TRF-0001'), findsOneWidget);
  });
}
