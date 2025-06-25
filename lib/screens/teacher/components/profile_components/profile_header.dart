import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get_state_manager/src/rx_flutter/rx_obx_widget.dart';

import '../../../../controller/teacherController.dart';
import '../../../../utils/colors.dart';

class ProfileHeader extends StatelessWidget {
  final TeacherController controller;

  const ProfileHeader({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: <Widget>[
          Obx(() => CircleAvatar(
                radius: 50.r,
                backgroundImage: NetworkImage(controller.profileImageUrl.value),
              )),
          SizedBox(height: 10.h),
          Obx(() => Text(
                controller.teacherName.value,
                style: TextStyle(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryColor,
                ),
              )),
          SizedBox(height: 5.h),
          Text(
            'Instructor',
            style: TextStyle(
              fontSize: 16.sp,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
