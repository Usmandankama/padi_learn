import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:padi_learn/utils/colors.dart';

class CustomBackButton extends StatelessWidget {
  const CustomBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 35.h,
      width: 80.w,
      decoration: BoxDecoration(
        color: AppColors.appWhite,
        boxShadow: [
          BoxShadow(
            blurRadius: 2,
            color: Colors.black.withOpacity(.4),
            spreadRadius: 2,
          ),
        ],
        borderRadius: BorderRadius.circular(30.r),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.arrow_back_ios_new,
            size: 16.sp,
            color: AppColors.fontGrey,
          ),
          Text(
            'Back',
            style: TextStyle(
              fontSize: 16.sp,
              color: AppColors.fontGrey,
            ),
          )
        ],
      ),
    );
  }
}
