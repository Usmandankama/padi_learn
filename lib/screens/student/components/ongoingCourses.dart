import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:padi_learn/screens/videoplayer/videoPlayer.dart';
import 'package:padi_learn/utils/colors.dart';
import '../../../controller/ongoing_courses_controller.dart';

class OngoingCoursesWidget extends StatelessWidget {
  final String userId;

  const OngoingCoursesWidget({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final OngoingCoursesController controller =
        Get.put(OngoingCoursesController(userId: userId));

    return Obx(() {
      if (controller.isLoading.value) {
        return SizedBox(
          height: 150.h,
          child: const Center(child: CircularProgressIndicator()),
        );
      }
      if (controller.errorMessage.isNotEmpty) {
        return _emptyHint(controller.errorMessage.value);
      }
      if (controller.ongoingCourses.isEmpty) {
        return _emptyHint('You have no courses in progress yet.');
      }

      return SizedBox(
        height: 150.h,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: controller.ongoingCourses.length,
          separatorBuilder: (_, __) => SizedBox(width: 12.w),
          itemBuilder: (context, index) {
            final course = controller.ongoingCourses[index];
            final imageUrl = (course['image'] ?? '').toString();
            final title = (course['title'] ?? 'Course Title').toString();
            final progress = ((course['progress'] as num?) ?? 0).toInt();

            return _OngoingCard(
              imageUrl: imageUrl,
              title: title,
              progress: progress,
              onTap: () => Get.to(
                () => VideoPlayerPage(courseId: (course['id'] ?? '').toString()),
              ),
            );
          },
        ),
      );
    });
  }

  Widget _emptyHint(String message) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 28.h, horizontal: 16.w),
      decoration: BoxDecoration(
        color: AppColors.appWhite,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Icon(Icons.menu_book_outlined,
              size: 30.sp, color: AppColors.primaryColor),
          SizedBox(height: 8.h),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12.sp,
              color: AppColors.fontGrey,
            ),
          ),
        ],
      ),
    );
  }
}

class _OngoingCard extends StatelessWidget {
  final String imageUrl;
  final String title;
  final int progress;
  final VoidCallback onTap;

  const _OngoingCard({
    required this.imageUrl,
    required this.title,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 230.w,
        padding: EdgeInsets.all(10.w),
        decoration: BoxDecoration(
          color: AppColors.appWhite,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12.r),
              child: SizedBox(
                width: 70.w,
                height: 70.w,
                child: imageUrl.isEmpty
                    ? Container(color: AppColors.primaryAccent)
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Container(color: AppColors.primaryAccent),
                      ),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.richBlack,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4.r),
                    child: LinearProgressIndicator(
                      value: (progress.clamp(0, 100)) / 100,
                      minHeight: 6.h,
                      backgroundColor: AppColors.primaryAccent,
                      valueColor: const AlwaysStoppedAnimation(
                          AppColors.primaryColor),
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    '$progress% complete',
                    style: GoogleFonts.poppins(
                      fontSize: 10.sp,
                      color: AppColors.fontGrey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
