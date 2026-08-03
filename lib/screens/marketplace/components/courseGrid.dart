import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:padi_learn/utils/colors.dart';
import '../../../controller/course_controller.dart';
import '../../description/course_description_screen.dart';

class CoursesGridLimited extends StatelessWidget {
  final List courses;

  const CoursesGridLimited({super.key, required this.courses});

  @override
  Widget build(BuildContext context) {
    final CoursesController controller = Get.find<CoursesController>();

    return GridView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.all(8.0),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: .60,
        crossAxisSpacing: 10.0,
        mainAxisSpacing: 15.0,
      ),
      itemCount: courses.length > 8 ? 8 : courses.length, // Limit to 8 courses
      itemBuilder: (context, index) {
        final courseData = courses[index] as Map<String, dynamic>;
        final title = courseData['title'] ?? 'No Title';
        final thumbnailUrl = courseData['thumbnail_url'] ?? '';
        final author = courseData['author'] ?? '';
        final price = courseData['price'] ?? 0; // numeric price (0 == free)
        final description =
            courseData['description'] ?? 'No description available';
        final courseId = courses[index]['id'] as String;

        return GestureDetector(
            onTap: () {
              controller.selectCourse(
                courseId,
                title,
                thumbnailUrl,
                price,
                description,
                author,
              );
              Get.to(() => CourseDescriptionScreen());
            },
            child: Container(
              width: 250.w,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 5,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.all(
                            Radius.circular(15.r),
                          ),
                          child: AspectRatio(
                            aspectRatio: 1 / 1,
                            child: thumbnailUrl.isEmpty
                                ? Container(color: AppColors.primaryAccent)
                                : Image.network(
                                    thumbnailUrl,
                                    height: 160.h,
                                    width: double.infinity,
                                    fit: BoxFit.fill,
                                    // An empty/stale URL used to throw and
                                    // paint Flutter's error box in the grid.
                                    errorBuilder: (_, __, ___) => Container(
                                      color: AppColors.primaryAccent,
                                      child: Icon(Icons.image_not_supported,
                                          color: AppColors.fontGrey,
                                          size: 28.sp),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 10.h,
                        right: 10.w,
                        child: const Icon(
                          Icons.bookmark_border,
                          color: Colors.white,
                        ),
                      ),
                      // The avatar overlay that used to sit here showed the
                      // *signed-in* teacher's photo on every card regardless of
                      // author (read non-reactively, from a deleted asset).
                      // `courses` carries no author avatar, so it's dropped
                      // rather than shown wrong.
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12.w),
                    child: Text(
                      'By $author',
                      style:
                          TextStyle(fontSize: 12.sp, color: AppColors.fontGrey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12.w),
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.fontGrey,
                      ),
                    ),
                  ),
                  SizedBox(height: 5.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12.w),
                    child: Text(
                      price == 0
                          ? 'Free' // If price is 0, show "Free"
                          :
                      price is String
                          ? price 
                          : 'NGN ${price.toStringAsFixed(0)}',
                         // Format price
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ));
      },
    );
  }
}
