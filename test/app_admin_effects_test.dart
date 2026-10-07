// What the main app shows of the back office's decisions (docs/ADMIN_PANEL.md,
// item 13). Each of these used to be invisible to the person affected: a
// teacher's taken-down course looked live, a suspended user met bare
// "row-level security" errors, and the earnings card ignored refunds and
// payouts.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:padi_learn/screens/components/suspension_frame.dart';
import 'package:padi_learn/screens/teacher/components/teacher_course_card.dart';
import 'package:padi_learn/services/suspension_service.dart';
import 'package:padi_learn/services/transaction_service.dart';
import 'package:padi_learn/utils/app_info.dart';

Widget phone(Widget child) => MediaQuery(
      data: const MediaQueryData(size: Size(393, 852)),
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (_, __) => MaterialApp(home: Scaffold(body: child)),
      ),
    );

void main() {
  group('TeacherBalance', () {
    test('earnings are net of refunds, and payable never goes negative', () {
      final balance = TeacherBalance.fromJson(const {
        'sales_count': 2,
        'earned_kobo': 625000,
        'clawback_kobo': 200000,
        'paid_out_kobo': 150000,
        'pending_kobo': 425000,
        'balance_kobo': 275000,
        'available_kobo': -150000,
        'payouts_held': false,
      });

      expect(balance.earned, 4250.0);
      expect(balance.paidOut, 1500.0);
      expect(balance.clearing, 4250.0);
      expect(balance.payable, 0,
          reason: 'a negative balance is recovered from later sales, not '
              'shown as money owed back');
    });

    test('a suspended teacher is told payouts are held', () {
      final balance = TeacherBalance.fromJson(const {'payouts_held': true});
      expect(balance.payoutsHeld, isTrue);
      expect(balance.earned, 0);
    });
  });

  group('CourseStatusChip', () {
    testWidgets('a taken-down course says so, even if also archived',
        (tester) async {
      await tester.pumpWidget(phone(const Column(children: [
        CourseStatusChip(archived: false),
        CourseStatusChip(archived: true),
        CourseStatusChip(archived: true, removed: true),
      ])));

      expect(find.text('Live'), findsOneWidget);
      expect(find.text('Archived'), findsOneWidget);
      expect(find.text('Taken down'), findsOneWidget);
    });
  });

  group('SuspensionFrame', () {
    testWidgets('explains a suspension above the screens, with the appeal',
        (tester) async {
      await tester.pumpWidget(phone(SuspensionFrame(
        load: () async =>
            const Suspension(reason: 'spam in comments', since: null),
        child: const Text('the app'),
      )));
      await tester.pumpAndSettle();

      expect(find.textContaining('Your account is suspended: spam in comments'),
          findsOneWidget);
      expect(find.textContaining(kSupportEmail), findsOneWidget);
      expect(find.text('the app'), findsOneWidget);
    });

    testWidgets('draws nothing extra for an account in good standing',
        (tester) async {
      await tester.pumpWidget(phone(SuspensionFrame(
        load: () async => null,
        child: const Text('the app'),
      )));
      await tester.pumpAndSettle();

      expect(find.textContaining('suspended'), findsNothing);
      expect(find.text('the app'), findsOneWidget);
    });
  });
}
