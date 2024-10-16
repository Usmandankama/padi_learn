import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:padi_learn/screens/description/course_description_screen.dart';
import 'package:padi_learn/utils/colors.dart';

import '../../controller/marketplace_controller.dart';
import '../marketplace/components/courseGrid.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  _StudentDashboardState createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  @override
  Widget build(BuildContext context) {
    final MarketplaceController controller = Get.find<MarketplaceController>();

    return Scaffold(
      backgroundColor: AppColors.appWhite,
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'Dashboard',
          style: TextStyle(
            color: AppColors.primaryColor,
            fontSize: 22.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.notifications,
            ),
          )
        ],
        backgroundColor: AppColors.appWhite,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primaryColor),
      ),
      body: ListView(
        shrinkWrap: true,
          padding: EdgeInsets.symmetric(horizontal: 16.0.w),
          children: [
            SizedBox(height: 15.h),
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
            SizedBox(
              child: Obx(() {
                if (controller.courses.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                          
                final filteredCourses = controller.filterCourses();
                          
                if (filteredCourses.isEmpty) {
                  return const Center(child: Text('No courses available'));
                }
                          
                return CoursesGrid(courses: filteredCourses);
              }),
            ),
          ]),
    );
  }

  Widget _buildOngoingCoursesSection() {
    return SizedBox(
      height: 210.h,
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
}
