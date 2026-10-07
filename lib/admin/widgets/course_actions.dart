import 'package:flutter/material.dart';

import 'format.dart';
import 'reason_dialog.dart';

/// Taking a course down is offered from Reports and from Courses; both ask
/// the same question and report the same consequences, from here.

/// Asks for the reason, after spelling out what a takedown does. Null when the
/// admin backs out.
Future<String?> askToTakeCourseDown(BuildContext context) {
  return askForReason(
    context,
    title: 'Take this course down?',
    message: 'It leaves the catalogue and stops playing for everyone but its '
        'teacher, including students who paid. They are owed refunds, '
        'which appear under Refunds. Open reports on the course are closed; '
        'reports on its comments stay open.',
    confirmLabel: 'Take course down',
    destructive: true,
  );
}

/// What admin_remove_course() did, in a sentence: reports closed, and the paid
/// sales it made refundable.
String describeTakedown(Map<String, dynamic> result) {
  final closed = asCount(result['closed_reports']);
  final sales = asCount(result['paid_sales']);
  final reports = closed == 0
      ? ''
      : closed == 1
          ? ' 1 report closed.'
          : ' $closed reports closed.';
  final refunds = sales == 0
      ? ' No paid sales to refund.'
      : ' $sales paid ${sales == 1 ? 'sale' : 'sales'}, '
          '${formatKobo(asCount(result['paid_kobo']))}, now owed refunds.';
  return 'Course taken down.$reports$refunds';
}

Future<String?> askToRestoreCourse(BuildContext context) {
  return askForReason(
    context,
    title: 'Restore this course?',
    message: 'It plays again for students still enrolled, and returns to the '
        'catalogue unless its teacher archived it or is suspended. Students '
        'already refunded stay unenrolled.',
    confirmLabel: 'Restore',
  );
}
