// lib/screens/course_description_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:padi_learn/utils/colors.dart';

import '../../controller/course_controller.dart';
import '../components/custom_back_button.dart';

class CourseDescriptionScreen extends StatelessWidget {
  // Retrieve the existing instance of CoursesController
  final CoursesController coursesController = Get.find<CoursesController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          // title: Obx(() => Text(coursesController.selectedCourseTitle.value)),
          ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Course Image
              Obx(() => Container(
                    height: 300.h,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: NetworkImage(
                          coursesController.selectedCourseImage.value,
                        ),
                        fit: BoxFit.cover,
                      ),
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            height: 50.h,
                            width: 100.w,
                            decoration: BoxDecoration(
                              color: AppColors.appWhite,
                              boxShadow: [
                                BoxShadow(
                                  blurRadius: 2,
                                  color: Colors.black.withOpacity(.4),
                                  spreadRadius: 2,
                                ),
                              ],
                              borderRadius: BorderRadius.circular(30.r),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 15.r,
                                  // child:,
                                ),
                                SizedBox(width: 10.w),
                                const Text('Author'),
                              ],
                            ),
                          ),
                          Container(
                            height: 50.h,
                            width: 100.w,
                            decoration: BoxDecoration(
                              color: AppColors.appWhite,
                              boxShadow: [
                                BoxShadow(
                                  blurRadius: 2,
                                  color: Colors.black.withOpacity(.4),
                                  spreadRadius: 2,
                                ),
                              ],
                              borderRadius: BorderRadius.circular(30.r),
                            ),
                            child: Center(
                              child: Text(
                                'NGN ${coursesController.selectedCoursePrice.value}',
                                style: const TextStyle(
                                  color: AppColors.primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          )
                        ]),
                  )),
              SizedBox(height: 20.h),
              // Course Title
              Obx(() => SizedBox(
                    width: 300.w,
                    child: Text(
                      coursesController.selectedCourseTitle.value,
                      style: TextStyle(
                        fontSize: 28.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )),
              SizedBox(height: 10.h),
              // Course Author (Get from current user name)
              Obx(() => Row(
                    children: [
                      const Text('by'),
                      SizedBox(width: 5.w),
                      Text(
                        coursesController.getCurrentUserName(),
                        style: TextStyle(
                          fontSize: 16.sp,
                          color: AppColors.fontGrey,
                        ),
                      ),
                    ],
                  )),

              SizedBox(height: 30.h),

              // Description Title
              Text(
                'Description',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),

              // Course Description
              Obx(() => Text(
                    coursesController.selectedCourseDescription.value,
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: AppColors.fontGrey,
                    ),
                  )),
              SizedBox(height: 70.h),
              // Buy Course Button and Favorite Icon
              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: AppColors.appWhite,
                  ),
                  onPressed: () {
                    // Handle course purchase action
                  },
                  child: Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 100.w, vertical: 30.h),
                    child: Text(
                      'Buy Course',
                      style: TextStyle(fontSize: 17.sp),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
