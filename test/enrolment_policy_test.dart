// Until 10 October 2026 the database refused every free enrolment, and no
// test could have noticed: the row-level security policy that lets a student
// enrol reads `courses`, and the policy that decides who sees a course read
// `enrollments` back. Postgres refuses a statement whose policies lead back
// to the table it started from ("infinite recursion detected in policy"),
// whatever the rows are.
//
// 20261010000002 took the read of `enrollments` out of the `courses` policy
// and put it behind `private.my_enrolled_course_ids()`. The way the bug
// survived five migrations is that each one recreated the policy by copying
// the previous text. This reads the migrations as the next author would and
// fails if the newest text of any policy on `courses` reads `enrollments`
// again.
//
// It checks the repo, not the live database: a migration only takes effect
// once it has been run in the SQL editor.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The newest text of every policy on [table], by policy name, going through
/// the migrations in the order they are run.
Map<String, String> newestPolicies(String table) {
  final files = Directory('supabase/migrations')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.sql'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  final statement = RegExp(
    r'\b(?:create|alter)\s+policy\s+("[^"]+"|\w+)\s+on\s+public\.' +
        table +
        r'\b[^;]*;',
    caseSensitive: false,
  );

  final newest = <String, String>{};
  for (final file in files) {
    final sql = file
        .readAsLinesSync()
        .map((line) => line.replaceFirst(RegExp(r'--.*$'), ''))
        .join('\n');
    for (final match in statement.allMatches(sql)) {
      newest[match.group(1)!.replaceAll('"', '')] = match.group(0)!;
    }
  }
  return newest;
}

void main() {
  test('enrolling still reads courses through row-level security', () {
    // The half of the cycle that was kept on purpose: it is what stops a
    // student enrolling in a free course they cannot see.
    final enrol =
        newestPolicies('enrollments')['Users can self-enroll in free courses'];
    expect(enrol, isNotNull);
    expect(enrol, contains('courses'));
  });

  test('so no policy on courses may read enrollments directly', () {
    final policies = newestPolicies('courses');
    expect(policies, contains('Courses are viewable by signed-in users'));

    for (final entry in policies.entries) {
      expect(
        entry.value.toLowerCase(),
        isNot(contains('enrollments')),
        reason: 'The policy "${entry.key}" on courses reads enrollments. '
            'Every free enrolment will be refused with "infinite recursion '
            'detected in policy". Use private.my_enrolled_course_ids() '
            'instead: see 20261010000002_free_enrolment_policy_recursion.sql.',
      );
    }
  });

  test('the enrolled branch of course visibility goes through the function',
      () {
    final visible =
        newestPolicies('courses')['Courses are viewable by signed-in users']!;
    expect(visible, contains('private.my_enrolled_course_ids()'));
    // The drafts rule, which this policy has to keep.
    expect(visible, contains('published_at is not null'));
  });
}
