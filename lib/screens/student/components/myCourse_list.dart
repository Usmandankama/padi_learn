import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
// import 'package:get/get.dart';
import 'package:padi_learn/utils/colors.dart';

class MyCoursesList extends StatelessWidget {
  final List<Map<String, dynamic>> courses;

  const MyCoursesList({Key? key, required this.courses}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (courses.isEmpty) {
      return Center(
        child: Text(
          'No enrolled courses yet.',
          style: TextStyle(color: Colors.grey, fontSize: 16.sp),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      itemCount: courses.length,
      itemBuilder: (context, index) {
        final course = courses[index];
        final title = course['title'] ?? 'Course Title';
        final image = course['image'] ?? '';
        final author = course['author'] ?? 'Unknown Instructor';
        final progress = course['progress'] ?? 0;

        return GestureDetector(
          onTap: () {
            // Go to course detail or video screen
          },
          child: Container(
            margin: EdgeInsets.only(bottom: 15.h),
            decoration: BoxDecoration(
              color: AppColors.appWhite,
              borderRadius: BorderRadius.circular(12.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Image Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.horizontal(left: Radius.circular(12.r)),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      image,
                      fit: BoxFit.cover,
                      width: 130.w,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey[300],
                        child: Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
                // Course Info
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(10.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15.sp,
                            color: AppColors.primaryColor,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 5.h),
                        Text(
                          'By $author',
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: AppColors.fontGrey,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        LinearProgressIndicator(
                          value: progress / 100,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation(AppColors.primaryColor),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          '$progress% completed',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.grey,
                          ),
                        )
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }
}
