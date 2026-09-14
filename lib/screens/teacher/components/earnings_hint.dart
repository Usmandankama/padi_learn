import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:padi_learn/utils/colors.dart';
import 'package:padi_learn/utils/pricing.dart';
import 'package:padi_learn/utils/money.dart';

/// Live "here's what you'll actually earn" line under a price field.
///
/// Teachers ask what their cut is before they ask anything else. Answering it
/// inline — while they are choosing the number — beats making them find it in a
/// help page, and it makes the commission feel like a stated term rather than a
/// deduction they discover later.
class EarningsHint extends StatelessWidget {
  /// Raw text from the price field; non-numeric input renders nothing.
  final String priceText;

  /// Prices above this get a gentle nudge, not a block — teachers can charge
  /// whatever they like.
  final double softPriceCeiling;

  const EarningsHint({
    super.key,
    required this.priceText,
    this.softPriceCeiling = 10000,
  });

  @override
  Widget build(BuildContext context) {
    // Subscribes to theme changes; without this the screen keeps
    // painting the previous theme's colours when the mode flips.
    AppColors.watch(context);
    final price = double.tryParse(priceText.trim()) ?? 0;
    if (price <= 0) {
      return _line(
        Icons.info_outline,
        'Free courses earn nothing, but they are the fastest way to get your '
        'first students.',
      );
    }

    final breakdown = estimateBreakdown(price);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _line(
          Icons.account_balance_wallet_outlined,
          'You earn about ${formatNaira(breakdown.teacherEarning)} per sale '
          '(~${breakdown.teacherShareOfList.round()}% of ${formatNaira(price)}). '
          'PadiLearn takes ${kPlatformFeePercent.round()}% after card fees.',
          emphasis: true,
        ),
        if (breakdown.isInFeeDeadZone) ...[
          SizedBox(height: 6.h),
          _line(
            Icons.lightbulb_outline,
            'Pricing at '
            '${formatNaira(PriceBreakdown.suggestedPriceBelowThreshold)} '
            'would earn you more — the card fee jumps by NGN 100 from '
            'NGN 2,500.',
            warning: true,
          ),
        ],
        if (price > softPriceCeiling) ...[
          SizedBox(height: 6.h),
          _line(
            Icons.trending_up,
            'Most PadiLearn courses are under '
            '${formatNaira(softPriceCeiling)}. Higher is allowed, but expect '
            'fewer '
            'buyers while the platform is new.',
          ),
        ],
      ],
    );
  }

  Widget _line(
    IconData icon,
    String text, {
    bool emphasis = false,
    bool warning = false,
  }) {
    final color = warning
        ? const Color(0xFFB26A00)
        : emphasis
            ? AppColors.primaryColor
            : AppColors.palette.inkSoft;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14.sp, color: color),
        SizedBox(width: 6.w),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 11.sp,
              height: 1.4,
              color: color,
              fontWeight: emphasis ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}
