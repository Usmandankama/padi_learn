import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:padi_learn/utils/colors.dart';

class AnalyticItem extends StatefulWidget {
  final String title;
  final dynamic statsData;

  const AnalyticItem({super.key, required this.title, required this.statsData});

  @override
  State<AnalyticItem> createState() => _AnalyticItemState();
}

class _AnalyticItemState extends State<AnalyticItem> {
  @override
  Widget build(BuildContext context) {
    return Container(
      // Width comes from the parent (an Expanded); a fixed 180.w meant two
      // tiles plus padding could exceed the screen. minHeight lets the tile
      // grow with the system font size instead of overflowing.
      constraints: BoxConstraints(minHeight: 130.h),
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
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 24.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            widget.title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.appWhite,
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 10.h),
          Text(
            '${widget.statsData}',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.appWhite,
              fontSize: 18.sp,
            ),
          ),
        ],
      ),
    );
  }
}
