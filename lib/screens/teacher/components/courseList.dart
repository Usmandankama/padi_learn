import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:padi_learn/screens/student/course_description_screen.dart';
import 'package:padi_learn/utils/colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../editCourse_screen.dart';

class CoursesList extends StatelessWidget {
  final List<QueryDocumentSnapshot> courses;

  const CoursesList({
    super.key,
    required this.courses,
  });

  // Function to delete a course
  Future<void> _deleteCourse(String courseId) async {
    try {
      await FirebaseFirestore.instance.collection('courses').doc(courseId).delete();
      print("Course deleted successfully");
    } catch (e) {
      print("Failed to delete the course: $e");
    }
  }

  // Function to navigate to edit course screen
  void _editCourse(BuildContext context, String courseId, Map<String, dynamic> courseData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditCourseScreen(courseId: courseId, courseData: courseData),
      ),
    );
  }

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
        final courseId = courses[index].id; // Get the course document ID
        final courseTitle = courseData['title'] ?? 'No Title';
        final author = courseData['author'] ?? 'Unknown Author';
        final price = courseData['price'] ?? 'Free';
        final description = courseData['description'] ?? 'No description available';

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
                    courseTitle,
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
                          _editCourse(context, courseId, courseData); // Call edit function
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: AppColors.appWhite),
                        onPressed: () async {
                          // Confirm deletion before deleting
                          bool confirmDelete = await showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: const Text("Delete Course"),
                                content: const Text("Are you sure you want to delete this course?"),
                                actions: <Widget>[
                                  TextButton(
                                    child: const Text("Cancel"),
                                    onPressed: () {
                                      Navigator.of(context).pop(false);
                                    },
                                  ),
                                  TextButton(
                                    child: const Text("Delete"),
                                    onPressed: () {
                                      Navigator.of(context).pop(true);
                                    },
                                  ),
                                ],
                              );
                            },
                          );
                          if (confirmDelete) {
                            _deleteCourse(courseId); // Call delete function
                          }
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
