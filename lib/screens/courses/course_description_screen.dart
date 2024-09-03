import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:padi_learn/screens/components/avatar_stack.dart';
import 'package:padi_learn/screens/components/custom_back_button.dart';
import 'package:padi_learn/utils/colors.dart';

class CourseDescriptionScreen extends StatefulWidget {
  final String imagePath;
  final String author;
  final double price;
  final String description;
  final String courseTitle;

  const CourseDescriptionScreen({
    super.key,
    required this.imagePath,
    required this.author,
    required this.price,
    required this.description,
    required this.courseTitle,
  });

  @override
  State<CourseDescriptionScreen> createState() =>
      _CourseDescriptionScreenState();
}

class _CourseDescriptionScreenState extends State<CourseDescriptionScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 25.h,
              ),
              SizedBox(
                height: 320.h,
                width: 375.w,
                child: Stack(
                  children: [
                    Container(
                      height: 300.h,
                      width: 375.w,
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: AssetImage(widget.imagePath),
                          fit: BoxFit.cover,
                        ),
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                    ),
                    Positioned(
                      top: 16.h,
                      left: 16.w,
                      child: const CustomBackButton(),
                    ),
                    const Align(
                      alignment: Alignment.bottomCenter,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CustomBackButton(),
                          ),
                          Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CustomBackButton(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 32.h),
              SizedBox(
                width: 242.w,
                child: Text(
                  'Figma Master Class',
                  style: TextStyle(
                    fontSize: 32.sp,
                  ),
                ),
              ),
              Row(
                children: [
                  const AvatarStack(),
                  SizedBox(width: 13.w),
                  Text(
                    'Active Students',
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: AppColors.fontGrey,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 23.h),
              Text(
                'Description',
                style: TextStyle(
                  fontSize: 20.sp,
                ),
              ),
              Text(
                'Amet minim mollit non deserunt ullamco est sit aliqua dolor do amet sint '
                'Lorem ipsum sit dolor amet consectetur labirado amigo',
                style: TextStyle(
                  fontSize: 16.sp,
                  color: AppColors.fontGrey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
