import 'package:flutter/material.dart';

import 'package:padi_learn/services/report_service.dart';
import 'package:padi_learn/utils/colors.dart';

import '../data/admin_api.dart';
import '../widgets/format.dart';
import '../widgets/panel.dart';
import '../widgets/reason_dialog.dart';

/// The reports queue (docs/ADMIN_PANEL.md, item 12b).
///
/// Open reports come oldest first, so the queue is worked in order. Acting on
/// the content (deleting a comment, taking a course down) closes every open
/// report about it in the same call, so ten reports on one comment are one
/// decision. Dismissing, marking dealt with, and reopening act on one report.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, this.api = const AdminApi()});

  final AdminApi api;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _status = 'open';

  /// Bumped after every action, which rebuilds the list from the database
  /// rather than patching it locally: the action may have closed other
  /// reports too.
  int _version = 0;

  /// Reports with an action in flight, so a double click cannot send it twice.
  final Set<String> _busy = {};

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _act(String reportId, Future<String> Function() action) async {
    setState(() => _busy.add(reportId));
    try {
      final message = await action();
      if (!mounted) return;
      _snack(message);
      setState(() {
        _version++;
      });
    } catch (e) {
      if (mounted) _snack(adminErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy.remove(reportId));
    }
  }

  static String _closed(Map<String, dynamic> result) {
    final n = asCount(result['closed_reports']);
    return n == 1 ? '1 report closed.' : '$n reports closed.';
  }

  Future<void> _deleteComment(Map<String, dynamic> report) async {
    final reason = await askForReason(
      context,
      title: 'Delete this comment?',
      message: 'It disappears for everyone. Its text stays in the report and '
          'the audit log, and every open report on it is closed as dealt '
          'with.',
      confirmLabel: 'Delete comment',
      destructive: true,
    );
    if (reason == null) return;

    await _act(report['id'] as String, () async {
      final result = await widget.api
          .deleteComment(report['comment_id'] as String, reason);
      return 'Comment deleted. ${_closed(result)}';
    });
  }

  Future<void> _takeCourseDown(Map<String, dynamic> report) async {
    final reason = await askForReason(
      context,
      title: 'Take this course down?',
      message: 'It leaves the catalogue and stops playing for everyone but its '
          'teacher, including students who paid. They are owed refunds, '
          'which appear under Refunds. Open reports on the course are closed; '
          'reports on its comments stay open.',
      confirmLabel: 'Take course down',
      destructive: true,
    );
    if (reason == null) return;

    await _act(report['id'] as String, () async {
      final result = await widget.api
          .removeCourse(report['course_id'] as String, reason);
      final sales = asCount(result['paid_sales']);
      final refunds = sales == 0
          ? 'No paid sales to refund.'
          : '$sales paid ${sales == 1 ? 'sale' : 'sales'}, '
              '${formatKobo(asCount(result['paid_kobo']))}, now owed refunds.';
      return 'Course taken down. ${_closed(result)} $refunds';
    });
  }

  Future<void> _setStatus(Map<String, dynamic> report, String status) async {
    final (title, message, confirm) = switch (status) {
      'dismissed' => (
          'Dismiss this report?',
          'Nothing is removed. Use this when the content is fine.',
          'Dismiss',
        ),
      'actioned' => (
          'Mark as dealt with?',
          'For when the problem was fixed some other way, for example the '
              'owner changed it. Nothing is removed.',
          'Mark dealt with',
        ),
      _ => (
          'Reopen this report?',
          'It goes back into the open queue.',
          'Reopen',
        ),
    };

    final reason = await askForReason(
      context,
      title: title,
      message: message,
      confirmLabel: confirm,
    );
    if (reason == null) return;

    await _act(report['id'] as String, () async {
      await widget.api
          .setReportStatus(report['id'] as String, status, reason);
      return switch (status) {
        'dismissed' => 'Report dismissed.',
        'actioned' => 'Report marked dealt with.',
        _ => 'Report reopened.',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Row(
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'open', label: Text('Open')),
                  ButtonSegment(value: 'actioned', label: Text('Dealt with')),
                  ButtonSegment(value: 'dismissed', label: Text('Dismissed')),
                ],
                selected: {_status},
                onSelectionChanged: (selection) =>
                    setState(() => _status = selection.first),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh),
                onPressed: () => setState(() {
                  _version++;
                }),
              ),
            ],
          ),
        ),
        Expanded(
          child: AdminLoader<List<Map<String, dynamic>>>(
            key: ValueKey('$_status/$_version'),
            load: () => widget.api.reports(_status),
            builder: (context, reports) {
              if (reports.isEmpty) {
                return Center(
                  child: Text(
                    _status == 'open'
                        ? 'Nothing waiting. Reports filed from the app appear '
                            'here.'
                        : 'None yet.',
                    style: TextStyle(color: palette.inkSoft),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                itemCount: reports.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  if (i == reports.length) {
                    return reports.length < AdminApi.reportPageSize
                        ? const SizedBox.shrink()
                        : Text(
                            'Showing the first ${AdminApi.reportPageSize}.',
                            style: TextStyle(color: palette.inkSoft),
                          );
                  }
                  final report = reports[i];
                  final open = report['status'] == 'open';
                  final isComment = report['target_type'] == 'comment';
                  final courseLive = report['course_id'] != null &&
                      report['course_removed_at'] == null;

                  return _ReportCard(
                    report: report,
                    busy: _busy.contains(report['id']),
                    onDeleteComment:
                        open && isComment && report['comment_exists'] == true
                            ? () => _deleteComment(report)
                            : null,
                    onTakeCourseDown: open && !isComment && courseLive
                        ? () => _takeCourseDown(report)
                        : null,
                    onDealtWith:
                        open ? () => _setStatus(report, 'actioned') : null,
                    onDismiss:
                        open ? () => _setStatus(report, 'dismissed') : null,
                    onReopen: open ? null : () => _setStatus(report, 'open'),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// One report: what was reported and what it says now, who is involved, how
/// it was resolved, and the actions that make sense for it.
class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.report,
    required this.busy,
    this.onDeleteComment,
    this.onTakeCourseDown,
    this.onDealtWith,
    this.onDismiss,
    this.onReopen,
  });

  final Map<String, dynamic> report;
  final bool busy;
  final VoidCallback? onDeleteComment;
  final VoidCallback? onTakeCourseDown;
  final VoidCallback? onDealtWith;
  final VoidCallback? onDismiss;
  final VoidCallback? onReopen;

  static String _reasonLabel(Object? value) {
    for (final reason in ReportReason.values) {
      if (reason.value == value) return reason.label;
    }
    return '$value';
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final error = Theme.of(context).colorScheme.error;

    final isComment = report['target_type'] == 'comment';
    final excerpt = report['target_excerpt'] as String? ?? '';
    final current = report['current_body'] as String?;
    final others = asCount(report['open_reports_on_target']);
    final courseTitle = report['course_title'] as String?;
    final removed = report['course_removed_at'] != null;
    final details = report['details'] as String?;
    final status = report['status'] as String?;

    Widget label(String s) => Text(
          s,
          style: text.labelSmall?.copyWith(color: palette.inkSoft),
        );

    Widget quote(String s) => Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: palette.surfaceAlt,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectableText(s, style: TextStyle(color: palette.ink)),
        );

    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: palette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: palette.hairline),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryAccent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _reasonLabel(report['reason']),
                        style: text.labelMedium?.copyWith(
                          color: AppColors.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(isComment ? 'Comment' : 'Course',
                        style: text.labelLarge?.copyWith(color: palette.ink)),
                    const Spacer(),
                    Text(formatWhen(report['created_at']),
                        style: text.bodySmall?.copyWith(color: palette.inkSoft)),
                  ],
                ),
                if (status == 'open' && others > 1) ...[
                  const SizedBox(height: 8),
                  Text(
                    '$others open reports on this',
                    style: text.bodySmall?.copyWith(
                      color: AppColors.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  'Course: ${courseTitle ?? 'a course that no longer exists'}'
                  '${removed ? ' (taken down)' : ''}',
                  style: text.bodyMedium?.copyWith(color: palette.ink),
                ),
                const SizedBox(height: 12),
                if (isComment) ...[
                  label('REPORTED TEXT'),
                  quote(excerpt),
                  if (report['comment_exists'] != true) ...[
                    const SizedBox(height: 6),
                    label('The comment has since been deleted.'),
                  ] else if (current != null && current != excerpt) ...[
                    const SizedBox(height: 10),
                    label('NOW READS'),
                    quote(current),
                  ],
                ] else if (courseTitle != null && courseTitle != excerpt) ...[
                  label('REPORTED UNDER THE TITLE'),
                  quote(excerpt),
                ],
                if (details != null && details.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  label("REPORTER'S NOTE"),
                  quote(details),
                ],
                const SizedBox(height: 12),
                Text(
                  'Reported by ${report['reporter_name'] ?? 'a deleted account'}'
                  ' · ${isComment ? 'Written by' : 'Teacher'}: '
                  '${report['owner_name'] ?? 'a deleted account'}',
                  style: text.bodySmall?.copyWith(color: palette.inkSoft),
                ),
                if (status != 'open') ...[
                  const SizedBox(height: 8),
                  Text(
                    '${status == 'actioned' ? 'Dealt with' : 'Dismissed'} by '
                    '${report['resolved_by_name'] ?? 'an admin'}, '
                    '${formatWhen(report['resolved_at'])}: '
                    '${report['resolution_note'] ?? ''}',
                    style: text.bodySmall?.copyWith(color: palette.ink),
                  ),
                ],
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (onDeleteComment != null)
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: error),
                        onPressed: busy ? null : onDeleteComment,
                        child: const Text('Delete comment'),
                      ),
                    if (onTakeCourseDown != null)
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: error),
                        onPressed: busy ? null : onTakeCourseDown,
                        child: const Text('Take course down'),
                      ),
                    if (onDealtWith != null)
                      OutlinedButton(
                        onPressed: busy ? null : onDealtWith,
                        child: const Text('Mark dealt with'),
                      ),
                    if (onDismiss != null)
                      OutlinedButton(
                        onPressed: busy ? null : onDismiss,
                        child: const Text('Dismiss'),
                      ),
                    if (onReopen != null)
                      OutlinedButton(
                        onPressed: busy ? null : onReopen,
                        child: const Text('Reopen'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
