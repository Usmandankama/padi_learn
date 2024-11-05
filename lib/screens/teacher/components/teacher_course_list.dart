import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore package
import 'package:padi_learn/screens/description/course_description_screen.dart';
import 'package:padi_learn/utils/colors.dart';

class TeacherCourseList extends StatelessWidget {
  final List<QueryDocumentSnapshot>
      courses; // Update type to QueryDocumentSnapshot

  const TeacherCourseList({
    super.key,
    required this.courses,
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

        return GestureDetector(
          onTap: () {
            // Navigate to course details page
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => CourseDescriptionScreen()),
            );
          },
          child: Container(
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
                        color: Colors
                            .grey, // Placeholder if thumbnail fails to load
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
                            'NGN ${price.toString()}',
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
                          onPressed: () {
                            _editCourse(context, courseId, title,
                                price); // Call the edit function
                          },
                          color: AppColors.primaryColor,
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          color: AppColors.primaryColor,
                          onPressed: () => _showDeleteConfirmationDialog(
                              context, courseId), // Show confirmation dialog
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10), // Space between details and buttons
              ],
            ),
          ),
        );
      },
    );
  }

  void _editCourse(BuildContext context, String courseId, String currentTitle,
      String currentPrice) {
    final TextEditingController titleController =
        TextEditingController(text: currentTitle);
    final TextEditingController priceController =
        TextEditingController(text: currentPrice);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Course'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Course Title'),
              ),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(labelText: 'Course Price'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                // Add logic to update the course in your Firestore database
                String updatedTitle = titleController.text;
                String updatedPrice = priceController.text;

                await FirebaseFirestore.instance
                    .collection('courses')
                    .doc(courseId)
                    .update({
                  'title': updatedTitle,
                  'price': updatedPrice,
                });

                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
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
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                // Add logic to delete the course from your Firestore database
                await FirebaseFirestore.instance
                    .collection('courses')
                    .doc(courseId)
                    .delete();

                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
