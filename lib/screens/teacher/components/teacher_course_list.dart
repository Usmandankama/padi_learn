import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:padi_learn/screens/teacher/editCourse_screen.dart';
import 'package:padi_learn/utils/colors.dart';

class TeacherCourseList extends StatelessWidget {
  final List<QueryDocumentSnapshot> courses;

  const TeacherCourseList({
    super.key,
    required this.courses,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: GridView.builder(
        key: ValueKey(courses.length),
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        padding: const EdgeInsets.all(8.0),
        itemCount: courses.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10.w,
          mainAxisSpacing: 10.h,
          childAspectRatio: .6,
        ),
        itemBuilder: (context, index) {
          final courseData = courses[index].data() as Map<String, dynamic>;

          final title = courseData['title'] ?? 'No Title';
          final thumbnailUrl = courseData['thumbnailUrl'] ?? '';
          final price = courseData['price'] ?? 'Free';
          final courseId = courses[index].id;

          return TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.95, end: 1.0),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            builder: (context, scale, child) {
              return Transform.scale(
                scale: scale,
                child: child,
              );
            },
            child: GestureDetector(
              onTapDown: (_) {},
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.appWhite,
                  borderRadius: BorderRadius.all(Radius.circular(12.r)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Course thumbnail with fade-in effect
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10.r),
                        child: FadeInImage.assetNetwork(
                          placeholder: 'assets/images/placeholder.png',
                          image: thumbnailUrl,
                          height: 120.h,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          imageErrorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 120.h,
                              color: Colors.grey,
                              child: const Center(
                                child: Icon(Icons.broken_image,
                                    color: Colors.white),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.w),
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.w),
                      child: Text(
                        'NGN ${price.toString()}',
                        style: const TextStyle(
                          fontSize: 14.0,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            // foregroundColor: AppColors.appWhite,
                            foregroundColor: AppColors.primaryColor,
                            // backgroundColor: AppColors.primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            padding: EdgeInsets.symmetric(horizontal: 12.w),
                            // elevation: 2,
                          ),
                          icon: const Icon(Icons.edit, size: 18),
                          label: const Text('Edit',
                              style: TextStyle(fontSize: 13)),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditCourseScreen(
                                  courseId: courseId,
                                  courseData: courseData,
                                ),
                              ),
                            );
                          },
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            foregroundColor: AppColors.appWhite,
                            backgroundColor: Colors.redAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            padding: EdgeInsets.symmetric(horizontal: 10.w),
                            // elevation: 2,
                          ),
                          icon: const Icon(Icons.delete, size: 18),
                          label: const Text('Delete',
                              style: TextStyle(fontSize: 13)),
                          onPressed: () => _showDeleteConfirmationDialog(
                              context, courseId),
                        ),
                      ],
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

  void _showDeleteConfirmationDialog(BuildContext context, String courseId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Course'),
          content: const Text('Are you sure you want to delete this course?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('courses')
                    .doc(courseId)
                    .delete();
                Navigator.of(context).pop();
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
