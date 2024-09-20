import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:padi_learn/screens/teacher/components/analytics_section.dart';
import 'package:padi_learn/utils/colors.dart';

import 'components/courseList.dart';
import 'components/profile_section.dart';

class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  _TeacherDashboardScreenState createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  late Future<List<QueryDocumentSnapshot>> _userCourses;
  String teacherName = "Loading...";
  String profileImageUrl = "https://via.placeholder.com/150"; // Default profile image
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

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();

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
        if (courseData.containsKey('price') && courseData.containsKey('enrollments')) {
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
        title: Text(
          'Dashboard',
          style: TextStyle(
            color: AppColors.primaryColor,
            fontSize: 22.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.appWhite,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primaryColor),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 16.0.w, vertical: 16.0.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ProfileSection(
              teacherName: teacherName,
              profileImageUrl: profileImageUrl,
            ),
            SizedBox(height: 20.h),
            
            // EARNINGS SECTION
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Earnings',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryColor,
                  ),
                ),
                Text(
                  '\$${totalEarnings.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20.h),

            // COURSES UPLOADED SECTION
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Courses Uploaded',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryColor,
                  ),
                ),
                Text(
                  '$totalCoursesUploaded',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20.h),

            // COURSE ANALYTICS SECTION
            Text(
              'Course Analytics',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryColor,
              ),
            ),
            SizedBox(height: 10.h),
            const AnalyticsSection(),
            SizedBox(height: 20.h),

            // YOUR COURSES SECTION
            Text(
              'Your Courses',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryColor,
              ),
            ),
            SizedBox(height: 10.h),
            FutureBuilder<List<QueryDocumentSnapshot>>(
              future: _userCourses,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading courses'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No courses found'));
                }
                return CoursesList(courses: snapshot.data!);
              },
            ),
            SizedBox(height: 20.h),
          ],
        ),
      ),
    );
  }
}
