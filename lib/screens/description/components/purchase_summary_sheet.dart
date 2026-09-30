import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:padi_learn/screens/components/primary_button.dart';
import 'package:padi_learn/utils/colors.dart';
import 'package:padi_learn/utils/money.dart';
import 'package:padi_learn/utils/pricing.dart';

/// Shows what a student is about to be charged, itemised, before Paystack.
///
/// Course prices are listed at what the teacher set, but the card fee is added
/// on top — so without this the total on Paystack's page would be the first
/// time anyone saw the real number, which reads as a bait and switch. Paystack
/// renders its own checkout inside a WebView and cannot be asked to explain
/// our fee, so the explaining has to happen here.
///
/// Resolves `true` when the student chooses to continue.
Future<bool> showPurchaseSummarySheet(
  BuildContext context, {
  required String courseTitle,
  required double listPrice,
}) async {
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.palette.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
    ),
    builder: (_) => _PurchaseSummarySheet(
      courseTitle: courseTitle,
      listPrice: listPrice,
    ),
  );
  return confirmed ?? false;
}

class _PurchaseSummarySheet extends StatelessWidget {
  final String courseTitle;
  final double listPrice;

  const _PurchaseSummarySheet({
    required this.courseTitle,
    required this.listPrice,
  });

  @override
  Widget build(BuildContext context) {
    // Subscribes to theme changes; without this the sheet keeps painting the
    // previous theme's colours when the mode flips.
    AppColors.watch(context);
    final breakdown = estimateBreakdown(listPrice);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 20.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: AppColors.palette.inkSoft.withValues(alpha: .3),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            SizedBox(height: 18.h),
            Text(
              courseTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 15.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.palette.ink,
              ),
            ),
            SizedBox(height: 16.h),
            _row('Course', breakdown.listPrice),
            SizedBox(height: 8.h),
            _row('Card fee', breakdown.paystackFee),
            SizedBox(height: 12.h),
            Divider(color: AppColors.palette.inkSoft.withValues(alpha: .2)),
            SizedBox(height: 12.h),
            _row('Total', breakdown.customerTotal, emphasis: true),
            SizedBox(height: 10.h),
            Text(
              'The card fee is charged by Paystack, not by PadiLearn.',
              style: GoogleFonts.poppins(
                fontSize: 11.sp,
                height: 1.4,
                color: AppColors.palette.inkSoft,
              ),
            ),
            SizedBox(height: 20.h),
            PrimaryButton(
              label: 'Continue to payment',
              onPressed: () => Navigator.of(context).pop(true),
            ),
            SizedBox(height: 8.h),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.poppins(
                    fontSize: 13.sp,
                    color: AppColors.palette.inkSoft,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, double amount, {bool emphasis = false}) {
    final style = GoogleFonts.poppins(
      fontSize: emphasis ? 15.sp : 13.sp,
      fontWeight: emphasis ? FontWeight.w700 : FontWeight.w400,
      color: emphasis ? AppColors.palette.ink : AppColors.palette.inkSoft,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(formatNaira(amount), style: style),
      ],
    );
  }
}
