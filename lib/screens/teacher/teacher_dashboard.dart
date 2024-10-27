import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:padi_learn/screens/teacher/components/earning_widget.dart';
import 'package:padi_learn/screens/teacher/create_course_screen.dart';
import 'package:padi_learn/utils/colors.dart';
import '../../controller/teacherController.dart';
import 'components/courseList.dart';

class TeacherDashboardScreen extends StatelessWidget {
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
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 10.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              height: 360.h,
              child: const EarningsWidget(),
            ),
            SizedBox(height: 10.h),
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
            // Using the stream from the controller
            StreamBuilder<QuerySnapshot>(
              stream: controller.courseStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading courses'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No courses found'));
                }
                return TeacherCourseList(courses: snapshot.data!.docs, onEdit: (String ) {  }, onDelete: (String ) {  },);
              },
            ),
            SizedBox(height: 20.h),
          ],
        ),
      ),
    );
  }
}
