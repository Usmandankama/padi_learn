import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:padi_learn/utils/colors.dart';

import '../data/admin_api.dart';
import '../widgets/format.dart';
import '../widgets/panel.dart';
import '../widgets/reason_dialog.dart';

/// Payouts (docs/ADMIN_PANEL.md, items 12f and 15): who has asked to be paid,
/// what each teacher is owed, where to send it, and a record of what was sent.
///
/// Transfers are made from the bank or Paystack, not from here. The rules are
/// decision 5's, enforced by the database: 7-day hold, verified accounts
/// only, never more than is payable, nothing to a suspended teacher. The
/// screen only offers the button when all of them can pass, and says which
/// one stands in the way when not.
class PayoutsScreen extends StatefulWidget {
  const PayoutsScreen({super.key, this.api = const AdminApi()});

  final AdminApi api;

  @override
  State<PayoutsScreen> createState() => _PayoutsScreenState();
}

class _PayoutsScreenState extends State<PayoutsScreen> {
  bool _balances = true;
  int _version = 0;
  final Set<String> _busy = {};

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _record(Map<String, dynamic> teacher) async {
    final entry = await showDialog<(int, String, String?)>(
      context: context,
      builder: (_) => _RecordPayoutDialog(teacher: teacher),
    );
    if (entry == null) return;
    final (amountKobo, reference, note) = entry;
    final id = teacher['teacher_id'] as String;

    setState(() => _busy.add(id));
    try {
      final result = await widget.api.recordPayout(
        teacherId: id,
        amountKobo: amountKobo,
        transferReference: reference,
        note: note,
      );
      if (!mounted) return;
      _snack('Payout of ${formatKobo(amountKobo)} recorded. '
          '${formatKobo(asCount(result['available_after_kobo']))} still '
          'payable.');
      setState(() {
        _version++;
      });
    } catch (e) {
      if (mounted) _snack(adminErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _decline(Map<String, dynamic> teacher) async {
    final reason = await askForReason(
      context,
      title: 'Decline payout request',
      message: '${teacher['teacher_name'] ?? 'The teacher'} asked for '
          '${formatKobo(asCount(teacher['requested_kobo']))}. They are shown '
          'this reason in the app, and can ask again.',
      confirmLabel: 'Decline request',
      destructive: true,
    );
    if (reason == null) return;
    final id = teacher['teacher_id'] as String;

    setState(() => _busy.add(id));
    try {
      await widget.api
          .declinePayoutRequest(teacher['request_id'] as String, reason);
      if (!mounted) return;
      _snack('Payout request declined.');
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
                  ButtonSegment(value: true, label: Text('Balances')),
                  ButtonSegment(value: false, label: Text('Payouts made')),
                ],
                selected: {_balances},
                onSelectionChanged: (s) =>
                    setState(() => _balances = s.first),
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
        if (_balances)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Text(
              'Teachers who asked to be paid come first. Send the transfer '
              'from your bank or Paystack, then record it here with its '
              'reference: that closes the request and tells the teacher. A '
              'sale becomes payable 7 days after it was paid.',
              style: TextStyle(color: palette.inkSoft),
            ),
          ),
        Expanded(
          child: AdminLoader<List<Map<String, dynamic>>>(
            key: ValueKey('$_balances/$_version'),
            load: _balances ? widget.api.teacherBalances : widget.api.payouts,
            builder: (context, rows) {
              if (rows.isEmpty) {
                return Center(
                  child: Text(
                    _balances
                        ? 'No teacher has made a sale yet.'
                        : 'No payouts recorded yet.',
                    style: TextStyle(color: palette.inkSoft),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                itemCount: rows.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) => _balances
                    ? _BalanceCard(
                        teacher: rows[i],
                        busy: _busy.contains(rows[i]['teacher_id']),
                        onRecord: () => _record(rows[i]),
                        onDecline: () => _decline(rows[i]),
                      )
                    : _PayoutCard(payout: rows[i]),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Why a teacher cannot be paid right now, or null when they can.
String? _blocker(Map<String, dynamic> teacher) {
  if (teacher['suspended'] == true) {
    return 'Payouts held while this teacher is suspended.';
  }
  if (asCount(teacher['available_kobo']) <= 0) {
    return asCount(teacher['pending_kobo']) > 0
        ? 'Nothing payable yet: sales are held for 7 days.'
        : 'Nothing payable.';
  }
  if (teacher['account_verified'] != true) {
    return 'No verified bank account yet. The teacher adds one in the app.';
  }
  return null;
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.teacher,
    required this.busy,
    required this.onRecord,
    required this.onDecline,
  });

  final Map<String, dynamic> teacher;
  final bool busy;
  final VoidCallback onRecord;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final blocker = _blocker(teacher);
    final account = teacher['account_number'] as String?;
    final requested = teacher['request_id'] != null;

    String kobo(String key) => formatKobo(asCount(teacher[key]));

    return Align(
      alignment: Alignment.topLeft,
      child: AdminCard(
        title: '${teacher['teacher_name'] ?? 'A deleted account'}',
        width: 620,
        children: [
          Text('${teacher['teacher_email'] ?? ''}',
              style: text.bodySmall?.copyWith(color: palette.inkSoft)),
          if (requested) ...[
            const SizedBox(height: 8),
            Text(
              'Asked to be paid '
              '${formatKobo(asCount(teacher['requested_kobo']))}, '
              '${formatWhen(teacher['requested_at'])}',
              style: text.bodyMedium?.copyWith(
                  color: palette.ink, fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 8),
          StatRow(
              label: 'Earned from ${asCount(teacher['sales_count'])} sales',
              value: kobo('earned_kobo')),
          StatRow(
              label: 'taken back by refunds',
              value: kobo('clawback_kobo'),
              indent: true),
          StatRow(label: 'paid out', value: kobo('paid_out_kobo'), indent: true),
          StatRow(label: 'Balance', value: kobo('balance_kobo')),
          StatRow(
              label: 'pending (7-day hold)',
              value: kobo('pending_kobo'),
              indent: true),
          StatRow(
            label: 'payable now',
            value: kobo('available_kobo'),
            indent: true,
            highlight: blocker == null,
          ),
          const Divider(height: 20),
          if (account == null)
            Text('No bank account.',
                style: text.bodyMedium?.copyWith(color: palette.ink))
          else
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    '${teacher['bank_name']}\n$account · '
                    '${teacher['account_name']}'
                    '${teacher['account_verified'] == true ? '' : ' (unverified)'}',
                    style: text.bodyMedium?.copyWith(color: palette.ink),
                  ),
                ),
                IconButton(
                  tooltip: 'Copy account number',
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: account));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Account number copied')),
                    );
                  },
                ),
              ],
            ),
          const SizedBox(height: 10),
          if (blocker != null)
            Text(blocker, style: text.bodySmall?.copyWith(color: palette.inkSoft)),
          if (blocker == null || requested)
            Padding(
              padding: EdgeInsets.only(top: blocker == null ? 0 : 10),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  if (blocker == null)
                    FilledButton(
                      onPressed: busy ? null : onRecord,
                      child: const Text('Record payout'),
                    ),
                  if (requested)
                    OutlinedButton(
                      onPressed: busy ? null : onDecline,
                      child: const Text('Decline request'),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PayoutCard extends StatelessWidget {
  const _PayoutCard({required this.payout});

  final Map<String, dynamic> payout;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final text = Theme.of(context).textTheme;

    return Align(
      alignment: Alignment.topLeft,
      child: AdminCard(
        title: '${formatKobo(asCount(payout['amount_kobo']))} to '
            '${payout['teacher_name'] ?? 'a deleted account'}',
        width: 620,
        children: [
          SelectableText(
            'Sent ${formatWhen(payout['paid_at'])} to ${payout['bank_name']} '
            '${payout['account_number']} (${payout['account_name']})\n'
            'Transfer reference: ${payout['transfer_reference']}\n'
            'Recorded by ${payout['recorded_by_name'] ?? 'an admin'}, '
            '${formatWhen(payout['created_at'])}'
            '${payout['note'] == null ? '' : '\nNote: ${payout['note']}'}',
            style: text.bodyMedium?.copyWith(color: palette.ink),
          ),
        ],
      ),
    );
  }
}

/// Amount (prefilled with everything payable), the transfer's reference, and
/// an optional note. Returns `(amountKobo, reference, note)`.
class _RecordPayoutDialog extends StatefulWidget {
  const _RecordPayoutDialog({required this.teacher});

  final Map<String, dynamic> teacher;

  @override
  State<_RecordPayoutDialog> createState() => _RecordPayoutDialogState();
}

class _RecordPayoutDialogState extends State<_RecordPayoutDialog> {
  late final int _available = asCount(widget.teacher['available_kobo']);

  /// What the teacher asked for, when they did and it is still payable;
  /// otherwise everything payable.
  late final int _prefill = () {
    final requested = asCount(widget.teacher['requested_kobo']);
    return requested > 0 && requested <= _available ? requested : _available;
  }();
  late final _amount =
      TextEditingController(text: koboToPlainNaira(_prefill));
  final _reference = TextEditingController();
  final _note = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _note.dispose();
    super.dispose();
  }

  int? get _kobo => parseNairaToKobo(_amount.text);

  String? get _amountError {
    final kobo = _kobo;
    if (kobo == null) return 'Enter an amount in naira, e.g. 4250.00';
    if (kobo > _available) {
      return 'More than the ${formatKobo(_available)} payable';
    }
    return null;
  }

  bool get _ready =>
      _amountError == null && _reference.text.trim().isNotEmpty;

  void _confirm() {
    if (!_ready) return;
    final note = _note.text.trim();
    Navigator.of(context)
        .pop((_kobo!, _reference.text.trim(), note.isEmpty ? null : note));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Record a payout to ${widget.teacher['teacher_name']}'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Record it only once the transfer has left. '
                '${formatKobo(_available)} is payable.'),
            const SizedBox(height: 16),
            TextField(
              controller: _amount,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Amount sent (NGN)',
                errorText: _amountError,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reference,
              decoration: const InputDecoration(
                  labelText: 'Transfer reference (from the bank or Paystack)'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              maxLength: 1000,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
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
          child: const Text('Record payout'),
        ),
      ],
    );
  }
}
