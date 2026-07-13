import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:padi_learn/services/supabase.dart';
import 'package:padi_learn/controller/course_controller.dart';
import 'package:padi_learn/controller/enrollment_controller.dart';
import 'package:padi_learn/screens/components/primary_button.dart';
import 'package:padi_learn/screens/description/components/course_header.dart';
import 'package:padi_learn/screens/payment/paystack_checkout_screen.dart';
import 'package:padi_learn/screens/videoplayer/videoPlayer.dart';
import 'package:padi_learn/services/payment_service.dart';
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
    final currentUser = supabase.auth.currentUser!;
    enrollmentController = EnrollmentController(userId: currentUser.id);

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
                price: coursesController.selectedCoursePrice.value
                    .toStringAsFixed(0),
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

              /// Enroll / Continue button — spinner shows inside the button.
              PrimaryButton(
                label: isAlreadyEnrolled
                    ? 'Continue Learning'
                    : isFree
                        ? 'Get for Free'
                        : 'Buy Course',
                isLoading: isLoading,
                onPressed:
                    isAlreadyEnrolled ? _continueCourse : _handleEnrollment,
              ),
              SizedBox(height: 24.h),
            ],
          ),
        ),
      ),
    );
  }

  /// Handles course enrollment (free) or purchase (paid, via Paystack).
  Future<void> _handleEnrollment() async {
    setState(() => isLoading = true);

    final courseId = coursesController.selectedCourseId.value;

    try {
      // Prevent duplicate enrollments.
      final alreadyEnrolled =
          await enrollmentController.isUserEnrolled(courseId);
      if (alreadyEnrolled) {
        Get.snackbar(
            'Already Enrolled', 'You already have access to this course.');
        setState(() => isLoading = false);
        return;
      }

      if (isFree) {
        // Free course: self-enroll (RLS allows this only for free courses).
        await enrollmentController.enrollUser(
          courseId: courseId,
          title: coursesController.selectedCourseTitle.value,
          image: coursesController.selectedCourseImage.value,
          videoUrl: coursesController.selectedCourseVideoUrl.value,
          isFree: true,
        );
        Get.snackbar('Success', 'Course added!');
      } else {
        // Paid course: initialize -> Paystack checkout -> server verify.
        final init = await PaymentService.initialize(courseId);
        if (!mounted) return;

        final completed = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => PaystackCheckoutScreen(
              authorizationUrl: init.authorizationUrl,
              callbackUrl: PaymentService.callbackUrl,
            ),
          ),
        );

        if (completed != true) {
          // User backed out of the checkout.
          setState(() => isLoading = false);
          return;
        }

        final verified = await PaymentService.verify(init.reference);
        if (!verified) {
          Get.snackbar('Payment not confirmed',
              'We could not confirm your payment. If you were charged, contact support.');
          setState(() => isLoading = false);
          return;
        }
        Get.snackbar('Success', 'Purchase complete!');
      }

      if (!mounted) return;
      Navigator.pop(context);
      setState(() {
        isLoading = false;
        isAlreadyEnrolled = true;
      });
    } catch (e) {
      Get.snackbar('Error', e.toString());
      if (mounted) setState(() => isLoading = false);
    }
  }

  /// Navigates the user to the course video player screen
  void _continueCourse() {
    Get.to(() => VideoPlayerPage(courseId: coursesController.selectedCourseId.value));
  }
}
