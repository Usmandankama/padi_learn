import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:padi_learn/controller/course_controller.dart';
import 'package:padi_learn/controller/teacher_controllers/enrollment_controller';
import 'package:padi_learn/screens/description/components/course_header.dart';
import 'package:padi_learn/screens/videoplayer/videoPlayer.dart';
import 'package:padi_learn/utils/colors.dart';

/// Screen that displays full course details with the option to enroll or continue learning.
class CourseDescriptionScreen extends StatefulWidget {
  @override
  State<CourseDescriptionScreen> createState() => _CourseDescriptionScreenState();
}

class _CourseDescriptionScreenState extends State<CourseDescriptionScreen> {
  final CoursesController coursesController = Get.find<CoursesController>();

  // Track course status and UI state
  bool isFree = false;
  bool isLoading = false;
  bool isAlreadyEnrolled = false;

  // Enrollment logic controller
  late final EnrollmentController enrollmentController;

  @override
  void initState() {
    super.initState();

    // Get current user
    final currentUser = FirebaseAuth.instance.currentUser!;
    enrollmentController = EnrollmentController(userId: currentUser.uid);

    // Determine if the selected course is free
    isFree = coursesController.selectedCoursePrice.value == 0;

    // Check if the user is already enrolled in this course
    final courseId = coursesController.selectedCourseId.value;
    enrollmentController.isUserEnrolled(courseId).then((enrolled) {
      setState(() {
        isAlreadyEnrolled = enrolled;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(), // Basic app bar
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              /// Course image, author, and price tag (modular component)
              Obx(() => CourseHeader(
                imageUrl: coursesController.selectedCourseImage.value,
                author: coursesController.selectedCourseAuthor.value,
                isFree: isFree,
                price: coursesController.selectedCoursePrice.value,
              )),

              SizedBox(height: 20.h),

              /// Course Title
              Obx(() => Text(
                coursesController.selectedCourseTitle.value,
                style: TextStyle(fontSize: 28.sp, fontWeight: FontWeight.bold),
              )),

              SizedBox(height: 10.h),

              /// Static 'Description' label
              Text('Description', style: TextStyle(fontSize: 20.sp)),

              /// Course Description
              Obx(() => Text(
                coursesController.selectedCourseDescription.value,
                style: TextStyle(fontSize: 16.sp, color: AppColors.fontGrey),
              )),

              SizedBox(height: 70.h),

              /// Enroll / Continue Button (dynamic based on course status)
              Center(
                child: ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : isAlreadyEnrolled
                          ? _continueCourse
                          : _handleEnrollment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: AppColors.appWhite,
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 50.w, vertical: 30.h),
                    child: Text(
                      isAlreadyEnrolled
                          ? 'Continue Learning'
                          : isFree
                              ? 'Get for Free'
                              : 'Buy Course',
                      style: TextStyle(fontSize: 16.sp),
                    ),
                  ),
                ),
              ),

              /// Optional loading spinner (shown during enrollment)
              if (isLoading) const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      ),
    );
  }

  /// Handles course enrollment (free or paid)
  Future<void> _handleEnrollment() async {
    setState(() => isLoading = true);

    final courseId = coursesController.selectedCourseId.value;

    // Prevent duplicate enrollments
    final alreadyEnrolled = await enrollmentController.isUserEnrolled(courseId);
    if (alreadyEnrolled) {
      Get.snackbar('Already Enrolled', 'You already have access to this course.');
      setState(() => isLoading = false);
      return;
    }

    // Proceed to enroll the user
    await enrollmentController.enrollUser(
      courseId: courseId,
      title: coursesController.selectedCourseTitle.value,
      image: coursesController.selectedCourseImage.value,
      videoUrl: coursesController.selectedCourseVideoUrl.value,
      isFree: isFree,
    );

    // Show success message and pop the screen
    Get.snackbar('Success', isFree ? 'Course added!' : 'Purchase complete!');
    Navigator.pop(context);

    setState(() {
      isLoading = false;
      isAlreadyEnrolled = true;
    });
  }

  /// Navigates the user to the course video player screen
  void _continueCourse() {
    Get.to(() => VideoPlayerPage(courseId: coursesController.selectedCourseId.value));
  }
}
