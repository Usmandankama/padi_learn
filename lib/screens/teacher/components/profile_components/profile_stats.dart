import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../controller/teacherController.dart';
import '../../../../utils/colors.dart';

class ProfileStats extends StatelessWidget {
  final TeacherController controller;

  const ProfileStats({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 20.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          _buildStatColumn(
              'Courses', '${controller.totalCoursesUploaded.value}'),
          _buildStatColumn('Earnings',
              '\$${controller.totalEarnings.value.toStringAsFixed(2)}'),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String count) {
    return Column(
      children: <Widget>[
        Text(
          count,
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryColor,
          ),
        ),
        SizedBox(height: 5.h),
        Text(
          label,
          style: TextStyle(
            fontSize: 14.sp,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}
