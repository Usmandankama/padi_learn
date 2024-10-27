import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:padi_learn/utils/colors.dart';

class TeacherCourseList extends StatelessWidget {
  final List courses;
  final Function(String) onEdit; // Callback for edit action
  final Function(String) onDelete; // Callback for delete action

  const TeacherCourseList({
    super.key,
    required this.courses,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: const EdgeInsets.all(8.0),
      itemCount: courses.length, // Display all courses
      itemBuilder: (context, index) {
        final courseData = courses[index].data() as Map<String, dynamic>;
        final title = courseData['title'] ?? 'No Title'; // Get title
        final thumbnailUrl =
            courseData['thumbnailUrl'] ?? ''; // Fetch thumbnail URL
        final price = courseData['price'] ?? 'Free'; // Fetch price
        final courseId =
            courses[index].id; // Get course ID for editing/deleting

        return Container(
          height: 300.h,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.appWhite,
            borderRadius: BorderRadius.all(
              Radius.circular(
                10.r,
              ),
            ),
            boxShadow: [
              BoxShadow(
                blurRadius: 1,
                color: Colors.black.withOpacity(.2),
                spreadRadius: 1,
              ),
            ],
          ),
          margin: const EdgeInsets.only(bottom: 15.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Course thumbnail
              ClipRRect(
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(10.r),
                    topRight: Radius.circular(10.r)),
                child: Image.network(
                  thumbnailUrl,
                  height: 200.h,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color:
                          Colors.grey, // Placeholder if thumbnail fails to load
                      child: const Center(
                        child: Icon(Icons.broken_image, color: Colors.white),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              // Course details
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0, top: 10),
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18.0,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Text(
                          '\$${price.toString()}',
                          style: const TextStyle(
                            fontSize: 16.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () {},
                        color: AppColors.primaryColor,
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        color: AppColors.primaryColor,
                        onPressed: () {},
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10), // Space between details and buttons
              // Action buttons for Edit and Delete
            ],
          ),
        );
      },
    );
  }
}
