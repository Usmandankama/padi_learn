import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:padi_learn/utils/colors.dart';
import 'package:padi_learn/utils/money.dart';

class PriceTag extends StatelessWidget {
  final num price;

  /// Already enrolled. Shows ownership rather than a price they cannot act on.
  final bool isOwned;

  const PriceTag({super.key, required this.price, this.isOwned = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40.h,
      decoration: BoxDecoration(
        color: AppColors.primaryColor,
        boxShadow: [BoxShadow(blurRadius: .5, color: Colors.black26)],
        borderRadius: BorderRadius.circular(30.r),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Text(
            isOwned ? 'Owned' : formatPriceLabel(price),
            style: const TextStyle(
                color: AppColors.appWhite, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
