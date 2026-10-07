import 'package:flutter/material.dart';

import 'package:padi_learn/utils/colors.dart';

import '../data/admin_api.dart';
import '../widgets/format.dart';
import '../widgets/panel.dart';

/// Refunds (docs/ADMIN_PANEL.md, item 12e): who is owed, and what has been
/// refunded.
///
/// Money moves in the Paystack dashboard, not here. This screen lists the paid
/// sales of taken-down courses that still need refunding, and records a refund
/// once it has been issued, with Paystack's reference for it. The split
/// (decision 4) is computed by the database, so it is shown, never typed.
class RefundsScreen extends StatefulWidget {
  const RefundsScreen({super.key, this.api = const AdminApi()});

  final AdminApi api;

  @override
  State<RefundsScreen> createState() => _RefundsScreenState();
}

class _RefundsScreenState extends State<RefundsScreen> {
  bool _owed = true;
  int _version = 0;
  final Set<String> _busy = {};

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _record(Map<String, dynamic> sale) async {
    final entry = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _RecordRefundDialog(sale: sale),
    );
    if (entry == null) return;
    final (paystackReference, reason) = entry;
    final id = sale['transaction_id'] as String;

    setState(() => _busy.add(id));
    try {
      final result =
          await widget.api.recordRefund(id, paystackReference, reason);
      if (!mounted) return;
      _snack('Refund recorded: ${formatKobo(asCount(result['amount_kobo']))} '
          'back to the student, '
          '${formatKobo(asCount(result['teacher_clawback_kobo']))} off the '
          'teacher.'
          '${result['enrollment_revoked'] == true ? ' Their enrolment was removed.' : ''}');
      setState(() {
        _version++;
      });
    } catch (e) {
      if (mounted) _snack(adminErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Row(
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Owed')),
                  ButtonSegment(value: false, label: Text('Recorded')),
                ],
                selected: {_owed},
                onSelectionChanged: (s) => setState(() => _owed = s.first),
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
        if (_owed)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Text(
              'Issue each refund in the Paystack dashboard first (find the '
              'payment by its reference, then Refund), then record it here '
              "with Paystack's refund reference.",
              style: TextStyle(color: palette.inkSoft),
            ),
          ),
        Expanded(
          child: AdminLoader<List<Map<String, dynamic>>>(
            key: ValueKey('$_owed/$_version'),
            load: _owed ? widget.api.refundsOwed : widget.api.refunds,
            builder: (context, rows) {
              if (rows.isEmpty) {
                return Center(
                  child: Text(
                    _owed
                        ? 'Nobody is owed a refund. Taking down a course that '
                            'sold puts its buyers here.'
                        : 'No refunds recorded yet.',
                    style: TextStyle(color: palette.inkSoft),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                itemCount: rows.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) => _owed
                    ? _OwedCard(
                        sale: rows[i],
                        busy: _busy.contains(rows[i]['transaction_id']),
                        onRecord: () => _record(rows[i]),
                      )
                    : _RecordedCard(refund: rows[i]),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// The split every refund follows, shown the same way on both tabs.
List<Widget> _split(Map<String, dynamic> row) => [
      StatRow(
          label: 'Back to the student',
          value: formatKobo(asCount(row['amount_kobo'])),
          highlight: true),
      StatRow(
          label: "off the teacher's balance",
          value: formatKobo(asCount(row['teacher_clawback_kobo'])),
          indent: true),
      StatRow(
          label: 'borne by PadiLearn (commission and card fee)',
          value: formatKobo(asCount(row['platform_cost_kobo'])),
          indent: true),
    ];

class _OwedCard extends StatelessWidget {
  const _OwedCard({
    required this.sale,
    required this.busy,
    required this.onRecord,
  });

  final Map<String, dynamic> sale;
  final bool busy;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final text = Theme.of(context).textTheme;

    return Align(
      alignment: Alignment.topLeft,
      child: AdminCard(
        title: '${sale['course_title'] ?? 'A deleted course'}',
        width: 620,
        children: [
          Text(
            'Taken down ${formatWhen(sale['removed_at'])}: '
            '${sale['removed_reason'] ?? ''}',
            style: text.bodySmall?.copyWith(color: palette.inkSoft),
          ),
          const SizedBox(height: 8),
          SelectableText(
            'Bought by ${sale['buyer_name'] ?? 'a deleted account'}'
            '${sale['buyer_email'] == null ? '' : ' <${sale['buyer_email']}>'}'
            ' on ${formatWhen(sale['paid_at'])}\n'
            'Teacher: ${sale['teacher_name'] ?? 'a deleted account'}\n'
            'Paystack payment reference: ${sale['reference']}',
            style: text.bodyMedium?.copyWith(color: palette.ink),
          ),
          const Divider(height: 20),
          ..._split(sale),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: busy ? null : onRecord,
              child: const Text('Record refund'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordedCard extends StatelessWidget {
  const _RecordedCard({required this.refund});

  final Map<String, dynamic> refund;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final text = Theme.of(context).textTheme;

    return Align(
      alignment: Alignment.topLeft,
      child: AdminCard(
        title: '${refund['course_title'] ?? 'A deleted course'}',
        width: 620,
        children: [
          SelectableText(
            'Refunded to ${refund['buyer_name'] ?? 'a deleted account'}, '
            'recorded ${formatWhen(refund['created_at'])} by '
            '${refund['recorded_by_name'] ?? 'an admin'}\n'
            'Paystack refund reference: ${refund['paystack_reference']}\n'
            'Original payment: ${refund['reference']}\n'
            'Reason: ${refund['reason']}'
            '${refund['enrollment_revoked'] == true ? '\nEnrolment removed.' : ''}',
            style: text.bodyMedium?.copyWith(color: palette.ink),
          ),
          const Divider(height: 20),
          ..._split(refund),
        ],
      ),
    );
  }
}

/// Paystack's refund reference and the reason, both required. Returns
/// `(reference, reason)`.
class _RecordRefundDialog extends StatefulWidget {
  const _RecordRefundDialog({required this.sale});

  final Map<String, dynamic> sale;

  @override
  State<_RecordRefundDialog> createState() => _RecordRefundDialogState();
}

class _RecordRefundDialogState extends State<_RecordRefundDialog> {
  final _reference = TextEditingController();
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reference.dispose();
    _reason.dispose();
    super.dispose();
  }

  bool get _ready =>
      _reference.text.trim().isNotEmpty && _reason.text.trim().isNotEmpty;

  void _confirm() {
    if (!_ready) return;
    Navigator.of(context).pop((_reference.text.trim(), _reason.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Record this refund'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${formatKobo(asCount(widget.sale['amount_kobo']))} back to the '
              'student. Record it only once Paystack shows the refund.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reference,
              autofocus: true,
              decoration: const InputDecoration(
                  labelText: 'Paystack refund reference'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reason,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'Reason',
                helperText: 'Recorded in the audit log.',
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _confirm(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _ready ? _confirm : null,
          child: const Text('Record refund'),
        ),
      ],
    );
  }
}
