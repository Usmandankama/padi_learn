import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:padi_learn/screens/components/primary_button.dart';
import 'package:padi_learn/services/payout_account_service.dart';
import 'package:padi_learn/utils/colors.dart';

/// Where a teacher tells us to send their money.
///
/// The account name is never typed — it is resolved from the bank via Paystack
/// and shown for confirmation before saving. Nigerian transfers are
/// irreversible, so a mistyped digit has to fail loudly here rather than
/// quietly pay a stranger.
class PayoutAccountScreen extends StatefulWidget {
  const PayoutAccountScreen({super.key});

  @override
  State<PayoutAccountScreen> createState() => _PayoutAccountScreenState();
}

class _PayoutAccountScreenState extends State<PayoutAccountScreen> {
  final _accountNumber = TextEditingController();

  PayoutAccount? _existing;
  List<Bank> _banks = const [];
  Bank? _selectedBank;

  String? _resolvedName;
  String? _resolveError;

  bool _loading = true;
  bool _resolving = false;
  bool _saving = false;

  /// Set when the teacher chooses to replace an account they already have.
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _accountNumber.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final existing = await PayoutAccountService.current();
      if (mounted) {
        setState(() {
          _existing = existing;
          _editing = existing == null;
        });
      }
      if (existing == null) await _loadBanks();
    } catch (_) {
      if (mounted) setState(() => _editing = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadBanks() async {
    if (_banks.isNotEmpty) return;
    try {
      final banks = await PayoutAccountService.banks();
      if (mounted) setState(() => _banks = banks);
    } catch (e) {
      _notify(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  void _notify(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
        duration: Duration(seconds: isError ? 5 : 3),
      ),
    );
  }

  /// Fires as soon as there is a bank and ten digits — the teacher shouldn't
  /// have to press anything to find out whose account they just typed.
  Future<void> _maybeResolve() async {
    final number = _accountNumber.text.trim();
    if (_selectedBank == null || number.length != 10) {
      setState(() {
        _resolvedName = null;
        _resolveError = null;
      });
      return;
    }

    setState(() {
      _resolving = true;
      _resolvedName = null;
      _resolveError = null;
    });

    try {
      final name = await PayoutAccountService.resolve(
        bankCode: _selectedBank!.code,
        accountNumber: number,
      );
      if (mounted) setState(() => _resolvedName = name);
    } catch (e) {
      if (mounted) {
        setState(
            () => _resolveError = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  Future<void> _pickBank() async {
    await _loadBanks();
    if (!mounted || _banks.isEmpty) return;

    final chosen = await showModalBottomSheet<Bank>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BankPickerSheet(banks: _banks),
    );

    if (chosen == null || !mounted) return;
    setState(() => _selectedBank = chosen);
    await _maybeResolve();
  }

  Future<void> _save() async {
    if (_selectedBank == null || _resolvedName == null) return;

    setState(() => _saving = true);
    try {
      await PayoutAccountService.save(
        bankCode: _selectedBank!.code,
        accountNumber: _accountNumber.text.trim(),
      );
      final refreshed = await PayoutAccountService.current();
      if (!mounted) return;
      setState(() {
        _existing = refreshed;
        _editing = false;
      });
      _notify('Payout account saved.');
    } catch (e) {
      _notify(e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _remove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove payout account'),
        content: const Text(
          'We will have nowhere to send your earnings until you add another.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await PayoutAccountService.remove();
      if (!mounted) return;
      setState(() {
        _existing = null;
        _editing = true;
        _selectedBank = null;
        _resolvedName = null;
        _accountNumber.clear();
      });
      await _loadBanks();
    } catch (e) {
      _notify(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
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
          'Payout Account',
          style: GoogleFonts.poppins(
            color: AppColors.primaryColor,
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _loading
          ? const AppLoader()
          : ListView(
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 32.h),
              children: [
                if (_existing != null && !_editing)
                  _buildSavedAccount(_existing!)
                else
                  _buildForm(),
              ],
            ),
    );
  }

  // ---------------------------------------------------------------------------

  Widget _buildSavedAccount(PayoutAccount account) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(18.w),
          decoration: BoxDecoration(
            color: AppColors.palette.surface,
            borderRadius: BorderRadius.circular(16.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.account_balance,
                      size: 20.sp, color: AppColors.primaryColor),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      account.bankName,
                      style: GoogleFonts.poppins(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.palette.ink,
                      ),
                    ),
                  ),
                  if (account.verifiedAt != null)
                    Icon(Icons.verified,
                        size: 18.sp, color: AppColors.primaryColor),
                ],
              ),
              SizedBox(height: 14.h),
              Text(
                account.accountName,
                style: GoogleFonts.poppins(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.palette.ink,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                account.maskedNumber,
                style: GoogleFonts.poppins(
                  fontSize: 14.sp,
                  letterSpacing: 1.5,
                  color: AppColors.palette.inkSoft,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16.h),
        _infoNote(
          'Earnings are sent here. Make sure the name matches your bank '
          'records — transfers cannot be reversed.',
        ),
        SizedBox(height: 20.h),
        PrimaryButton(
          label: 'Change account',
          isLoading: false,
          onPressed: () async {
            setState(() {
              _editing = true;
              _selectedBank = null;
              _resolvedName = null;
              _accountNumber.clear();
            });
            await _loadBanks();
          },
        ),
        SizedBox(height: 8.h),
        TextButton(
          onPressed: _remove,
          child: Text(
            'Remove account',
            style: GoogleFonts.poppins(fontSize: 13.sp, color: Colors.red),
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    final canSave = _resolvedName != null && !_saving;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoNote(
          'We check the account with your bank before saving, so your money '
          'never goes to the wrong place.',
        ),
        SizedBox(height: 16.h),

        // Bank
        Text(
          'Bank',
          style: GoogleFonts.poppins(
            fontSize: 12.5.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.palette.ink,
          ),
        ),
        SizedBox(height: 8.h),
        GestureDetector(
          onTap: _saving ? null : _pickBank,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 16.h),
            decoration: BoxDecoration(
              color: AppColors.palette.surface,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Row(
              children: [
                Icon(Icons.account_balance_outlined,
                    size: 20.sp, color: AppColors.primaryColor),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    _selectedBank?.name ?? 'Choose your bank',
                    style: GoogleFonts.poppins(
                      fontSize: 13.sp,
                      color: _selectedBank == null
                          ? AppColors.palette.inkSoft
                          : AppColors.palette.ink,
                    ),
                  ),
                ),
                Icon(Icons.keyboard_arrow_down,
                    color: AppColors.palette.inkSoft),
              ],
            ),
          ),
        ),
        SizedBox(height: 16.h),

        // Account number
        Text(
          'Account number',
          style: GoogleFonts.poppins(
            fontSize: 12.5.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.palette.ink,
          ),
        ),
        SizedBox(height: 8.h),
        TextField(
          controller: _accountNumber,
          enabled: !_saving,
          keyboardType: TextInputType.number,
          maxLength: 10,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => _maybeResolve(),
          style: GoogleFonts.poppins(fontSize: 15.sp, letterSpacing: 2),
          decoration: InputDecoration(
            hintText: '0123456789',
            counterText: '',
            filled: true,
            fillColor: AppColors.palette.surface,
            prefixIcon: Icon(Icons.pin_outlined,
                size: 20.sp, color: AppColors.primaryColor),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        SizedBox(height: 14.h),

        _buildResolutionState(),

        SizedBox(height: 24.h),
        PrimaryButton(
          label: 'Save account',
          isLoading: _saving,
          onPressed: canSave ? _save : null,
        ),
        if (_existing != null) ...[
          SizedBox(height: 8.h),
          TextButton(
            onPressed: () => setState(() => _editing = false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                  fontSize: 13.sp, color: AppColors.palette.inkSoft),
            ),
          ),
        ],
      ],
    );
  }

  /// The confirmation step: the name the bank returned, before anything saves.
  Widget _buildResolutionState() {
    if (_resolving) {
      return Row(
        children: [
          SizedBox(
            width: 16.w,
            height: 16.w,
            child: const CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 10.w),
          Text(
            'Checking with the bank…',
            style: GoogleFonts.poppins(
                fontSize: 12.sp, color: AppColors.palette.inkSoft),
          ),
        ],
      );
    }

    if (_resolveError != null) {
      return Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, size: 18.sp, color: Colors.red),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                _resolveError!,
                style: GoogleFonts.poppins(fontSize: 12.sp, color: Colors.red),
              ),
            ),
          ],
        ),
      );
    }

    if (_resolvedName != null) {
      return Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: AppColors.primaryAccent,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          children: [
            Icon(Icons.verified_user_outlined,
                size: 20.sp, color: AppColors.primaryColor),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Account name',
                    style: GoogleFonts.poppins(
                        fontSize: 10.5.sp, color: AppColors.palette.inkSoft),
                  ),
                  Text(
                    _resolvedName!,
                    style: GoogleFonts.poppins(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.palette.ink,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Text(
      'Enter your 10-digit account number and we will confirm the name.',
      style: GoogleFonts.poppins(
          fontSize: 11.5.sp, color: AppColors.palette.inkSoft),
    );
  }

  Widget _infoNote(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.lock_outline, size: 14.sp, color: AppColors.palette.inkSoft),
        SizedBox(width: 6.w),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 11.sp,
              height: 1.4,
              color: AppColors.palette.inkSoft,
            ),
          ),
        ),
      ],
    );
  }
}

