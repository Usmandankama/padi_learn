import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:padi_learn/screens/videoplayer/videoPlayer.dart';
import 'package:padi_learn/utils/colors.dart';
import '../../../controller/ongoing_courses_controller.dart';

class OngoingCoursesWidget extends StatelessWidget {
  final String userId;

  const OngoingCoursesWidget({Key? key, required this.userId})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final OngoingCoursesController controller =
        Get.put(OngoingCoursesController(userId: userId));

    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      } else if (controller.errorMessage.isNotEmpty) {
        return Center(child: Text(controller.errorMessage.value));
      } else if (controller.ongoingCourses.isEmpty) {
        return const Center(child: Text('No ongoing courses found'));
      } else {
        return SizedBox(
          height: 210.h,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: controller.ongoingCourses.length,
            itemBuilder: (context, index) {
              final courseData = controller.ongoingCourses[index];
              final imageUrl = courseData['image'] ?? '';
              final title = courseData['title'] ?? 'Course Title';
              final progress = courseData['progress'] ?? 0;

              return GestureDetector(
                onTap: () {
                  Get.to(() => VideoPlayerPage(courseId: courseData['id']));
                },
                child: Container(
                  width: 250.w,
                  margin: EdgeInsets.only(right: 10.w),
                  decoration: BoxDecoration(
                    color: AppColors.appWhite,
                    borderRadius: BorderRadius.circular(10.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 5,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(12.0.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Container(
                          height: 100.h,
                          decoration: BoxDecoration(
                            color: AppColors.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8.r),
                            child: Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    value: progress.expectedTotalBytes != null
                                        ? progress.cumulativeBytesLoaded /
                                            progress.expectedTotalBytes!
                                        : null,
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return const Center(
                                  child: Icon(Icons.broken_image,
                                      color: AppColors.primaryColor),
                                );
                              },
                            ),
                          ),
                        ),
                        SizedBox(height: 10.h),
                        Text(
                          title,
                          style: TextStyle(
                            color: AppColors.primaryColor,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 5.h),
                        Text(
                          'Progress: $progress%',
                          style: TextStyle(
                            color: AppColors.fontGrey,
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
    });
  }
}
