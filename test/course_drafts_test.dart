// Course drafts, the half that needs no server: what counts as a draft, what
// one still needs before it can be uploaded, and the widgets that say so.
//
// The rules themselves live in the database
// (supabase/migrations/20261010000001_course_drafts.sql), which was run
// against a local copy of the live schema; the 10 October 2026 entry in
// docs/DEVLOG.md lists what that covered. These pin the app's copy of the
// same list and sentences, so the checklist a teacher reads and the refusal
// the database gives cannot drift apart unnoticed.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import 'package:padi_learn/screens/components/primary_button.dart';
import 'package:padi_learn/screens/teacher/components/course_submit_buttons.dart';
import 'package:padi_learn/screens/teacher/components/draft_panel.dart';
import 'package:padi_learn/screens/teacher/components/teacher_course_card.dart';
import 'package:padi_learn/services/course_service.dart';
import 'package:padi_learn/services/lesson_service.dart';

Widget phone(Widget child) => MediaQuery(
      data: const MediaQueryData(size: Size(393, 852)),
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (_, __) => MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    );

Lesson lesson({String? video}) => Lesson(
      id: 'l1',
      courseId: 'c1',
      title: 'Lesson 1',
      position: 1,
      videoPath: video,
      durationSeconds: null,
      isPreview: false,
    );

/// A draft as "Save to drafts" writes it from a form with only a title.
Map<String, dynamic> bareDraft() => {
      'id': 'c1',
      'title': 'Excel for Small Businesses',
      'description': null,
      'author': null,
      'category': null,
      'price': null,
      'thumbnail_url': null,
      'published_at': null,
      'archived_at': null,
      'removed_at': null,
      'enrollments': 0,
    };

Map<String, dynamic> finishedDraft() => {
      ...bareDraft(),
      'description': 'Formulas, tables and a monthly cash book.',
      'author': 'Ada Teacher',
      'category': 'Business',
      'price': 0,
      'thumbnail_url': 'https://example.test/cover.png',
    };

