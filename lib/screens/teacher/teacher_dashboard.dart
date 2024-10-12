import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:padi_learn/screens/teacher/components/earning_widget.dart';
import 'package:padi_learn/screens/teacher/create_course_screen.dart';
import 'package:padi_learn/utils/colors.dart';
import 'components/courseList.dart';

class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  _TeacherDashboardScreenState createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  late Future<List<QueryDocumentSnapshot>> _userCourses;
  String teacherName = "Loading...";
  String profileImageUrl =
      "https://via.placeholder.com/150"; // Default profile image
  int totalCoursesUploaded = 0;
  double totalEarnings = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchTeacherInfo(); // Fetch teacher's info on init
    _userCourses = _fetchUserCourses(); // Fetch user courses
    _fetchTeacherEarningsAndCourses(); // Fetch earnings and course count
  }

  Future<void> _fetchTeacherInfo() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;

      if (userId == null) {
        setState(() {
          teacherName = 'User not logged in';
        });
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data();

        if (data != null && data.containsKey('name')) {
          setState(() {
            teacherName = data['name'] ?? 'Unknown Name';
            profileImageUrl = data['profileImageUrl'] ?? profileImageUrl;
          });
        } else {
          setState(() {
            teacherName = 'Name field missing';
          });
        }
      } else {
        setState(() {
          teacherName = 'User document not found';
        });
      }
    } catch (e) {
      setState(() {
        teacherName = 'Error loading name';
      });
      print('Error fetching teacher info: $e');
    }
  }

  Future<void> _fetchTeacherEarningsAndCourses() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;

      if (userId == null) return;

      // Fetch teacher's courses
      final querySnapshot = await FirebaseFirestore.instance
          .collection('courses')
          .where('userId', isEqualTo: userId)
          .get();

      int coursesCount = querySnapshot.docs.length;
      double earnings = 0.0;

      for (var courseDoc in querySnapshot.docs) {
        final courseData = courseDoc.data();
        if (courseData.containsKey('price') &&
            courseData.containsKey('enrollments')) {
          final double price = courseData['price'] ?? 0.0;
          final int enrollments = courseData['enrollments'] ?? 0;
          earnings += price * enrollments;
        }
      }

      setState(() {
        totalCoursesUploaded = coursesCount;
        totalEarnings = earnings;
      });
    } catch (e) {
      print('Error fetching teacher earnings and courses: $e');
    }
  }

  Future<List<QueryDocumentSnapshot>> _fetchUserCourses() async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final querySnapshot = await FirebaseFirestore.instance
        .collection('courses')
        .where('userId', isEqualTo: userId)
        .get();
    return querySnapshot.docs;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appWhite,
      appBar: AppBar(
        backgroundColor: AppColors.primaryAccent,
        foregroundColor: AppColors.fontGrey,
        title: Row(
          children: [
            GestureDetector(
              onTap: () {},
              child: CircleAvatar(
                radius: 25, // Adjust the size as needed
                backgroundImage: NetworkImage(profileImageUrl),
              ),
            ),
            const SizedBox(width: 10), // Space between image and text
            Text(
              teacherName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16.sp,
              ),
            ),
          ],
        ),
        toolbarHeight: 80.h,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 10.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(
              height: 350,
              child: EarningsWidget(),
            ),
            const SizedBox(height: 10),
            // YOUR COURSES SECTION
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Manage Courses',
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryColor,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CreateCourseScreen(),
                        ),
                      );
                    },
                    icon: Icon(
                      Icons.add,
                      color: AppColors.primaryColor,
                      size: 25.sp,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 10.h),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('courses')
                  .where('userId',
                      isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading courses'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No courses found'));
                }
                return CoursesList(courses: snapshot.data!.docs);
              },
            ),
            SizedBox(height: 20.h),
          ],
        ),
      ),
    );
  }
}
