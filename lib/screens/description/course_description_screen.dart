import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:padi_learn/screens/videoplayer/vvideoPlayer.dart';
import 'package:padi_learn/utils/colors.dart';
import '../../controller/course_controller.dart';

class CourseDescriptionScreen extends StatefulWidget {
  @override
  State<CourseDescriptionScreen> createState() =>
      _CourseDescriptionScreenState();
}

class _CourseDescriptionScreenState extends State<CourseDescriptionScreen> {
  final CoursesController coursesController = Get.find<CoursesController>();
  bool isFree = false;
  bool isLoading = false; // Add a loading state variable

  @override
  Widget build(BuildContext context) {
    var courseFee = coursesController.selectedCoursePrice.value;

    // Check if the course is free and set state only if it has changed
    if (isFree != (courseFee == 0)) {
      setState(() {
        isFree = courseFee == 0;
      });
    }

    return Scaffold(
      appBar: AppBar(),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Obx(
                () => Stack(
                  children: [
                    SizedBox(
                      height: 350.h,
                      width: double.infinity,
                    ),
                    Container(
                      height: 300.h,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        image: DecorationImage(
                            image: NetworkImage(
                              coursesController.selectedCourseImage.value,
                            ),
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.high),
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                    ),
                    Positioned(
                      top: 270.h,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Author Info
                          Container(
                            height: 40.h,
                            // width: 100.w,
                            decoration: BoxDecoration(
                              color: AppColors.appWhite,
                              boxShadow: [
                                BoxShadow(
                                  blurRadius: .5,
                                  color: Colors.black.withOpacity(.4),
                                  spreadRadius: .5,
                                ),
                              ],
                              borderRadius: BorderRadius.circular(30.r),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(left: 5),
                                  child: CircleAvatar(
                                    radius: 15.r,
                                  ),
                                ),
                                SizedBox(width: 5.w),
                                Padding(
                                  padding: const EdgeInsets.only(right: 10.0),
                                  child: Text(
                                    coursesController
                                        .selectedCourseAuthor.value,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 115.w),
                          Container(
                            height: 40.h,
                            decoration: BoxDecoration(
                              color: AppColors.primaryColor,
                              boxShadow: [
                                BoxShadow(
                                  blurRadius: .5,
                                  color: Colors.black.withOpacity(.4),
                                  spreadRadius: .5,
                                ),
                              ],
                              borderRadius: BorderRadius.circular(30.r),
                            ),
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(10.0),
                                child: Text(
                                  isFree
                                      ? 'Free'
                                      : 'NGN ${coursesController.selectedCoursePrice.value}',
                                  style: const TextStyle(
                                    color: AppColors.appWhite,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20.h),
              Obx(
                () => SizedBox(
                  width: 300.w,
                  child: Text(
                    coursesController.selectedCourseTitle.value,
                    style: TextStyle(
                      fontSize: 28.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 10.h),
              Text(
                'Description',
                style: TextStyle(
                  fontSize: 20.sp,
                ),
              ),
              Obx(
                () => Text(
                  coursesController.selectedCourseDescription.value,
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: AppColors.fontGrey,
                  ),
                ),
              ),
              SizedBox(height: 70.h),
              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: AppColors.appWhite,
                  ),
                  onPressed: () async {
                    if (isFree) {
                      await _addFreeCourseToStudent();
                    } else {
                      await _purchaseCourse();
                    }
                  },
                  child: Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 100.w, vertical: 30.h),
                    child: Text(
                      isFree ? 'Get for free' : 'Buy course',
                      style: TextStyle(
                        fontSize: 16.sp,
                      ),
                    ),
                  ),
                ),
              ),
              // Circular Progress Indicator
              if (isLoading)
                const Center(
                  child: CircularProgressIndicator(),
                ), // Show loading indicator when in progress
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addFreeCourseToStudent() async {
    setState(() {
      isLoading = true; // Start loading
    });

    final currentUser = coursesController.getCurrentUser();

    if (currentUser != null) {
      final userRef =
          FirebaseFirestore.instance.collection('users').doc(currentUser.uid);

      // Prepare course data to be added
      final courseData = {
        'id':
            coursesController.selectedCourseId.value, // Assuming you have this
        'title': coursesController.selectedCourseTitle.value,
        'image': coursesController.selectedCourseImage.value,
        'description': coursesController.selectedCourseDescription.value,
        'video_url': coursesController.selectedCourseVideoUrl.value,
        'progress': 0, // Initial progress
      };

      await userRef.update({
        'ongoingCourses': FieldValue.arrayUnion([courseData]),
      }).then((_) {
        Get.snackbar(
          'Success',
          'Course added to your ongoing courses.',
          snackPosition: SnackPosition.BOTTOM,
        );
        Navigator.pop(context); // Exit the page after success
      }).catchError((error) {
        Get.snackbar(
          'Error',
          'Failed to add course: $error',
          snackPosition: SnackPosition.BOTTOM,
        );
      }).whenComplete(() {
        setState(() {
          isLoading = false; // Stop loading
        });
      });
    } else {
      setState(() {
        isLoading = false; // Stop loading if user is null
      });
    }
  }

  Future<void> _purchaseCourse() async {
    setState(() {
      isLoading = true; // Start loading
    });

    final currentUser = coursesController.getCurrentUser();

    if (currentUser != null) {
      final userRef =
          FirebaseFirestore.instance.collection('users').doc(currentUser.uid);

      // Prepare course data to be added
      final courseData = {
        'id':
            coursesController.selectedCourseId.value, // Assuming you have this
        'title': coursesController.selectedCourseTitle.value,
        'image': coursesController.selectedCourseImage.value,
        'description': coursesController.selectedCourseDescription.value,
        'video_url': coursesController.selectedCourseVideoUrl.value,
        'progress': 0, // Initial progress
      };

      await userRef.update({
        'ongoingCourses': FieldValue.arrayUnion([courseData]),
      }).then((_) {
        Get.snackbar(
          'Success',
          'Course purchased and added to your ongoing courses.',
          snackPosition: SnackPosition.BOTTOM,
        );
        Navigator.pop(context); // Exit the page after success
      }).catchError((error) {
        Get.snackbar(
          'Error',
          'Failed to purchase course: $error',
          snackPosition: SnackPosition.BOTTOM,
        );
      }).whenComplete(() {
        setState(() {
          isLoading = false; // Stop loading
        });
      });
    } else {
      setState(() {
        isLoading = false; // Stop loading if user is null
      });
    }
  }
}
