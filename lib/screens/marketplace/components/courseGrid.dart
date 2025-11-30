import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:padi_learn/controller/teacherController.dart';
import 'package:padi_learn/utils/colors.dart';
import '../../../controller/course_controller.dart';
import '../../description/course_description_screen.dart';

class CoursesGridLimited extends StatelessWidget {
  final List courses;

  const CoursesGridLimited({super.key, required this.courses});

  @override
  Widget build(BuildContext context) {
    final CoursesController controller = Get.put(CoursesController());
    final TeacherController teacherController = Get.find();

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
        final courseData = courses[index].data() as Map<String, dynamic>;
        final title = courseData['title'] ?? 'No Title'; // Get title
        final thumbnailUrl =
            courseData['thumbnailUrl'] ?? ''; // Fetch thumbnail URL
        final author = courseData['author'] ?? '';
        final price = courseData['price'] ?? 'Free'; // Fetch price
        final description = courseData['description'] ??
            'No description available'; // Fetch description
        final videoUrl = courseData['videoUrl'] ?? ''; // Fetch video URL
        final courseId = courses[index].id; // Get the course ID

        return GestureDetector(
            onTap: () {
              // Set selected course details in the controller, including video URL
              controller.selectCourse(
                courseId,
                title,
                thumbnailUrl,
                price.toString(),
                description,
                author,
                videoUrl,
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
                            child: Image.network(
                              thumbnailUrl,
                              height: 160.h,
                              width: double.infinity,
                              fit: BoxFit.fill,
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
                      Positioned(
                        top: 120.h,
                        left: -7.w,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 12.w, vertical: 3.h),
                          child: Container(
                            height: 50.h,
                            width: 50.h,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: AppColors.appWhite,
                                width: 3.w,
                              ),
                              borderRadius: BorderRadius.circular(50.r),
                              image: DecorationImage(
                                image: NetworkImage(
                                  teacherController.profileImageUrl.value,
                                ),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ),
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
