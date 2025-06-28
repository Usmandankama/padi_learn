import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:padi_learn/utils/colors.dart';

class PriceTag extends StatelessWidget {
  final bool isFree;
  final String price;

  const PriceTag({Key? key, required this.isFree, required this.price}) : super(key: key);

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
            isFree ? 'Free' : 'NGN $price',
            style: const TextStyle(color: AppColors.appWhite, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
// }