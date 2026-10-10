// The users screen. Suspending and changing a role change what a real person
// can do in the app, so these pin what each action sends and what the screen
// refuses to offer: an admin has no Suspend button, a suspended account has
// Lift instead, and a role change names the role (or null, to let them
// choose again).
//
// Fixtures follow the shape admin_user_detail() returned on the live project
// on 2026-10-07; the people in them are invented.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:padi_learn/admin/screens/users_screen.dart';

import 'admin_fakes.dart';

Map<String, dynamic> row(
  String id,
  String name, {
  String role = 'Student',
  bool admin = false,
  bool suspended = false,
  int courses = 0,
}) =>
    {
      'id': id,
      'name': name,
      'email': '${name.split(' ').first.toLowerCase()}@example.com',
      'role': role,
      'is_admin': admin,
      'created_at': '2026-10-01T09:00:00+00:00',
      'last_sign_in_at': '2026-10-07T07:00:00+00:00',
      'email_confirmed': true,
      'banned_until': null,
      'suspended': suspended,
      'course_count': courses,
      'enrollment_count': 0,
      'purchase_count': 0,
    };

Map<String, dynamic> detail(
  String id,
  String name, {
  String role = 'Student',
  bool admin = false,
  Map<String, dynamic>? suspension,
  List<Map<String, dynamic>> courses = const [],
  Map<String, dynamic>? balance,
  List<Map<String, dynamic>> enrollments = const [],
  List<Map<String, dynamic>> purchases = const [],
  List<Map<String, dynamic>> actions = const [],
}) =>
    {
      'id': id,
      'email': '${name.split(' ').first.toLowerCase()}@example.com',
      'name': name,
      'role': role,
      'profile_image_url': null,
      'is_admin': admin,
      'created_at': '2026-10-01T09:00:00+00:00',
      'last_sign_in_at': '2026-10-07T07:00:00+00:00',
      'email_confirmed_at': '2026-10-01T09:05:00+00:00',
      'banned_until': null,
      'suspension': suspension,
      'providers': ['email'],
      'verified_mfa_factors': admin ? 1 : 0,
      'courses': courses,
      'balance': balance,
      'payout_account': null,
      'enrollments': enrollments,
      'purchases': purchases,
      'reports_filed': 0,
      'reports_against': {'open': 0, 'total': 0},
      'admin_actions': actions,
    };

FakeAdminApi directory() => FakeAdminApi()
  ..users = [
    row('t1', 'Ada Teacher', role: 'Teacher', courses: 2),
    row('s1', 'Bola Student', suspended: true),
    row('a1', 'PadiLearn Admin', admin: true),
  ]
  ..userDetails = {
    't1': detail(
      't1',
      'Ada Teacher',
      role: 'Teacher',
      courses: [
        {
          'id': 'c1',
          'title': 'Excel for Small Businesses',
          'price': 5000,
          'enrollments': 2,
          'created_at': '2026-10-02T09:00:00+00:00',
          'archived_at': null,
          'removed_at': null,
          'removed_reason': null,
        },
        {
          'id': 'c2',
          'title': 'An Old Course',
          'price': 0,
          'enrollments': 0,
          'created_at': '2026-10-01T09:00:00+00:00',
          'archived_at': '2026-10-03T09:00:00+00:00',
          'removed_at': null,
          'removed_reason': null,
        },
        // As admin_user_detail() returns a draft since 20261010000001. The
        // two above are from before it and carry no `published_at` at all.
        {
          'id': 'c3',
          'title': 'Half-Written Course',
          'price': null,
          'enrollments': 0,
          'created_at': '2026-10-09T09:00:00+00:00',
          'published_at': null,
          'archived_at': null,
          'removed_at': null,
          'removed_reason': null,
        },
      ],
      balance: {
        'sales_count': 1,
        'earned_kobo': 425000,
        'clawback_kobo': 0,
        'paid_out_kobo': 0,
        'balance_kobo': 425000,
        'pending_kobo': 425000,
        'available_kobo': 0,
      },
    ),
    's1': detail(
      's1',
      'Bola Student',
      suspension: {
        'reason': 'spam in comments',
        'suspended_at': '2026-10-07T08:00:00+00:00',
        'suspended_by': 'a1',
      },
      enrollments: [
        {
          'course_id': 'c1',
          'title': 'Excel for Small Businesses',
          'is_free': false,
          'progress': 40,
          'enrolled_at': '2026-10-06T16:07:00+00:00',
        },
      ],
      purchases: [
        {
          'transaction_id': 'tx1',
          'reference': 'T123',
          'course_id': 'c1',
          'course_title': 'Excel for Small Businesses',
          'amount_kobo': 517767,
          'status': 'success',
          'paid_at': '2026-10-06T16:06:48+00:00',
          'refunded': false,
        },
      ],
      actions: [
        {
          'action': 'user.suspend',
          'reason': 'spam in comments',
          'details': {'role': 'Student', 'courses_hidden': 0},
          'admin_id': 'a1',
          'created_at': '2026-10-07T08:00:00+00:00',
        },
      ],
    ),
    'a1': detail('a1', 'PadiLearn Admin', admin: true),
  };

