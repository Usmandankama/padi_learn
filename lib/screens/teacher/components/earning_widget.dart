import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:padi_learn/controller/teacher_controller.dart';
import 'package:padi_learn/utils/colors.dart';

import 'analytic_item.dart';

class EarningsWidget extends StatelessWidget {
  const EarningsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final TeacherController controller = Get.find<TeacherController>();

    return Column(
      // `stretch` lets the card take the width it is given instead of a fixed
      // one. It used to be `width: 500.w`, ~1.3x the screen on the 393pt design
      // size, so it overflowed on every device.
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: 25.h),
        Container(
          // minHeight rather than a fixed height, so a large system font size
          // grows the card instead of overflowing it.
          constraints: BoxConstraints(minHeight: 150.h),
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
          decoration: const BoxDecoration(
            color: AppColors.primaryColor,
            borderRadius: BorderRadius.all(
              Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, 2),
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Earnings',
                style: TextStyle(
                  color: AppColors.appWhite,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Obx(
                () => Text(
                  'NGN ${controller.totalEarnings.value.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: AppColors.appWhite,
                    fontSize: 35.sp,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 20.h),
        // Expanded so the two tiles split whatever width is available rather
        // than claiming a fixed 180.w each and overflowing on narrow screens.
        Row(
          children: [
            Expanded(
              child: Obx(
                () => AnalyticItem(
                  title: 'Courses',
                  statsData: controller.totalCoursesUploaded.value,
                ),
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Obx(
                () => AnalyticItem(
                  title: 'Earnings',
                  statsData: controller.totalEarnings.value.toInt(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
