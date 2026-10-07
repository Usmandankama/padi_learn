import 'package:flutter/material.dart';

/// Asks for the reason an admin action needs, and confirms the action itself.
///
/// The database refuses most admin actions without a reason (they land in the
/// audit log), so the confirm button stays disabled until one is typed rather
/// than letting the call fail. Returns the trimmed reason, or null when the
/// admin backs out.
Future<String?> askForReason(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _ReasonDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      destructive: destructive,
    ),
  );
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.destructive,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final bool destructive;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  String get _trimmed => _reason.text.trim();

  void _confirm() {
    if (_trimmed.isNotEmpty) Navigator.of(context).pop(_trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;

    return AlertDialog(
      title: Text(widget.title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.message),
            const SizedBox(height: 16),
            TextField(
              controller: _reason,
              autofocus: true,
              maxLength: 1000,
              minLines: 1,
              maxLines: 4,
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
          style: widget.destructive
              ? FilledButton.styleFrom(backgroundColor: error)
              : null,
          onPressed: _trimmed.isEmpty ? null : _confirm,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
