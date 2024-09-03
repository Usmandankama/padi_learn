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
      appBar: AppBar(),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
              SizedBox(height: 10.h),
              SizedBox(
                width: 250.w,
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
              SizedBox(height: 70.h),
              Row(
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: 90.w,
                        vertical: 20.h,
                      ),
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: AppColors.appWhite,
                    ),
                    onPressed: () {},
                    child: const Text('Buy Course'),
                  ),
                  SizedBox(width: 30.w),
                  CircleAvatar(
                    backgroundColor: AppColors.lightGrey,
                    radius: 30.r,
                    child: Icon(
                      Icons.favorite_border_outlined,
                      size: 30.sp,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
