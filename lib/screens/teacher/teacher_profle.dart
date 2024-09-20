import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:padi_learn/screens/teacher/create_course_screen.dart';
import 'package:padi_learn/utils/colors.dart';

class TeacherProfileScreen extends StatefulWidget {
  const TeacherProfileScreen({Key? key}) : super(key: key);

  @override
  _TeacherProfileScreenState createState() => _TeacherProfileScreenState();
}

class _TeacherProfileScreenState extends State<TeacherProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String teacherName = 'Loading...';
  String profileImageUrl = 'https://via.placeholder.com/150'; // Default profile image
  String role = 'Instructor';
  int coursesCount = 0;
  int totalStudents = 0;
  double averageRating = 0.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchProfileData();  // Fetching the profile data from Firestore
    _fetchCourseStats();  // Fetching the teacher's courses stats
  }

  Future<void> _fetchProfileData() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      // Fetch teacher's profile info from Firestore
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        setState(() {
          teacherName = data?['name'] ?? 'Unknown';  // Update teacher's name
          profileImageUrl = data?['profileImageUrl'] ?? profileImageUrl;  // Update profile image
          role = data?['role'] ?? 'Instructor';  // Update role
        });
      }
    } catch (e) {
      print('Error fetching profile data: $e');
    }
  }

 Future<void> _fetchCourseStats() async {
  try {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    // Fetch teacher's courses from Firestore
    final querySnapshot = await FirebaseFirestore.instance
        .collection('courses')
        .where('teacherId', isEqualTo: userId)
        .get();

    int courses = querySnapshot.docs.length;
    int students = 0;
    double totalRating = 0.0;
    int ratingCount = 0;

    for (var courseDoc in querySnapshot.docs) {
      final courseData = courseDoc.data();
      
      // Casting enrollments and rating to appropriate types
      students += (courseData['enrollments'] as num?)?.toInt() ?? 0;  // Casting num to int for students
      final rating = (courseData['rating'] as num?)?.toDouble() ?? 0.0;  // Casting num to double for rating
      if (rating > 0) {
        totalRating += rating;
        ratingCount++;
      }
    }

    setState(() {
      coursesCount = courses;
      totalStudents = students;
      averageRating = ratingCount > 0 ? totalRating / ratingCount : 0.0;  // Average rating
    });
  } catch (e) {
    print('Error fetching course stats: $e');
  }
}


  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appWhite,
      appBar: AppBar(
        backgroundColor: AppColors.appWhite,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primaryColor),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: AppColors.primaryColor),
            onPressed: () {
              // Navigate to Settings screen
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            _buildProfileHeader(),
            _buildProfileStats(),
            _buildProfileActions(),
            _buildTabBar(),
            _buildTabBarView(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Center(
      child: Column(
        children: <Widget>[
          CircleAvatar(
            radius: 50.r,
            backgroundImage: NetworkImage(profileImageUrl),  // Display profile image
          ),
          SizedBox(height: 10.h),
          Text(
            teacherName,  // Display teacher's name
            style: TextStyle(
              fontSize: 24.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryColor,
            ),
          ),
          SizedBox(height: 5.h),
          Text(
            role,  // Display role
            style: TextStyle(
              fontSize: 16.sp,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileStats() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 20.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          _buildStatColumn('Courses', '$coursesCount'),  // Display number of courses
          _buildStatColumn('Students', '$totalStudents'),  // Display number of students
          _buildStatColumn('Rating', averageRating.toStringAsFixed(1)),  // Display average rating
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String count) {
    return Column(
      children: <Widget>[
        Text(
          count,
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryColor,
          ),
        ),
        SizedBox(height: 5.h),
        Text(
          label,
          style: TextStyle(
            fontSize: 14.sp,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileActions() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 30.w, vertical: 20.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                // Handle Edit Profile
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                padding: EdgeInsets.symmetric(vertical: 15.h),
              ),
              child: Text(
                'Edit Profile',
                style: TextStyle(
                  color: AppColors.appWhite,
                  fontSize: 16.sp,
                ),
              ),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                // Handle Create New Course
                Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateCourseScreen()));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                padding: EdgeInsets.symmetric(vertical: 15.h),
              ),
              child: Text(
                'Create New Course',
                style: TextStyle(
                  color: AppColors.appWhite,
                  fontSize: 16.sp,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return TabBar(
      controller: _tabController,
      labelColor: AppColors.primaryColor,
      unselectedLabelColor: Colors.grey,
      indicatorColor: AppColors.primaryColor,
      tabs: const <Widget>[
        Tab(text: 'My Courses'),  // Tab for "My Courses"
        Tab(text: 'Course Reviews'),  // Tab for "Course Reviews"
      ],
    );
  }

  Widget _buildTabBarView() {
    return SizedBox(
      height: 400.h,
      child: TabBarView(
        controller: _tabController,
        children: <Widget>[
          _buildMyCoursesTab(),  // Content for "My Courses" tab
          _buildCourseReviewsTab(),  // Content for "Course Reviews" tab
        ],
      ),
    );
  }

  Widget _buildMyCoursesTab() {
    // Replace with dynamic content based on courses fetched
    return const Center(child: Text('My Courses'));
  }

  Widget _buildCourseReviewsTab() {
    // Replace with dynamic content based on reviews fetched
    return const Center(child: Text('Course Reviews'));
  }
}
