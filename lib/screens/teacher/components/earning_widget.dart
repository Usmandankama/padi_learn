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
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        const SizedBox(height: 25),
        Container(
          height: 150.h,
          width: 500.w,
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
        const SizedBox(height: 20),
        Row(
          children: [
            Obx(
              () => AnalyticItem(
                title: 'Courses',
                statsData: controller.totalCoursesUploaded.value,
              ),
            ),
            SizedBox(width: 5.w),
            Obx(
              () => AnalyticItem(
                title: 'Earnings',
                statsData: controller.totalEarnings.value.toInt(),
              ),
            ),
            SizedBox(width: 5.w),
          ],
        ),
      ],
    );
  }
}
