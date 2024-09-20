import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'courseCard.dart';

class CoursesGrid extends StatelessWidget {
  final List<QueryDocumentSnapshot> courses;

  const CoursesGrid({super.key, required this.courses});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,  // Number of courses per row
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.75,
      ),
      padding: const EdgeInsets.all(10),
      itemCount: courses.length,
      itemBuilder: (context, index) {
        final courseData = courses[index].data() as Map<String, dynamic>;

        return CourseCard(courseData: courseData);
      },
    );
  }
}
