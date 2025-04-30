import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controller/course_controller.dart';
import '../../description/course_description_screen.dart';

class CoursesList extends StatelessWidget {
  final List courses;

  const CoursesList({super.key, required this.courses});

  @override
  Widget build(BuildContext context) {
    final CoursesController controller = Get.put(CoursesController());

    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.all(8.0),
      itemCount: courses.length, // Display all courses
      itemBuilder: (context, index) {
        final courseData = courses[index].data() as Map<String, dynamic>;
        final title = courseData['title'] ?? 'No Title'; // Get title
        final author = courseData['author'] ?? '';
        final thumbnailUrl =
            courseData['thumbnailUrl'] ?? ''; // Fetch thumbnail URL
        final price = courseData['price'] ?? 'Free'; // Fetch price
        final videoUrl = courseData['videoUrl'] ?? ''; // Fetch video URL
        final description = courseData['description'] ??
            'No description available'; // Fetch description
        final courseId = courses[index].id; // Get the course ID

        return GestureDetector(
          onTap: () {
            // Set selected course details in the controller
            controller.selectCourse(courseId, title, thumbnailUrl,
                price.toString(), description, author, videoUrl);

            Get.to(() => CourseDescriptionScreen());
          },
          child: Card(
            margin: const EdgeInsets.only(bottom: 15.0),
            elevation: 5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
            child: Row(
              children: [
                // Course thumbnail
                // ClipRRect(
                //   borderRadius: const BorderRadius.only(
                //     topLeft: Radius.circular(10),
                //     bottomLeft: Radius.circular(10),
                //   ),
                //   child: Image.network(
                //     thumbnailUrl,
                //     height: 100.0,
                //     width: 100.0,
                //     fit: BoxFit.cover,
                //     errorBuilder: (context, error, stackTrace) {
                //       return Container(
                //         color: Colors
                //             .grey, // Placeholder if thumbnail fails to load
                //         child: const Center(
                //           child: Icon(Icons.broken_image, color: Colors.white),
                //         ),
                //       );
                //     },
                //   ),
                // ),
                const SizedBox(width: 10),
                // Course details
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18.0,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          description,
                          style: const TextStyle(
                            fontSize: 14.0,
                            color: Colors.grey,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'NGN ${price.toString()}',
                          style: const TextStyle(
                            fontSize: 16.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
