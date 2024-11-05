import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:padi_learn/screens/teacher/components/earning_widget.dart';
import 'package:padi_learn/screens/teacher/create_course_screen.dart';
import 'package:padi_learn/utils/colors.dart';
import '../../controller/teacherController.dart';
import 'components/teacher_course_list.dart';

class TeacherDashboardScreen extends StatelessWidget {
  // Instantiate the TeacherDashboardController for managing course data and state
  final TeacherDashboardController controller = Get.put(TeacherDashboardController());

  @override
  Widget build(BuildContext context) {
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
          // Notification button placeholder
          IconButton(
            onPressed: () {}, 
            icon: const Icon(Icons.notifications),
          )
        ],
        backgroundColor: AppColors.appWhite,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primaryColor),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 10.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Earnings Widget Section
            SizedBox(
              height: 360.h,
              child: const EarningsWidget(), // Displays financial metrics for the teacher
            ),
            SizedBox(height: 10.h),
            
            // Course Management Header
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Manage Courses',
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryColor,
                    ),
                  ),
                  // Button to navigate to Create Course Screen
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CreateCourseScreen(),
                        ),
                      );
                    },
                    icon: Icon(
                      Icons.add,
                      color: AppColors.primaryColor,
                      size: 25.sp,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 10.h),

            // StreamBuilder for Courses
            StreamBuilder<QuerySnapshot>(
              stream: controller.courseStream(), // Subscribe to the Firestore course stream
              builder: (context, snapshot) {
                // Handling different states of the stream
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator()); // Loading state
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading courses')); // Error handling
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No courses found')); // Empty state
                }
                // Display the list of courses using the TeacherCourseList widget
                return TeacherCourseList(courses: snapshot.data!.docs);
              },
            ),
            SizedBox(height: 20.h),
          ],
        ),
      ),
    );
  }
}
