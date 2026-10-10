// The courses screen keeps the teacher's "archived" apart from PadiLearn's
// "taken down", because only the second is an admin's to undo. These pin that
// distinction, the filters, and what take down and restore send.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:padi_learn/admin/screens/courses_screen.dart';

import 'admin_fakes.dart';

Map<String, dynamic> course(
  String id,
  String title, {
  String owner = 'Ada Teacher',
  num price = 0,
  String? archivedAt,
  String? removedAt,
  String? removedReason,
  String? publishedAt = '2026-10-02T09:00:00+00:00',
}) =>
    {
      'id': id,
      'title': title,
      'price': price,
      'category': 'Business',
      'user_id': 'u-$owner',
      'owner_name': owner,
      'enrollments': 2,
      'created_at': '2026-10-02T09:00:00+00:00',
      'published_at': publishedAt,
      'archived_at': archivedAt,
      'removed_at': removedAt,
      'removed_reason': removedReason,
    };

FakeAdminApi catalogue() => FakeAdminApi(
      removeCourseResult: const {
        'paid_sales': 1,
        'paid_kobo': 517767,
        'closed_reports': 0,
      },
    )..courseRows = [
        course('c1', 'Excel for Small Businesses', price: 5000),
        course('c2', 'Bookkeeping Basics',
            archivedAt: '2026-10-03T09:00:00+00:00'),
        course('c3', 'Photoshop Basics',
            owner: 'Chidi',
            removedAt: '2026-10-05T09:00:00+00:00',
            removedReason: 'copyright: Adobe tutorial'),
      ];

Future<void> giveReason(WidgetTester tester, String confirm, String reason) async {
  await tester.enterText(
    find.descendant(
        of: find.byType(AlertDialog), matching: find.byType(TextField)),
    reason,
  );
  await tester.pump();
  await tester.tap(find.descendant(
    of: find.byType(AlertDialog),
    matching: find.widgetWithText(FilledButton, confirm),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('counts and filters by state, keeping archived apart',
      (tester) async {
    await pumpAdminScreen(tester, CoursesScreen(api: catalogue()));

    expect(tester.takeException(), isNull);
    expect(find.text('All 3'), findsOneWidget);
    expect(find.text('Live 1'), findsOneWidget);
    expect(find.text('Archived 1'), findsOneWidget);
    expect(find.text('Taken down 1'), findsOneWidget);
    expect(find.text('Archived by teacher'), findsOneWidget);
    expect(find.textContaining('copyright: Adobe tutorial'), findsOneWidget);

    await tester.tap(find.text('Taken down 1'));
    await tester.pumpAndSettle();
    expect(find.text('Photoshop Basics'), findsOneWidget);
    expect(find.text('Excel for Small Businesses'), findsNothing);
  });

  testWidgets('a draft is listed and labelled, and never counted as live',
      (tester) async {
    final api = catalogue()
      ..courseRows.add(
          course('c4', 'Half-Written Course', owner: 'Chidi', publishedAt: null))
      // Archived by hand before it was ever uploaded: still a draft.
      ..courseRows.add(course('c5', 'Shelved Draft',
          publishedAt: null, archivedAt: '2026-10-04T09:00:00+00:00'));
    await pumpAdminScreen(tester, CoursesScreen(api: api));

    expect(tester.takeException(), isNull);
    expect(find.text('All 5'), findsOneWidget);
    expect(find.text('Live 1'), findsOneWidget);
    expect(find.text('Drafts 2'), findsOneWidget);
    expect(find.text('Archived 1'), findsOneWidget);
    expect(find.text('Taken down 1'), findsOneWidget);
    expect(find.text('Draft, not uploaded'), findsNWidgets(2));

    await tester.tap(find.text('Drafts 2'));
    await tester.pumpAndSettle();
    expect(find.text('Half-Written Course'), findsOneWidget);
    expect(find.text('Shelved Draft'), findsOneWidget);
    expect(find.text('Excel for Small Businesses'), findsNothing);

    await tester.tap(find.text('Live 1'));
    await tester.pumpAndSettle();
    expect(find.text('Half-Written Course'), findsNothing);
    expect(find.text('Excel for Small Businesses'), findsOneWidget);
  });

  testWidgets('a row from before drafts existed still reads as live',
      (tester) async {
    final api = FakeAdminApi()
      ..courseRows = [
        course('c1', 'Excel for Small Businesses')..remove('published_at'),
      ];
    await pumpAdminScreen(tester, CoursesScreen(api: api));

    expect(find.text('Live 1'), findsOneWidget);
    expect(find.text('Drafts 0'), findsOneWidget);
  });

  testWidgets('search matches the teacher as well as the title',
      (tester) async {
    await pumpAdminScreen(tester, CoursesScreen(api: catalogue()));

    await tester.enterText(find.byType(TextField), 'chidi');
    await tester.pumpAndSettle();
    expect(find.text('Photoshop Basics'), findsOneWidget);
    expect(find.text('Bookkeeping Basics'), findsNothing);
  });

  testWidgets('taking a course down sends the reason and names the refunds',
      (tester) async {
    final api = catalogue();
    await pumpAdminScreen(tester, CoursesScreen(api: api));

    await tester.tap(find.widgetWithText(OutlinedButton, 'Take down').first);
    await tester.pumpAndSettle();
    await giveReason(tester, 'Take course down', 'teacher asked us to');

    expect(api.calls, contains('removeCourse:c1:teacher asked us to'));
    expect(find.textContaining('1 paid sale, NGN 5,177.67, now owed refunds'),
        findsOneWidget);
    expect(api.count('courses'), 2, reason: 'reloaded after acting');
  });

  testWidgets('only a taken-down course can be restored', (tester) async {
    final api = catalogue();
    await pumpAdminScreen(tester, CoursesScreen(api: api));

    expect(find.widgetWithText(FilledButton, 'Restore'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Restore'));
    await tester.pumpAndSettle();
    await giveReason(tester, 'Restore', 'appeal upheld');

    expect(api.calls, contains('restoreCourse:c3:appeal upheld'));
    expect(find.text('Course restored.'), findsOneWidget);
  });
}
