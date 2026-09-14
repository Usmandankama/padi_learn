import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:padi_learn/services/supabase.dart';
import 'package:padi_learn/controller/course_controller.dart';
import 'package:padi_learn/config/features.dart';
import 'package:padi_learn/controller/enrollment_controller.dart';
import 'package:padi_learn/screens/components/primary_button.dart';
import 'package:padi_learn/screens/components/report_sheet.dart';
import 'package:padi_learn/screens/description/components/course_header.dart';
import 'package:padi_learn/screens/payment/paystack_checkout_screen.dart';
import 'package:padi_learn/screens/videoplayer/videoPlayer.dart';
import 'package:padi_learn/services/lesson_service.dart';
import 'package:padi_learn/services/payment_service.dart';
import 'package:padi_learn/utils/colors.dart';

/// Screen that displays full course details with the option to enroll or continue learning.
class CourseDescriptionScreen extends StatefulWidget {
  @override
  State<CourseDescriptionScreen> createState() =>
      _CourseDescriptionScreenState();
}

class _CourseDescriptionScreenState extends State<CourseDescriptionScreen> {
  final CoursesController coursesController = Get.find<CoursesController>();

  // Track course status and UI state
  bool isFree = false;
  bool isLoading = false;
  bool isAlreadyEnrolled = false;

  // Enrollment logic controller
  late final EnrollmentController enrollmentController;

  List<Lesson> _lessons = const [];
  bool _loadingLessons = true;

  /// Whether this course can be acquired from here: free ones always, paid
  /// ones only once in-app checkout is allowed (see `features.dart`).
  bool get _canBuy => isFree || kPaidCheckoutEnabled;

  @override
  void initState() {
    super.initState();

    enrollmentController =
        EnrollmentController(userId: supabase.auth.currentUser?.id ?? '');

    // Determine if the selected course is free
    isFree = coursesController.selectedCoursePrice.value == 0;

    _checkEnrollment();
    _loadLessons();
  }

  /// The curriculum doubles as the sales pitch, so it loads for everyone —
  /// enrolled or not. RLS exposes lesson titles freely; the videos stay locked.
  Future<void> _loadLessons() async {
    try {
      final lessons = await LessonService.forCourse(
          coursesController.selectedCourseId.value);
      if (mounted) setState(() => _lessons = lessons);
    } catch (_) {
      // Leave the section empty rather than blocking the buy button.
    } finally {
      if (mounted) setState(() => _loadingLessons = false);
    }
  }

  void _openLesson(Lesson lesson) {
    Get.to(() => VideoPlayerPage(
          courseId: coursesController.selectedCourseId.value,
          initialLessonId: lesson.id,
        ));
  }

  /// Looks up the existing enrolment, if any. Failures are non-fatal: the
  /// button simply stays on "Buy"/"Get for Free", and the duplicate check in
  /// [_handleEnrollment] catches the rest.
  Future<void> _checkEnrollment() async {
    if (enrollmentController.userId.isEmpty) return;
    try {
      final enrolled = await enrollmentController
          .isUserEnrolled(coursesController.selectedCourseId.value);
      if (mounted) setState(() => isAlreadyEnrolled = enrolled);
    } catch (_) {
      // Offline or transient — leave the default state.
    }
  }