Future<void> openAccount(WidgetTester tester, String name) async {
  await tester.tap(find.text(name).first);
  await tester.pumpAndSettle();
}

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
  testWidgets('lists accounts with what matters at a glance, and searches',
      (tester) async {
    final api = directory();
    await pumpAdminScreen(tester, UsersScreen(api: api));

    expect(tester.takeException(), isNull);
    expect(find.text('Ada Teacher'), findsOneWidget);
    expect(find.text('Admin'), findsOneWidget);
    expect(find.text('Suspended'), findsOneWidget);
    expect(find.text('Choose an account.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'ada');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(api.calls, contains('searchUsers:ada'));
  });

  testWidgets("a teacher's detail shows their courses and balance",
      (tester) async {
    await pumpAdminScreen(tester, UsersScreen(api: directory()));
    await openAccount(tester, 'Ada Teacher');

    expect(tester.takeException(), isNull);
    expect(find.text('Excel for Small Businesses (live)'), findsOneWidget);
    expect(find.text('An Old Course (archived)'), findsOneWidget);
    expect(find.text('Half-Written Course (draft)'), findsOneWidget);
    expect(find.text('NGN 4,250.00'), findsWidgets);
    expect(find.text('Suspend'), findsOneWidget);
  });

  testWidgets('suspending sends the reason and says what left the catalogue',
      (tester) async {
    final api = directory()..suspendResult = const {'courses_hidden': 2};
    await pumpAdminScreen(tester, UsersScreen(api: api));
    await openAccount(tester, 'Ada Teacher');

    await tester.tap(find.text('Suspend'));
    await tester.pumpAndSettle();
    await giveReason(tester, 'Suspend', 'selling stolen courses');

    expect(api.calls, contains('suspendUser:t1:selling stolen courses'));
    expect(find.text('Suspended. 2 courses left the catalogue.'),
        findsOneWidget);
    expect(api.count('userDetail:t1'), 2, reason: 'detail reloaded');
    expect(api.count('searchUsers'), 2, reason: 'list badges reloaded');
  });

  testWidgets('a suspended account offers Lift, with its reason on show',
      (tester) async {
    final api = directory();
    await pumpAdminScreen(tester, UsersScreen(api: api));
    await openAccount(tester, 'Bola Student');

    expect(find.textContaining('Suspended since'), findsOneWidget);
    expect(find.text('Suspend'), findsNothing);
    expect(find.text('NGN 5,177.67'), findsOneWidget);
    expect(find.textContaining('Suspended, '), findsOneWidget,
        reason: 'the suspension is in their admin history');

    await tester.tap(find.text('Lift suspension'));
    await tester.pumpAndSettle();
    await giveReason(tester, 'Lift suspension', 'appeal upheld');

    expect(api.calls, contains('liftSuspension:s1:appeal upheld'));
  });

  testWidgets('an admin cannot be suspended from here', (tester) async {
    await pumpAdminScreen(tester, UsersScreen(api: directory()));
    await openAccount(tester, 'PadiLearn Admin');

    expect(find.text('Admins cannot be suspended.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Suspend'), findsNothing);
  });

  testWidgets('changing a role names the role, or null to let them choose',
      (tester) async {
    final api = directory();
    await pumpAdminScreen(tester, UsersScreen(api: api));
    await openAccount(tester, 'Ada Teacher');

    await tester.tap(find.widgetWithText(OutlinedButton, 'Change role'));
    await tester.pumpAndSettle();

    final confirm = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, 'Change role'),
    );
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull,
        reason: 'no role or reason chosen yet');

    await tester.tap(find.text('Let them choose'));
    await tester.pump();
    await giveReason(tester, 'Change role', 'picked the wrong role');

    expect(api.calls, contains('setRole:t1:null:picked the wrong role'));
  });

  testWidgets("the database's refusal is shown when a teacher owns courses",
      (tester) async {
    final api = directory()
      ..actionError = const PostgrestException(
        message: 'This teacher owns 2 course(s), which a student account '
            'cannot manage',
        code: '22023',
      );
    await pumpAdminScreen(tester, UsersScreen(api: api));
    await openAccount(tester, 'Ada Teacher');

    await tester.tap(find.widgetWithText(OutlinedButton, 'Change role'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Student'),
    ));
    await tester.pump();
    await giveReason(tester, 'Change role', 'asked to switch');

    expect(api.calls, contains('setRole:t1:Student:asked to switch'));
    expect(find.textContaining('owns 2 course(s)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('on a narrow window an account opens as its own page',
      (tester) async {
    tester.view.physicalSize = const Size(700, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: UsersScreen(api: directory()))));
    await tester.pumpAndSettle();

    expect(find.text('Choose an account.'), findsNothing);
    await openAccount(tester, 'Ada Teacher');
    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Excel for Small Businesses (live)'), findsOneWidget);
  });
}
