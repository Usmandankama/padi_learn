// Categories: a suggestion waits until approved, a rename carries its courses
// with it, and deleting a category that courses use must say where they go.
// These pin what each action sends, and that the delete cannot be confirmed
// without a destination while any course would be left without a category.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:padi_learn/admin/screens/categories_screen.dart';

import 'admin_fakes.dart';

Map<String, dynamic> category(
  String id,
  String name, {
  bool active = true,
  int position = 10,
  int courses = 0,
  String? suggestedBy,
}) =>
    {
      'id': id,
      'name': name,
      'position': position,
      'is_active': active,
      'suggested_by': suggestedBy == null ? null : 'u-$suggestedBy',
      'suggested_by_name': suggestedBy,
      'created_at': '2026-10-01T09:00:00+00:00',
      'course_count': courses,
    };

/// The live list's shape on 2026-10-07: one suggestion, "Philosophy", waiting.
FakeAdminApi shelf() => FakeAdminApi()
  ..categoryRows = [
    category('k0', 'Philosophy',
        active: false, position: 900, suggestedBy: 'Ada Teacher'),
    category('k1', 'Exam Prep', position: 10, courses: 3),
    category('k2', 'Programming', position: 20, courses: 1),
  ];

void main() {
  testWidgets('a waiting suggestion is shown apart, with who suggested it',
      (tester) async {
    await pumpAdminScreen(tester, CategoriesScreen(api: shelf()));

    expect(tester.takeException(), isNull);
    expect(find.text('Not in the app (1)'), findsOneWidget);
    expect(find.text('In the app (2)'), findsOneWidget);
    expect(find.textContaining('suggested by Ada Teacher'), findsOneWidget);
  });

  testWidgets('approving is one click', (tester) async {
    final api = shelf();
    await pumpAdminScreen(tester, CategoriesScreen(api: api));

    await tester.tap(find.widgetWithText(FilledButton, 'Approve'));
    await tester.pumpAndSettle();

    expect(api.calls, contains('setCategoryActive:k0:true'));
    expect(find.text('"Philosophy" is now in the app.'), findsOneWidget);
  });

  testWidgets('deleting a category in use needs somewhere to move its courses',
      (tester) async {
    final api = shelf();
    await pumpAdminScreen(tester, CategoriesScreen(api: api));

    // The delete button on "Exam Prep", which three courses use.
    await tester.tap(find.byTooltip('Delete or merge').at(1));
    await tester.pumpAndSettle();

    final confirm = find.widgetWithText(FilledButton, 'Merge and delete');
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull,
        reason: 'no destination chosen yet');

    await tester.tap(find.text('Move its courses to…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Programming').last);
    await tester.pumpAndSettle();
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(api.calls, contains('deleteCategory:k1:k2'));
  });

  testWidgets('a rename sends only the name', (tester) async {
    final api = shelf();
    await pumpAdminScreen(tester, CategoriesScreen(api: api));

    await tester.tap(find.byTooltip('Rename or reorder').at(2));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
          of: find.byType(AlertDialog), matching: find.byType(TextField))
          .first,
      'Coding',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(api.calls, contains('updateCategory:k2:Coding:null'));
  });

  testWidgets("the database's duplicate check is shown", (tester) async {
    final api = shelf()
      ..actionError = const PostgrestException(
        message: 'A category named "Philosophy" already exists; merge this '
            'one into it instead',
        code: '22023',
      );
    await pumpAdminScreen(tester, CategoriesScreen(api: api));

    await tester.tap(find.widgetWithText(FilledButton, 'Approve'));
    await tester.pumpAndSettle();

    expect(find.textContaining('merge this one into it instead'),
        findsOneWidget);
  });
}
