import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controller/course_controller.dart';
import '../../description/course_description_screen.dart';

class CoursesGrid extends StatelessWidget {
  final List courses;

  const CoursesGrid({super.key, required this.courses});

  @override
  Widget build(BuildContext context) {
    final CoursesController controller = Get.put(CoursesController());

    return GridView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.all(8.0),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.0,
        crossAxisSpacing: 10.0,
        mainAxisSpacing: 10.0,
      ),
      itemCount: courses.length,
      itemBuilder: (context, index) {
        final courseData = courses[index].data() as Map<String, dynamic>;
        final title = courseData['title'] ?? 'No Title'; // Get title
        final thumbnailUrl = courseData['thumbnailUrl'] ?? ''; // Fetch thumbnail URL
        final price = courseData['price'] ?? 'Free'; // Fetch price
        final description = courseData['description'] ?? 'No description available'; // Fetch description

        return GestureDetector(
          onTap: () {
            // Set selected course details in the controller
            controller.selectCourse(title, thumbnailUrl, price.toString(), description);
            Get.to(() => CourseDescriptionScreen());
          },
          child: Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15.0),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15.0),
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  // Display the custom thumbnail as the background
                  Image.network(
                    thumbnailUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey, // Placeholder if thumbnail fails to load
                        child: const Center(
                          child: Icon(Icons.broken_image, color: Colors.white),
                        ),
                      );
                    },
                  ),
                  // Overlay course title
                  Positioned(
                    bottom: 10,
                    left: 10,
                    right: 10,
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            blurRadius: 10.0,
                            color: Colors.black,
                            offset: Offset(0.0, 0.0),
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
