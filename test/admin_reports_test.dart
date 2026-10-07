// The reports queue. Every action here changes what other people can see, so
// the tests pin down what each button sends: the right function, the right
// id, the reason the admin typed, and nothing at all when they back out.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:padi_learn/admin/screens/reports_screen.dart';

import 'admin_fakes.dart';

Map<String, dynamic> commentReport() => {
      'id': 'r1',
      'status': 'open',
      'reason': 'harassment',
      'details': 'Keeps posting this under every lesson',
      'created_at': '2026-10-07T08:00:00+00:00',
      'target_type': 'comment',
      'course_id': 'c1',
      'course_title': 'Excel for Small Businesses',
      'course_removed_at': null,
      'comment_id': 'cm1',
      'comment_exists': true,
      'target_excerpt': 'nobody should pay for this rubbish',
      'current_body': 'nobody should pay for this rubbish, the teacher is a fraud',
      'target_owner_id': 'u-ada',
      'owner_name': 'Ada',
      'reporter_id': 'u-bola',
      'reporter_name': 'Bola',
      'open_reports_on_target': 2,
      'resolved_at': null,
      'resolved_by': null,
      'resolved_by_name': null,
      'resolution_note': null,
    };

Map<String, dynamic> courseReport() => {
      'id': 'r2',
      'status': 'open',
      'reason': 'copyright',
      'details': null,
      'created_at': '2026-10-07T09:00:00+00:00',
      'target_type': 'course',
      'course_id': 'c2',
      'course_title': 'Photoshop Basics',
      'course_removed_at': null,
      'comment_id': null,
      'comment_exists': false,
      'target_excerpt': 'Photoshop Basics',
      'current_body': 'Photoshop Basics',
      'target_owner_id': 'u-chidi',
      'owner_name': 'Chidi',
      'reporter_id': 'u-bola',
      'reporter_name': 'Bola',
      'open_reports_on_target': 1,
      'resolved_at': null,
      'resolved_by': null,
      'resolved_by_name': null,
      'resolution_note': null,
    };

Map<String, dynamic> resolvedReport() => {
      ...commentReport(),
      'id': 'r3',
      'status': 'actioned',
      'comment_exists': false,
      'current_body': null,
      'open_reports_on_target': 0,
      'resolved_at': '2026-10-07T10:00:00+00:00',
      'resolved_by': 'u-admin',
      'resolved_by_name': 'PadiLearn Admin',
      'resolution_note': 'abusive',
    };

FakeAdminApi queue({
  Map<String, dynamic> removeCourseResult = const {
    'paid_sales': 0,
    'paid_kobo': 0,
    'closed_reports': 1,
  },
}) =>
    FakeAdminApi(
      reports: {
        'open': [commentReport(), courseReport()],
        'actioned': [resolvedReport()],
      },
      removeCourseResult: removeCourseResult,
    );

/// Types [reason] into the open reason dialog and presses its confirm button.
Future<void> giveReason(WidgetTester tester, String confirm, String reason) async {
  await tester.enterText(find.byType(TextField), reason);
  await tester.pump();
  await tester.tap(find.descendant(
    of: find.byType(AlertDialog),
    matching: find.widgetWithText(FilledButton, confirm),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the open queue shows what was reported and what it says now',
      (tester) async {
    await pumpAdminScreen(tester, ReportsScreen(api: queue()));

    expect(tester.takeException(), isNull);
    expect(find.text('Harassment or bullying'), findsOneWidget);
    expect(find.text('Copied or stolen content'), findsOneWidget);
    expect(find.text('2 open reports on this'), findsOneWidget);
    // The comment changed after it was reported; both versions are shown.
    expect(find.text('NOW READS'), findsOneWidget);
    expect(find.text('Delete comment'), findsOneWidget);
    expect(find.text('Take course down'), findsOneWidget);
  });

  testWidgets('deleting a comment needs a reason, then sends it and reloads',
      (tester) async {
    final api = queue();
    await pumpAdminScreen(tester, ReportsScreen(api: api));

    await tester.tap(find.text('Delete comment'));
    await tester.pumpAndSettle();

    final confirm = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, 'Delete comment'),
    );
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull,
        reason: 'no reason typed yet');

    await giveReason(tester, 'Delete comment', 'abusive to the teacher');

    expect(api.calls, contains('deleteComment:cm1:abusive to the teacher'));
    expect(find.text('Comment deleted. 2 reports closed.'), findsOneWidget);
    expect(api.count('reports:open'), 2, reason: 'reloaded after acting');
  });

  testWidgets('taking a course down says what refunds it created',
      (tester) async {
    final api = queue(removeCourseResult: const {
      'paid_sales': 1,
      'paid_kobo': 517767,
      'closed_reports': 1,
    });
    await pumpAdminScreen(tester, ReportsScreen(api: api));

    await tester.tap(find.text('Take course down'));
    await tester.pumpAndSettle();
    await giveReason(tester, 'Take course down', 'copyright: Adobe tutorial');

    expect(api.calls, contains('removeCourse:c2:copyright: Adobe tutorial'));
    expect(find.textContaining('1 paid sale, NGN 5,177.67, now owed refunds'),
        findsOneWidget);
  });

  testWidgets('backing out sends nothing', (tester) async {
    final api = queue();
    await pumpAdminScreen(tester, ReportsScreen(api: api));

    await tester.tap(find.text('Dismiss').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(api.count('setReportStatus'), 0);
  });

  testWidgets('a resolved report shows who resolved it, and can be reopened',
      (tester) async {
    final api = queue();
    await pumpAdminScreen(tester, ReportsScreen(api: api));

    await tester.tap(find.text('Dealt with'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Dealt with by PadiLearn Admin'), findsOneWidget);
    expect(find.text('Delete comment'), findsNothing);

    await tester.tap(find.text('Reopen'));
    await tester.pumpAndSettle();
    await giveReason(tester, 'Reopen', 'closed by mistake');

    expect(api.calls, contains('setReportStatus:r3:open:closed by mistake'));
  });

  testWidgets("a refusal from the database is shown, not swallowed",
      (tester) async {
    final api = queue()
      ..actionError = const PostgrestException(
        message: 'Course is already removed',
        code: '22023',
      );
    await pumpAdminScreen(tester, ReportsScreen(api: api));

    await tester.tap(find.text('Take course down'));
    await tester.pumpAndSettle();
    await giveReason(tester, 'Take course down', 'copyright');

    expect(find.text('Course is already removed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
