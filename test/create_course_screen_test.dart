// The create-course screen itself, pumped whole.
//
// On 10 October 2026 "Save to drafts" worked in the Android app and did
// nothing in a browser: no message, no request. The form was a ListView, which
// builds lazily and discards what scrolls out of view, and the draft check
// asked the title *field* whether it was filled in. By the time the buttons at
// the bottom are on screen the title field is a screen or two above them and
// gone, so the check came back empty and the tap returned in silence. It only
// worked when the title still had the keyboard's focus, which keeps a field
// alive. These pin that both buttons always answer, wherever the form has been
// scrolled to.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:padi_learn/screens/components/primary_button.dart';
import 'package:padi_learn/screens/teacher/create_course_screen.dart';

Future<void> pumpCreateScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(ScreenUtilInit(
    designSize: const Size(393, 852),
    builder: (_, __) => const MaterialApp(home: CreateCourseScreen()),
  ));
  await tester.pump();
}

/// Leaves the title field (so nothing holds it on screen) and scrolls to the
/// two buttons, as someone filling the form in from the top does.
Future<void> scrollToButtons(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
  await tester.dragUntilVisible(
    find.text('Save to drafts'),
    find.byType(Scrollable).first,
    const Offset(0, -300),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    // Nobody is signed in and nothing answers at this address. That is the
    // point: once a button gets past its own checks, the first thing the
    // screen does is notice there is no session, and say so.
    await Supabase.initialize(
      url: 'http://127.0.0.1:9',
      publishableKey: 'test-key',
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        detectSessionInUri: false,
        autoRefreshToken: false,
      ),
    );
  });

  testWidgets('"Save to drafts" answers after the title has scrolled away',
      (tester) async {
    await pumpCreateScreen(tester);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Course title'), 'Excel basics');
    await scrollToButtons(tester);

    await tester.tap(find.widgetWithText(SecondaryButton, 'Save to drafts'));
    await tester.pump();

    // Past the title check and on to the save, which finds no session.
    expect(find.text('Your session expired. Please sign in again.'),
        findsOneWidget);
  });

  testWidgets('with no title it says so, instead of doing nothing',
      (tester) async {
    await pumpCreateScreen(tester);
    await scrollToButtons(tester);

    await tester.tap(find.widgetWithText(SecondaryButton, 'Save to drafts'));
    await tester.pump();

    expect(find.text('Give the course a title before saving it to drafts.'),
        findsOneWidget);
    expect(
        find.text('Your session expired. Please sign in again.'), findsNothing);
  });

  testWidgets('"Upload" still checks the fields that have scrolled away',
      (tester) async {
    await pumpCreateScreen(tester);
    await scrollToButtons(tester);

    await tester.tap(find.widgetWithText(PrimaryButton, 'Upload'));
    await tester.pump();

    expect(
        find.text('Some details are missing. Check the fields marked in red.'),
        findsOneWidget);
    // The title is the first thing wrong, a long way above the button, and
    // it is marked.
    expect(find.text('Please enter a course title', skipOffstage: false),
        findsOneWidget);
  });
}
