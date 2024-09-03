import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:padi_learn/screens/courses/course_description_screen.dart';
import 'package:padi_learn/utils/colors.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  _StudentDashboardState createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appWhite,
      appBar: AppBar(
        title: Text(
          'Dashboard',
          style: TextStyle(
            color: AppColors.primaryColor,
            fontSize: 22.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.appWhite,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primaryColor),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 16.0.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              padding: EdgeInsets.all(16.0.w),
              decoration: BoxDecoration(
                color: AppColors.primaryColor,
                borderRadius: BorderRadius.circular(15.r),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Ongoing Courses',
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.appWhite,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  _buildOngoingCoursesSection(),
                ],
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              'Courses to Buy',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryColor,
              ),
            ),
            SizedBox(height: 10.h),
            _buildCoursesToBuyGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildOngoingCoursesSection() {
    return SizedBox(
      height: 180.h,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 5,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () {},
            child: Container(
              width: 250.w,
              margin: EdgeInsets.only(right: 10.w),
              decoration: BoxDecoration(
                color: AppColors.appWhite,
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Padding(
                padding: EdgeInsets.all(12.0.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      height: 100.h,
                      decoration: BoxDecoration(
                        color: AppColors.primaryColor.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Center(
                        child: Text(
                          'Course Image', // Placeholder for course image
                          style: TextStyle(
                            color: AppColors.primaryColor,
                            fontSize: 14.sp,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 10.h),
                    Text(
                      'Course Title',
                      style: TextStyle(
                        color: AppColors.primaryColor,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 5.h),
                    Text(
                      'Progress: 50%', // Placeholder for progress
                      style: TextStyle(
                        color: AppColors.primaryColor,
                        fontSize: 14.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCoursesToBuyGrid() {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(), // Prevent scrolling
      shrinkWrap: true,
      itemCount: 6, // Replace with your dynamic item count
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16.w,
        mainAxisSpacing: 16.h,
        childAspectRatio: 3 / 4, // Adjust as necessary
      ),
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CourseDescriptionScreen(
                  imagePath: 'assets/images/1.jpg',
                  author: 'Usman Abubakar',
                  price: 20000,
                  description: 'Course description',
                  courseTitle: 'Figma Master Course',
                ),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Padding(
              padding: EdgeInsets.all(12.0.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    height: 100.h,
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Center(
                      child: Text(
                        'Course Image', // Placeholder for course image
                        style: TextStyle(
                          color: AppColors.primaryColor,
                          fontSize: 14.sp,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Text(
                    'Course Title',
                    style: TextStyle(
                      color: AppColors.primaryColor,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 5.h),
                  Text(
                    '\$49.99', // Placeholder for course price
                    style: TextStyle(
                      color: AppColors.primaryColor,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
