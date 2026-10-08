// A teacher asking to be paid (docs/ADMIN_PANEL.md, item 15). The database
// decides; these pin that the screen offers exactly one next step, says which
// rule is in the way when there is none, and reads `my_payouts()` as the live
// function returns it.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:padi_learn/screens/teacher/payouts_screen.dart';
import 'package:padi_learn/services/payout_account_service.dart';
import 'package:padi_learn/services/payout_service.dart';
import 'package:padi_learn/services/transaction_service.dart';

Widget phone(Widget child) => MediaQuery(
      data: const MediaQueryData(size: Size(393, 852)),
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (_, __) => MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    );

TeacherBalance balanceOf(int availableKobo, {bool held = false}) =>
    TeacherBalance.fromJson({
      'sales_count': 3,
      'earned_kobo': availableKobo + 425000,
      'clawback_kobo': 0,
      'paid_out_kobo': 0,
      'pending_kobo': 425000,
      'available_kobo': availableKobo,
      'payouts_held': held,
    });

final gtb = PayoutAccount(
  bankCode: '058',
  bankName: 'Guaranty Trust Bank',
  accountNumber: '0123456789',
  accountName: 'ADA TEACHER',
  verifiedAt: DateTime(2026, 10, 1),
);

PayoutSummary summaryOf(Map<String, dynamic> extra) =>
    PayoutSummary.fromJson({'minimum_kobo': 100000, 'payouts': [], ...extra});

class Taps {
  int request = 0, cancel = 0, account = 0;
}

Future<Taps> pumpPanel(
  WidgetTester tester, {
  required TeacherBalance balance,
  PayoutAccount? account,
  PayoutSummary? summary,
}) async {
  final taps = Taps();
  await tester.pumpWidget(phone(PayoutRequestPanel(
    balance: balance,
    account: account,
    summary: summary ?? summaryOf(const {}),
    onRequest: () => taps.request++,
    onCancel: () => taps.cancel++,
    onOpenAccount: () => taps.account++,
  )));
  return taps;
}

void main() {
  group('PayoutSummary', () {
    test('reads my_payouts() as the database returns it', () {
      final summary = PayoutSummary.fromJson(const {
        'minimum_kobo': 100000,
        'open_request': {
          'id': 'r1',
          'amount_kobo': 425000,
          'created_at': '2026-10-08T09:00:00+00:00',
        },
        'last_closed_request': {
          'status': 'paid',
          'amount_kobo': 200000,
          'created_at': '2026-10-01T09:00:00+00:00',
          'resolved_at': '2026-10-02T09:00:00+00:00',
          'resolution_note': null,
        },
        'payouts': [
          {
            'amount_kobo': 200000,
            'paid_at': '2026-10-02T09:00:00+00:00',
            'bank_name': 'Guaranty Trust Bank',
            'account_last4': '6789',
            'transfer_reference': 'TRF-0001',
          },
        ],
      });

      expect(summary.minimum, 1000);
      expect(summary.openRequest!.amount, 4250);
      expect(summary.payouts.single.accountLast4, '6789');
      expect(summary.showDecline, isFalse);
    });

    test('a declined request is shown until the next one is made', () {
      final declined = {
        'status': 'declined',
        'amount_kobo': 200000,
        'resolution_note': 'Bank name does not match',
      };
      expect(summaryOf({'last_closed_request': declined}).showDecline, isTrue);
      expect(
        summaryOf({
          'last_closed_request': declined,
          'open_request': {'id': 'r2', 'amount_kobo': 200000},
        }).showDecline,
        isFalse,
      );
    });

    test('nothing yet is not an error', () {
      final summary = PayoutSummary.fromJson(const {'minimum_kobo': 100000});
      expect(summary.openRequest, isNull);
      expect(summary.payouts, isEmpty);
    });
  });

  group('PayoutRequestPanel', () {
    testWidgets('ready, banked: one button, for the whole amount',
        (tester) async {
      final taps = await pumpPanel(tester,
          balance: balanceOf(425000), account: gtb);

      await tester.tap(find.text('Request NGN 4,250'));
      expect(taps.request, 1);
      expect(find.textContaining('Payouts start at'), findsNothing);
    });

    testWidgets('below the minimum: disabled, and says where it starts',
        (tester) async {
      final taps =
          await pumpPanel(tester, balance: balanceOf(50000), account: gtb);

      expect(find.text('Payouts start at NGN 1,000 ready.'), findsOneWidget);
      await tester.tap(find.text('Request payout'));
      expect(taps.request, 0);
    });

    testWidgets('no bank account: the only step is adding one',
        (tester) async {
      final taps = await pumpPanel(tester, balance: balanceOf(425000));

      expect(find.textContaining('Request'), findsNothing);
      await tester.tap(find.text('Add a bank account'));
      expect(taps.account, 1);
    });

    testWidgets('an open request can be cancelled, not repeated',
        (tester) async {
      final taps = await pumpPanel(
        tester,
        balance: balanceOf(425000),
        account: gtb,
        summary: summaryOf({
          'open_request': {
            'id': 'r1',
            'amount_kobo': 425000,
            'created_at': '2026-10-08T09:00:00',
          },
        }),
      );

      expect(find.textContaining('You asked for NGN 4,250 on 8 Oct 2026'),
          findsOneWidget);
      expect(find.textContaining('Request NGN'), findsNothing);
      await tester.tap(find.text('Cancel request'));
      expect(taps.cancel, 1);
    });

    testWidgets('a suspended teacher is told payouts are held',
        (tester) async {
      await pumpPanel(tester,
          balance: balanceOf(425000, held: true), account: gtb);

      expect(find.text('Payouts are on hold while your account is suspended.'),
          findsOneWidget);
      expect(find.textContaining('Request'), findsNothing);
    });

    testWidgets('a declined request shows its reason', (tester) async {
      await pumpPanel(
        tester,
        balance: balanceOf(425000),
        account: gtb,
        summary: summaryOf({
          'last_closed_request': {
            'status': 'declined',
            'amount_kobo': 200000,
            'resolution_note': 'Bank name does not match',
          },
        }),
      );

      expect(find.textContaining('was declined: Bank name does not match'),
          findsOneWidget);
      expect(find.text('Request NGN 4,250'), findsOneWidget,
          reason: 'they can ask again');
    });
  });

  test('formatDay', () {
    expect(formatDay(DateTime(2026, 10, 8)), '8 Oct 2026');
    expect(formatDay(DateTime(2027, 1, 31)), '31 Jan 2027');
  });
}
