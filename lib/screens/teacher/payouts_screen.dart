import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:padi_learn/screens/components/primary_button.dart';
import 'package:padi_learn/screens/teacher/payout_account_screen.dart';
import 'package:padi_learn/services/payout_account_service.dart';
import 'package:padi_learn/services/payout_service.dart';
import 'package:padi_learn/services/transaction_service.dart';
import 'package:padi_learn/utils/colors.dart';
import 'package:padi_learn/utils/money.dart';

/// Where a teacher sees what is ready, asks for it, and sees what was sent.
///
/// Asking moves no money by itself: PadiLearn makes the transfer by hand and
/// records it in the admin panel, which closes the request and sends the
/// teacher a notification. The rules (7-day hold, verified account, minimum,
/// one request at a time) are the database's; this screen only says which one
/// applies.
class TeacherPayoutsScreen extends StatefulWidget {
  const TeacherPayoutsScreen({super.key});

  @override
  State<TeacherPayoutsScreen> createState() => _TeacherPayoutsScreenState();
}

class _TeacherPayoutsScreenState extends State<TeacherPayoutsScreen> {
  TeacherBalance? _balance;
  PayoutAccount? _account;
  PayoutSummary? _summary;

  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final (balance, account, summary) = await (
        TransactionService.myBalance(),
        PayoutAccountService.current(),
        PayoutService.summary(),
      ).wait;
      if (!mounted) return;
      setState(() {
        _balance = balance;
        _account = account;
        _summary = summary;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Could not load your payouts. Pull to retry.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _notify(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
      ));
  }

  Future<void> _request() async {
    final balance = _balance;
    final account = _account;
    if (balance == null || account == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Request payout'),
        content: Text(
          'Ask PadiLearn to send ${formatNaira(balance.payable)} to '
          '${account.bankName} ${account.maskedNumber} '
          '(${account.accountName}). You will get a notification when it '
          'has been sent.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Request'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      final kobo = await PayoutService.request();
      _notify('Payout of ${formatNaira(kobo / 100)} requested.');
      await _load();
    } catch (e) {
      _notify(e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    setState(() => _busy = true);
    try {
      await PayoutService.cancel();
      _notify('Payout request cancelled.');
      await _load();
    } catch (e) {
      _notify(e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openAccount() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PayoutAccountScreen()),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    // Subscribes to theme changes; without this the screen keeps
    // painting the previous theme's colours when the mode flips.
    AppColors.watch(context);
    return Scaffold(
      backgroundColor: AppColors.palette.ground,
      appBar: AppBar(
        backgroundColor: AppColors.palette.ground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.palette.ink),
        title: Text(
          'Payouts',
          style: GoogleFonts.poppins(
            color: AppColors.primaryColor,
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _loading
          ? const AppLoader()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 32.h),
                children: [
                  if (_error != null || _balance == null || _summary == null)
                    Padding(
                      padding: EdgeInsets.only(top: 40.h),
                      child: Text(
                        _error ?? 'Could not load your payouts. Pull to retry.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.palette.inkSoft),
                      ),
                    )
                  else ...[
                    _BalanceCard(balance: _balance!),
                    SizedBox(height: 20.h),
                    PayoutRequestPanel(
                      balance: _balance!,
                      account: _account,
                      summary: _summary!,
                      busy: _busy,
                      onRequest: _request,
                      onCancel: _cancel,
                      onOpenAccount: _openAccount,
                    ),
                    SizedBox(height: 28.h),
                    _History(payouts: _summary!.payouts),
                  ],
                ],
              ),
            ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance});

  final TeacherBalance balance;

  @override
  Widget build(BuildContext context) {
    final soft = TextStyle(
      color: AppColors.appWhite.withValues(alpha: 0.85),
      fontSize: 12.sp,
    );
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 18.h),
      decoration: BoxDecoration(
        color: AppColors.primaryColor,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ready to pay out',
              style: TextStyle(color: AppColors.appWhite, fontSize: 14.sp)),
          SizedBox(height: 6.h),
          Text(
            formatNaira(balance.payable),
            style: TextStyle(
              color: AppColors.appWhite,
              fontSize: 32.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8.h),
          if (balance.settledDirectKobo > 0) ...[
            Text('Sent to your bank by Paystack '
                '${formatNaira(balance.paidByPaystack)}', style: soft),
            SizedBox(height: 2.h),
          ],
          Text('Clearing ${formatNaira(balance.clearing)}: a sale is held '
              'for 7 days before it can be paid out.', style: soft),
          SizedBox(height: 2.h),
          Text('Paid out so far ${formatNaira(balance.paidOut)}', style: soft),
        ],
      ),
    );
  }
}

/// The one thing a teacher can do next about being paid, or why they can't.
///
/// Pure: everything comes in through the constructor, so each state can be
/// pinned by a widget test without a database.
class PayoutRequestPanel extends StatelessWidget {
  const PayoutRequestPanel({
    super.key,
    required this.balance,
    required this.account,
    required this.summary,
    required this.onRequest,
    required this.onCancel,
    required this.onOpenAccount,
    this.busy = false,
  });