  @override
  Widget build(BuildContext context) {
    // Subscribes to theme changes; without this the screen keeps
    // painting the previous theme's colours when the mode flips.
    AppColors.watch(context);
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.flag_outlined),
            tooltip: 'Report course',
            onPressed: () => showReportSheet(
              context,
              courseId: coursesController.selectedCourseId.value,
            ),
          ),
        ],
      ),
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
                    price: coursesController.selectedCoursePrice.value,
                    isOwned: isAlreadyEnrolled,
                  )),

              SizedBox(height: 20.h),

              /// Course Title
              Obx(() => Text(
                    coursesController.selectedCourseTitle.value,
                    style:
                        TextStyle(fontSize: 28.sp, fontWeight: FontWeight.bold),
                  )),

              SizedBox(height: 10.h),

              /// Static 'Description' label
              Text('Description', style: TextStyle(fontSize: 20.sp)),

              /// Course Description
              Obx(() => Text(
                    coursesController.selectedCourseDescription.value,
                    style: TextStyle(
                        fontSize: 16.sp, color: AppColors.palette.inkSoft),
                  )),

              SizedBox(height: 24.h),

              /// What they actually get — the strongest thing on this screen.
              _buildCurriculum(),

              SizedBox(height: 40.h),

              /// Enroll / Continue button — spinner shows inside the button.
              PrimaryButton(
                label: isAlreadyEnrolled
                    ? 'Continue Learning'
                    : isFree
                        ? 'Get for Free'
                        : _canBuy
                            ? 'Buy Course'
                            : 'Not available yet',
                isLoading: isLoading,
                onPressed: isAlreadyEnrolled
                    ? _continueCourse
                    : (isFree || _canBuy)
                        ? _handleEnrollment
                        : null,
              ),
              // Deliberately says nothing about where else the course might
              // be bought: Play's Payments policy bans steering users to an
              // outside checkout from inside the app.
              if (!isAlreadyEnrolled && !isFree && !_canBuy) ...[
                SizedBox(height: 10.h),
                Center(
                  child: Text(
                    "Paid courses can't be bought in the app yet. Preview "
                    'lessons are free to watch.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12.sp, color: AppColors.palette.inkSoft),
                  ),
                ),
              ],
              SizedBox(height: 24.h + MediaQuery.of(context).padding.bottom),
            ],
          ),
        ),
      ),
    );
  }

  /// Handles course enrollment (free) or purchase (paid, via Paystack).
  Future<void> _handleEnrollment() async {
    // The button is already disabled in this case; this is the backstop, so
    // no future caller can open the Paystack checkout while it's switched off.
    if (!_canBuy) return;
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

  Widget _buildCurriculum() {
    if (_loadingLessons) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 16.h),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_lessons.isEmpty) return const SizedBox.shrink();

    final total = LessonService.totalDurationLabel(_lessons);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              "What you'll learn",
              style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Text(
              [
                '${_lessons.length} lesson${_lessons.length == 1 ? '' : 's'}',
                if (total != null) total,
              ].join(' · '),
              style:
                  TextStyle(fontSize: 12.sp, color: AppColors.palette.inkSoft),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        for (var i = 0; i < _lessons.length; i++)
          _curriculumRow(_lessons[i], i + 1),
      ],
    );
  }

  Widget _curriculumRow(Lesson lesson, int number) {
    // Preview lessons are playable before buying; the rest show a lock. The
    // edge function enforces this regardless of what the UI offers.
    final unlocked = lesson.isPreview || isAlreadyEnrolled;

    return InkWell(
      onTap: unlocked ? () => _openLesson(lesson) : null,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 10.h),
        child: Row(
          children: [
            Icon(
              unlocked ? Icons.play_circle_outline : Icons.lock_outline,
              size: 20.sp,
              color:
                  unlocked ? AppColors.primaryColor : AppColors.palette.inkSoft,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                '$number. ${lesson.title}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: AppColors.palette.ink,
                ),
              ),
            ),
            if (lesson.isPreview)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: AppColors.primaryAccent,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  'Preview',
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryColor,
                  ),
                ),
              )
            else if (lesson.durationLabel != null)
              Text(
                lesson.durationLabel!,
                style: TextStyle(
                    fontSize: 12.sp, color: AppColors.palette.inkSoft),
              ),
          ],
        ),
      ),
    );
  }

  /// Navigates the user to the course video player screen
  void _continueCourse() {
    Get.to(() =>
        VideoPlayerPage(courseId: coursesController.selectedCourseId.value));
  }
}
