import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth for current user
import '../../student/course_description_screen.dart';

class CoursesGrid extends StatelessWidget {
  final List courses;

  const CoursesGrid({super.key, required this.courses});

  // Get current user from Firebase Auth
  String _getCurrentUserName() {
    final User? user = FirebaseAuth.instance.currentUser;
    return user?.displayName ?? 'Unknown User'; // Get the display name, or default to 'Unknown User'
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _getCurrentUserName(); // Fetch the current user's name

    return GridView.builder(
      padding: const EdgeInsets.all(8.0),
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
        final courseTitle = courseData['title'] ?? 'No Title'; // Fetch course title

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CourseDescriptionScreen(
                  imagePath: NetworkImage(thumbnailUrl), // Load the image from the URL
                  author: currentUser, // Use current user's name as the author
                  price: price,
                  description: description,
                  courseTitle: courseTitle,
                ),
              ),
            );
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