void main() {
  group('isDraftCourse', () {
    test('a null published_at is a draft', () {
      expect(isDraftCourse(bareDraft()), isTrue);
    });

    test('a course that has been uploaded is not', () {
      expect(
        isDraftCourse(
            {...bareDraft(), 'published_at': '2026-10-10T09:00:00+00:00'}),
        isFalse,
      );
    });

    test('a row read without the column is not: every course was live before',
        () {
      expect(
          isDraftCourse({'id': 'c1', 'title': 'From before drafts'}), isFalse);
    });
  });

  group('publishGaps', () {
    test('a draft with only a title is told everything, in the form\'s order',
        () {
      expect(publishGaps(bareDraft(), const []), [
        'a description',
        'an author name',
        'a category',
        'a price',
        'a cover image',
        'a lesson with a video',
      ]);
    });

    test('a finished draft with a video lesson has none', () {
      expect(publishGaps(finishedDraft(), [lesson(video: 'u/videos/a.mp4')]),
          isEmpty);
    });

    test('a lesson without a video does not count', () {
      expect(
          publishGaps(finishedDraft(), [lesson()]), ['a lesson with a video']);
    });

    test('blank text is as missing as none', () {
      expect(
        publishGaps({...finishedDraft(), 'description': '   ', 'author': ''},
            [lesson(video: 'u/videos/a.mp4')]),
        ['a description', 'an author name'],
      );
    });

    test('free is a price; no price is not', () {
      final lessons = [lesson(video: 'u/videos/a.mp4')];
      expect(publishGaps({...finishedDraft(), 'price': 0}, lessons), isEmpty);
      expect(publishGaps({...finishedDraft(), 'price': null}, lessons),
          ['a price']);
    });

    test('the sentence is the one the database raises', () {
      // Word for word what publish_course() raised on the local copy.
      expect(
        publishGapsMessage(publishGaps(bareDraft(), [lesson()])),
        'This course cannot be uploaded yet. It still needs a description, '
        'an author name, a category, a price, a cover image and a lesson '
        'with a video.',
      );
      expect(publishGapsMessage(const ['a description']),
          'This course cannot be uploaded yet. It still needs a description.');
    });
  });

  group('what a refusal says', () {
    test('the draft limit is worded as the database words it', () {
      expect(kMaxCourseDrafts, 3);
      expect(kDraftLimitMessage,
          'You already have 3 drafts. Upload or delete one before saving another.');
    });

    test('a rule the database raised is shown as it is', () {
      const refusal = PostgrestException(
        message:
            'You already have 3 drafts. Upload or delete one before saving another.',
        code: '22023',
      );
      expect(courseErrorMessage(refusal, fallback: 'Could not save the draft'),
          kDraftLimitMessage);
    });

    test('anything else keeps what was being attempted in front', () {
      const rls = PostgrestException(
        message: 'new row violates row-level security policy',
        code: '42501',
      );
      expect(
        courseErrorMessage(rls, fallback: 'Could not save the draft'),
        'Could not save the draft: new row violates row-level security policy',
      );
      expect(
        courseErrorMessage(Exception('offline'),
            fallback: 'Failed to create course'),
        'Failed to create course: offline',
      );
    });
  });

  group('the two buttons on the create screen', () {
    testWidgets('sit side by side, and each does its own thing',
        (tester) async {
      var drafts = 0, uploads = 0;
      await tester.pumpWidget(phone(Padding(
        padding: const EdgeInsets.all(16),
        child: CourseSubmitButtons(
          onSaveDraft: () => drafts++,
          onUpload: () => uploads++,
        ),
      )));

      expect(tester.takeException(), isNull);
      final draft = find.widgetWithText(SecondaryButton, 'Save to drafts');
      final upload = find.widgetWithText(PrimaryButton, 'Upload');
      expect(draft, findsOneWidget);
      expect(upload, findsOneWidget);
      expect(find.text('Create course'), findsNothing);

      // Beside each other, drafts first, level.
      expect(tester.getCenter(draft).dy, tester.getCenter(upload).dy);
      expect(tester.getCenter(draft).dx, lessThan(tester.getCenter(upload).dx));

      await tester.tap(draft);
      expect((drafts, uploads), (1, 0));
      await tester.tap(upload);
      expect((drafts, uploads), (1, 1));
    });

    testWidgets('both grey out while a chosen video is still being read',
        (tester) async {
      await tester.pumpWidget(phone(const CourseSubmitButtons(
        onSaveDraft: null,
        onUpload: null,
      )));

      expect(
          tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
          isNull);
      expect(
          tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
          isNull);
    });

    testWidgets('fit a narrow phone without overflowing', (tester) async {
      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(size: Size(320, 640)),
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          builder: (_, __) => MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: CourseSubmitButtons(onSaveDraft: () {}, onUpload: () {}),
              ),
            ),
          ),
        ),
      ));

      expect(tester.takeException(), isNull);
      expect(find.text('Save to drafts'), findsOneWidget);
    });
  });

  group('a draft\'s own screen', () {
    testWidgets('lists what is missing, and Upload still answers a tap',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(phone(DraftPanel(
        gaps: publishGaps(bareDraft(), const []),
        busy: false,
        onUpload: () => taps++,
      )));

      expect(tester.takeException(), isNull);
      expect(find.text('This course is a draft'), findsOneWidget);
      expect(find.textContaining('Only you can see it'), findsOneWidget);
      expect(find.text('A description'), findsOneWidget);
      expect(find.text('A cover image'), findsOneWidget);
      expect(find.text('A lesson with a video'), findsOneWidget);

      // Tapping is how a teacher asks why not; the screen answers. With six
      // things listed the button sits below the test window, as it sits below
      // the fold on a phone.
      final upload = find.widgetWithText(PrimaryButton, 'Upload');
      await tester.ensureVisible(upload);
      await tester.pumpAndSettle();
      await tester.tap(upload);
      expect(taps, 1);
    });

    testWidgets('says so when nothing is missing', (tester) async {
      await tester.pumpWidget(phone(DraftPanel(
        gaps: const [],
        busy: false,
        onUpload: () {},
      )));

      expect(find.text('Everything it needs is here.'), findsOneWidget);
      expect(find.textContaining('Still needed'), findsNothing);
    });

    testWidgets('cannot be tapped twice while the upload is going through',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(phone(DraftPanel(
        gaps: const [],
        busy: true,
        onUpload: () => taps++,
      )));

      await tester.tap(find.byType(ElevatedButton), warnIfMissed: false);
      expect(taps, 0);
    });
  });

  group('a draft in the teacher\'s list', () {
    testWidgets('wears the badge, and shows no students or price it lacks',
        (tester) async {
      await tester.pumpWidget(phone(Padding(
        padding: const EdgeInsets.all(16),
        child: TeacherCourseCard(course: bareDraft(), onTap: () {}),
      )));

      expect(tester.takeException(), isNull);
      expect(find.text('Draft'), findsOneWidget);
      expect(find.text('No price yet'), findsOneWidget);
      expect(find.text('Free'), findsNothing,
          reason: 'free is a decision the teacher has not made');
      expect(
          find.text('Not uploaded yet. Only you can see it.'), findsOneWidget);
      expect(find.byIcon(Icons.people_outline), findsNothing);
    });

    testWidgets('a live course looks as it always did', (tester) async {
      await tester.pumpWidget(phone(Padding(
        padding: const EdgeInsets.all(16),
        child: TeacherCourseCard(
          course: {
            ...finishedDraft(),
            'published_at': '2026-10-10T09:00:00+00:00',
            'enrollments': 4,
          },
          onTap: () {},
        ),
      )));

      expect(find.text('Draft'), findsNothing);
      expect(find.text('Free'), findsOneWidget);
      expect(find.byIcon(Icons.people_outline), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('taken down outranks draft, and draft outranks archived',
        (tester) async {
      await tester.pumpWidget(phone(const Column(children: [
        CourseStatusChip(archived: false, draft: true),
        CourseStatusChip(archived: true, draft: true),
        CourseStatusChip(archived: false, draft: true, removed: true),
      ])));

      expect(find.text('Draft'), findsNWidgets(2));
      expect(find.text('Archived'), findsNothing);
      expect(find.text('Taken down'), findsOneWidget);
    });
  });
}
