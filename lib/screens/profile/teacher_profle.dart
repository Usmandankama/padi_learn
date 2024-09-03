import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:padi_learn/utils/colors.dart';

class TeacherProfileScreen extends StatefulWidget {
  const TeacherProfileScreen({Key? key}) : super(key: key);

  @override
  _TeacherProfileScreenState createState() => _TeacherProfileScreenState();
}

class _TeacherProfileScreenState extends State<TeacherProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
        iconTheme: IconThemeData(color: AppColors.primaryColor),
        actions: [
          IconButton(
            icon: Icon(Icons.settings, color: AppColors.primaryColor),
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
            backgroundImage: NetworkImage('https://via.placeholder.com/150'), // Replace with profile image
          ),
          SizedBox(height: 10.h),
          Text(
            'John Doe', // Replace with teacher's name
            style: TextStyle(
              fontSize: 24.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryColor,
            ),
          ),
          SizedBox(height: 5.h),
          Text(
            'Instructor', // Replace with user's role
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
          _buildStatColumn('Courses', '10'), // Number of courses taught
          _buildStatColumn('Students', '1.2K'), // Number of students enrolled
          _buildStatColumn('Rating', '4.8'), // Overall rating
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
      tabs: <Widget>[
        Tab(text: 'My Courses'),
        Tab(text: 'Course Reviews'),
      ],
    );
  }

  Widget _buildTabBarView() {
    return SizedBox(
      height: 400.h,
      child: TabBarView(
        controller: _tabController,
        children: <Widget>[
          _buildMyCoursesTab(),
          _buildCourseReviewsTab(),
        ],
      ),
    );
  }

  Widget _buildMyCoursesTab() {
    // Replace with dynamic content
    return Center(child: Text('My Courses'));
  }

  Widget _buildCourseReviewsTab() {
    // Replace with dynamic content
    return Center(child: Text('Course Reviews'));
  }
}
