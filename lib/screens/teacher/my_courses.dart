import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:padi_learn/controller/teacherController.dart';
import 'package:padi_learn/screens/teacher/components/teacher_course_list.dart';

class TeacherMyCoursesPage extends StatefulWidget {
  const TeacherMyCoursesPage({super.key});

  @override
  _TeacherMyCoursesPageState createState() => _TeacherMyCoursesPageState();
}

class _TeacherMyCoursesPageState extends State<TeacherMyCoursesPage> {
  String searchQuery = '';
  final TeacherController controller = Get.put(TeacherController());
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Courses'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              // Search bar
              TextField(
                decoration: InputDecoration(
                  labelText: 'Search Courses',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onChanged: (value) => setState(() => searchQuery = value),
              ),
              const SizedBox(height: 12),
              // Courses list
              StreamBuilder<QuerySnapshot>(
                stream: controller
                    .courseStream(), // Subscribe to the Firestore course stream
                builder: (context, snapshot) {
                  // Handling different states of the stream
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator()); // Loading state
                  }
                  if (snapshot.hasError) {
                    return const Center(
                        child: Text('Error loading courses')); // Error handling
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                        child: Text('No courses found')); // Empty state
                  }
                  // Display the list of courses using the TeacherCourseList widget
                  return TeacherCourseList(courses: snapshot.data!.docs);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
