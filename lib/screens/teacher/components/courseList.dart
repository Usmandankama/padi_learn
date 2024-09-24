import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:padi_learn/utils/colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CoursesList extends StatelessWidget {
  final List<QueryDocumentSnapshot> courses;

  const CoursesList({
    Key? key,
    required this.courses,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(), // Prevent scrolling
      shrinkWrap: true,
      itemCount: courses.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, // Number of items per row
        childAspectRatio: 1.0, // Adjust aspect ratio to fit your design
        crossAxisSpacing: 10.w,
        mainAxisSpacing: 10.h,
      ),
      itemBuilder: (context, index) {
        final courseData = courses[index].data() as Map<String, dynamic>;
        final thumbnailUrl = courseData['thumbnailUrl'] ?? '';

        return Container(
          decoration: BoxDecoration(
            color: AppColors.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10.r),
            image: thumbnailUrl.isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(thumbnailUrl),
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(
                      Colors.black.withOpacity(0.3),
                      BlendMode.darken,
                    ),
                  )
                : null, // Only add if thumbnail URL exists
          ),
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  courseData['title'] ?? 'No Title',
                  style: TextStyle(
                    color: AppColors.appWhite,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 5.h),
                Text(
                  'Students Enrolled: ${courseData['enrollments'] ?? 0}', // Replace with dynamic student count
                  style: TextStyle(
                    color: AppColors.appWhite,
                    fontSize: 14.sp,
                  ),
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    IconButton(
                      icon: const Icon(Icons.edit, color: AppColors.appWhite),
                      onPressed: () {
                        // Handle course edit
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: AppColors.appWhite),
                      onPressed: () {
                        // Handle course delete
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
