import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:padi_learn/utils/colors.dart';

class OnboardingPage extends StatelessWidget {
  final String title;
  final String description;
  final String imagePath;
  final bool isLastPage;
  final VoidCallback? onGetStarted;

  const OnboardingPage({
    super.key,
    required this.title,
    required this.description,
    required this.imagePath,
    this.isLastPage = false,
    this.onGetStarted,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Image.asset(imagePath, height: 300.h, fit: BoxFit.cover),
          SizedBox(height: 20.h),
          Text(
            title,
            style: TextStyle(
              fontSize: 24.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.appBlack,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 10.h),
          Text(
            description,
            style: TextStyle(fontSize: 16.sp, color: AppColors.fontGrey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