/// Searchable bank list. Nigeria has well over a hundred banks and fintechs, so
/// a plain dropdown is unusable.
class _BankPickerSheet extends StatefulWidget {
  final List<Bank> banks;
  const _BankPickerSheet({required this.banks});

  @override
  State<_BankPickerSheet> createState() => _BankPickerSheetState();
}

class _BankPickerSheetState extends State<_BankPickerSheet> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Subscribes to theme changes; without this the screen keeps
    // painting the previous theme's colours when the mode flips.
    AppColors.watch(context);
    final query = _search.text.trim().toLowerCase();
    final banks = query.isEmpty
        ? widget.banks
        : widget.banks
            .where((b) => b.name.toLowerCase().contains(query))
            .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      minChildSize: 0.5,
      expand: false,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: AppColors.palette.ground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        ),
        child: Column(
          children: [
            SizedBox(height: 10.h),
            Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(4.r),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(16.w),
              child: TextField(
                controller: _search,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                style: GoogleFonts.poppins(fontSize: 13.sp),
                decoration: InputDecoration(
                  hintText: 'Search banks',
                  prefixIcon:
                      const Icon(Icons.search, color: AppColors.primaryColor),
                  filled: true,
                  fillColor: AppColors.palette.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: banks.isEmpty
                  ? Center(
                      child: Text(
                        'No banks match "${_search.text.trim()}"',
                        style: GoogleFonts.poppins(
                            fontSize: 12.sp, color: AppColors.palette.inkSoft),
                      ),
                    )
                  : ListView.separated(
                      controller: controller,
                      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w,
                          MediaQuery.of(context).padding.bottom + 12.h),
                      itemCount: banks.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: AppColors.palette.hairline),
                      itemBuilder: (_, i) => ListTile(
                        title: Text(
                          banks[i].name,
                          style: GoogleFonts.poppins(fontSize: 13.sp),
                        ),
                        onTap: () => Navigator.pop(context, banks[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
