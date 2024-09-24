import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:padi_learn/utils/colors.dart';

class AnalyticItem extends StatefulWidget {
  final String title;
  final double earning;

  const AnalyticItem({super.key, required this.title, required this.earning});

  @override
  State<AnalyticItem> createState() => _AnalyticItemState();
}

class _AnalyticItemState extends State<AnalyticItem> {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200.h,
      width: 180.w,
      decoration: BoxDecoration(
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 2),
            spreadRadius: 2,
          ),
        ],
        color: AppColors.beige,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Column(
            children: [
              SizedBox(height: 20.h),
              Text(
                widget.title,
                style: TextStyle(
                  color: AppColors.appWhite,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${widget.earning}',
                style: TextStyle(
                  color: AppColors.appWhite,
                  fontSize: 15.sp,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}