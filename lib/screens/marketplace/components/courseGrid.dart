import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:padi_learn/utils/colors.dart';
import '../../../controller/course_controller.dart';
import '../../description/course_description_screen.dart';

class CoursesGridLimited extends StatelessWidget {
  final List courses;

  const CoursesGridLimited({super.key, required this.courses});

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
      itemCount: courses.length > 8 ? 8 : courses.length, // Limit to 8 courses
      itemBuilder: (context, index) {
        final courseData = courses[index].data() as Map<String, dynamic>;
        final title = courseData['title'] ?? 'No Title'; // Get title
        final thumbnailUrl = courseData['thumbnailUrl'] ?? ''; // Fetch thumbnail URL
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
                  Image.network(
                    thumbnailUrl, // or use Image.network('your_url')
                    fit: BoxFit.cover,
                  ),
                  // Overlay course title and price
                  Positioned(
                    bottom: 10,
                    left: 10,
                    right: 10,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16.0,
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
                        const SizedBox(height: 5),
                        Container(
                          height: 35.h,
                          width: 80.w,
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(212, 255, 255, 255),
                            boxShadow: [
                              BoxShadow(
                                blurRadius: 2,
                                color: Colors.black.withOpacity(.1),
                                spreadRadius: 2,
                              ),
                            ],
                            borderRadius: BorderRadius.circular(30.r),
                          ),
                          child: Center(
                            child: Text(
                              '\$${price.toString()}',
                              style: TextStyle(
                                color: AppColors.primaryColor,
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
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
