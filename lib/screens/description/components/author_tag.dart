import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:padi_learn/utils/colors.dart';

class AuthorTag extends StatelessWidget {
  final String authorName;

  const AuthorTag({Key? key, required this.authorName}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40.h,
      decoration: BoxDecoration(
        color: AppColors.appWhite,
        boxShadow: [BoxShadow(blurRadius: .5, color: Colors.black26)],
        borderRadius: BorderRadius.circular(30.r),
      ),
      child: Row(
        children: [
          SizedBox(width: 5.w),
          CircleAvatar(radius: 15.r),
          SizedBox(width: 8.w),
          Text(authorName),
          SizedBox(width: 10.w),
        ],
      ),
    );
  }
}
