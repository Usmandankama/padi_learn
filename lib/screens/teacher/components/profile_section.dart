import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:padi_learn/utils/colors.dart';

class ProfileSection extends StatelessWidget {
  final String teacherName;
  final String profileImageUrl;

  const ProfileSection({
    Key? key,
    required this.teacherName,
    required this.profileImageUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: <Widget>[
        CircleAvatar(
          radius: 30.r,
          backgroundImage: NetworkImage(profileImageUrl),
        ),
        SizedBox(width: 15.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              teacherName,
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryColor,
              ),
            ),
            Text(
              'Teacher',
              style: TextStyle(
                fontSize: 16.sp,
                color: AppColors.primaryColor.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
