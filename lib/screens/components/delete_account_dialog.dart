import 'package:flutter/material.dart';

/// The word the user types to confirm. A tap-to-confirm is too easy to hit by
/// accident for something that cannot be undone.
const String kDeleteConfirmationWord = 'DELETE';

/// Explains what deleting an account removes, and only enables the button
/// once the confirmation word is typed. Pops `true` to go ahead.
///
/// A widget of its own, rather than a builder inside the service, so the text
/// controller lives exactly as long as the dialog — disposing it straight
/// after `showDialog` returns would crash the closing animation.
class DeleteAccountDialog extends StatefulWidget {
  final bool isTeacher;
  const DeleteAccountDialog({super.key, required this.isTeacher});

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  final _controller = TextEditingController();

  bool get _confirmed => _controller.text.trim() == kDeleteConfirmationWord;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete account?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isTeacher
                  ? 'This permanently deletes your profile, your courses and '
                      'their videos, your comments and your payout details. '
                      'Students lose access to your courses.'
                  : 'This permanently deletes your profile, your courses and '
                      'progress, your ratings and your comments.',
            ),
            const SizedBox(height: 12),
            const Text(
              'Records of payments are kept for accounting, without your '
              'name attached. This cannot be undone.',
            ),
            const SizedBox(height: 16),
            const Text('Type $kDeleteConfirmationWord to confirm.'),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              autocorrect: false,
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() {}),
              decoration:
                  const InputDecoration(hintText: kDeleteConfirmationWord),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _confirmed ? () => Navigator.pop(context, true) : null,
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Delete account'),
        ),
      ],
    );
  }
}
