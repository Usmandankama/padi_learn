import 'package:flutter/material.dart';

import 'package:padi_learn/screens/teacher/payout_account_screen.dart';
import 'package:padi_learn/services/payout_account_service.dart';

/// Asks for a bank account before a course is made paid.
///
/// Each sale of a paid course is split at checkout to the teacher's Paystack
/// subaccount, which is created when they save a bank account. The database
/// refuses a paid course without one; asking here first stops a teacher
/// uploading a whole video only to be refused at the end.
///
/// Returns true when the course may be saved. When the status cannot be read
/// it lets the save go ahead and leaves the refusal to the database.
Future<bool> ensureCanSellPaid(BuildContext context) async {
  final SellingStatus status;
  try {
    status = await PayoutAccountService.sellingStatus();
  } catch (_) {
    return true;
  }
  if (status.canSell) return true;
  if (!context.mounted) return false;

  final openAccount = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Add your bank account first'),
      content: Text(
        status.hasBank
            ? 'Save your bank account once more to finish setting up payouts. '
                'Paystack then pays your share of each sale straight into it.'
            : 'Paystack pays your share of each sale straight into your bank '
                'account, so we need it before you can charge for a course. '
                'Free courses need nothing.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Not now'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(status.hasBank ? 'Open payouts' : 'Add bank account'),
        ),
      ],
    ),
  );
  if (openAccount != true || !context.mounted) return false;

  await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const PayoutAccountScreen()),
  );

  // Carry straight on with the save once the account is in place.
  try {
    return (await PayoutAccountService.sellingStatus()).canSell;
  } catch (_) {
    return true;
  }
}
