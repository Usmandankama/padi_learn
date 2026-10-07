import 'package:flutter/material.dart';

import 'package:padi_learn/utils/colors.dart';

import '../data/admin_api.dart';
import '../widgets/format.dart';
import '../widgets/panel.dart';

/// The audit log (docs/ADMIN_PANEL.md, item 12h): every admin action, newest
/// first, with who did it and why.
///
/// Read-only, deliberately. `admin_actions` cannot be written or edited by any
/// client; rows are only added by the admin functions, in the same transaction
/// as the change they record.
class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key, this.api = const AdminApi()});

  final AdminApi api;

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

/// Action names as the database writes them, in words.
const _labels = {
  'course.remove': 'Took a course down',
  'course.restore': 'Restored a course',
  'report.actioned': 'Marked a report dealt with',
  'report.dismissed': 'Dismissed a report',
  'report.reopen': 'Reopened a report',
  'comment.delete': 'Deleted a comment',
  'refund.record': 'Recorded a refund',
  'payout.record': 'Recorded a payout',
  'user.set_role': 'Changed a role',
  'user.suspend': 'Suspended an account',
  'user.unsuspend': 'Lifted a suspension',
  'category.approve': 'Approved a category',
  'category.deactivate': 'Switched a category off',
  'category.update': 'Edited a category',
  'category.delete': 'Deleted a category',
};

/// Filter areas, keyed by the part of the action name before the dot.
const _areas = {
  'course': 'Courses',
  'report': 'Reports',
  'comment': 'Comments',
  'user': 'Users',
  'refund': 'Refunds',
  'payout': 'Payouts',
  'category': 'Categories',
};

class _AuditLogScreenState extends State<AuditLogScreen> {
  String? _area;
  int _version = 0;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);

    return AdminLoader<List<Map<String, dynamic>>>(
      key: ValueKey(_version),
      load: widget.api.auditLog,
      builder: (context, entries) {
        final shown = [
          for (final e in entries)
            if (_area == null || '${e['action']}'.startsWith('$_area.')) e,
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('All'),
                          selected: _area == null,
                          onSelected: (_) => setState(() => _area = null),
                        ),
                        for (final area in _areas.entries)
                          ChoiceChip(
                            label: Text(area.value),
                            selected: _area == area.key,
                            onSelected: (_) =>
                                setState(() => _area = area.key),
                          ),
                      ],
                    ),
                  ),
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
              child: shown.isEmpty
                  ? Center(
                      child: Text(
                        entries.isEmpty
                            ? 'No admin actions yet. Everything done in this '
                                'panel is recorded here.'
                            : 'Nothing in this area.',
                        style: TextStyle(color: palette.inkSoft),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: shown.length + 1,
                      itemBuilder: (context, i) {
                        if (i == shown.length) {
                          return entries.length < AdminApi.auditPageSize
                              ? const SizedBox.shrink()
                              : Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Text(
                                    'Showing the newest '
                                    '${AdminApi.auditPageSize}.',
                                    style: TextStyle(color: palette.inkSoft),
                                  ),
                                );
                        }
                        return _Entry(entry: shown[i]);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({required this.entry});

  final Map<String, dynamic> entry;

  /// One detail value for reading: kobo as money, nested lists flattened.
  static String _value(String key, Object? value) {
    if (value == null) return 'none';
    if (key.endsWith('_kobo') && value is num) return formatKobo(value);
    if (value is List) return value.isEmpty ? 'none' : value.join(', ');
    if (key.endsWith('_at') || key == 'paid_at') {
      final when = formatWhen(value);
      if (when.isNotEmpty) return when;
    }
    return '$value';
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final action = '${entry['action']}';
    final details =
        Map<String, dynamic>.from(entry['details'] as Map? ?? const {});
    final reason = entry['reason'] as String?;

    return ExpansionTile(
      shape: const Border(),
      collapsedShape: const Border(),
      tilePadding: const EdgeInsets.symmetric(horizontal: 8),
      title: Text(
        _labels[action] ?? action,
        style: TextStyle(color: palette.ink, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${entry['admin_name'] ?? 'A removed admin'} · '
        '${formatWhen(entry['created_at'])}'
        '${reason == null ? '' : '\n$reason'}',
        style: TextStyle(color: palette.inkSoft),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(24, 0, 8, 12),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(
          [
            '${entry['target_type']}: ${entry['target_id'] ?? 'none'}',
            for (final d in details.entries)
              '${d.key.replaceAll('_', ' ')}: ${_value(d.key, d.value)}',
          ].join('\n'),
          style: text.bodySmall?.copyWith(color: palette.ink),
        ),
      ],
    );
  }
}