  final TeacherBalance balance;
  final PayoutAccount? account;
  final PayoutSummary summary;
  final bool busy;
  final VoidCallback onRequest;
  final VoidCallback onCancel;
  final VoidCallback onOpenAccount;

  bool get _hasAccount => account != null && account!.verifiedAt != null;

  @override
  Widget build(BuildContext context) {
    final open = summary.openRequest;
    final closed = summary.lastClosedRequest;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _accountRow(),
        SizedBox(height: 16.h),
        if (summary.showDecline && closed != null) ...[
          _note(
            'Your request for ${formatNaira(closed.amount)} was declined: '
            '${closed.resolutionNote ?? 'no reason given'}. Email '
            'hello@padilearn.com if you have questions.',
            icon: Icons.info_outline,
          ),
          SizedBox(height: 12.h),
        ],
        if (balance.payoutsHeld)
          _note('Payouts are on hold while your account is suspended.',
              icon: Icons.pause_circle_outline)
        else if (open != null) ...[
          _note(
            'You asked for ${formatNaira(open.amount)}'
            '${open.createdAt == null ? '' : ' on ${formatDay(open.createdAt!)}'}. '
            "We'll send it to ${account?.bankName ?? 'your bank'} "
            '${account?.maskedNumber ?? ''} and notify you when it has gone.',
            icon: Icons.schedule,
          ),
          SizedBox(height: 4.h),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: busy ? null : onCancel,
              child: const Text('Cancel request'),
            ),
          ),
        ] else if (!_hasAccount)
          PrimaryButton(
            label: 'Add a bank account',
            icon: Icons.account_balance_outlined,
            onPressed: onOpenAccount,
          )
        else ...[
          PrimaryButton(
            label: balance.payable >= summary.minimum
                ? 'Request ${formatNaira(balance.payable)}'
                : 'Request payout',
            isLoading: busy,
            onPressed: balance.payable >= summary.minimum ? onRequest : null,
          ),
          if (balance.payable < summary.minimum) ...[
            SizedBox(height: 8.h),
            Text(
              'Payouts start at ${formatNaira(summary.minimum)} ready.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12.sp, color: AppColors.palette.inkSoft),
            ),
          ],
        ],
      ],
    );
  }

  Widget _accountRow() {
    final account = this.account;
    return InkWell(
      onTap: onOpenAccount,
      borderRadius: BorderRadius.circular(14.r),
      child: Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: AppColors.palette.surface,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: AppColors.palette.hairline),
        ),
        child: Row(
          children: [
            Icon(Icons.account_balance_outlined,
                color: AppColors.primaryColor, size: 22.sp),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                account == null
                    ? 'No bank account yet'
                    : '${account.bankName} ${account.maskedNumber}\n'
                        '${account.accountName}',
                style: TextStyle(fontSize: 13.sp, color: AppColors.palette.ink),
              ),
            ),
            Text(account == null ? 'Add' : 'Change',
                style: TextStyle(
                    fontSize: 13.sp,
                    color: AppColors.primaryColor,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _note(String text, {required IconData icon}) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.primaryAccent,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20.sp, color: AppColors.primaryColor),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 13.sp, height: 1.4, color: AppColors.palette.ink)),
          ),
        ],
      ),
    );
  }
}

class _History extends StatelessWidget {
  const _History({required this.payouts});

  final List<PayoutRecord> payouts;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payouts sent',
          style: GoogleFonts.poppins(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.palette.ink,
          ),
        ),
        SizedBox(height: 10.h),
        if (payouts.isEmpty)
          Text('Nothing sent yet.',
              style: TextStyle(color: AppColors.palette.inkSoft))
        else
          for (final p in payouts)
            Padding(
              padding: EdgeInsets.only(bottom: 10.h),
              child: Container(
                padding: EdgeInsets.all(14.w),
                decoration: BoxDecoration(
                  color: AppColors.palette.surface,
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(color: AppColors.palette.hairline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatNaira(p.amount),
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.palette.ink,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    SelectableText(
                      '${p.paidAt == null ? '' : '${formatDay(p.paidAt!)} · '}'
                      '${p.bankName} ••••${p.accountLast4}\n'
                      'Reference ${p.transferReference}',
                      style: TextStyle(
                          fontSize: 12.sp, color: AppColors.palette.inkSoft),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

/// `8 Oct 2026`.
String formatDay(DateTime date) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}
