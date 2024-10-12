import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:padi_learn/utils/colors.dart';
import 'package:padi_learn/screens/settings/settings_screen.dart'; // Import your settings screen

class StudentProfileScreen extends StatefulWidget {
  const StudentProfileScreen({super.key});

  @override
  _StudentProfileScreenState createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen>
    with SingleTickerProviderStateMixin {
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
        iconTheme: const IconThemeData(color: AppColors.primaryColor),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: AppColors.primaryColor),
            onPressed: () {
              // Navigate to Settings screen
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            _buildProfileHeader(),
            _buildCourseAnalytics(),
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
            backgroundImage: const NetworkImage(
                'https://via.placeholder.com/150'), // Replace with profile image
          ),
          SizedBox(height: 10.h),
          Text(
            'John Doe', // Replace with user's name
            style: TextStyle(
              fontSize: 24.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryColor,
            ),
          ),
          SizedBox(height: 5.h),
          Text(
            '@johndoe', // Replace with user's username
            style: TextStyle(
              fontSize: 16.sp,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseAnalytics() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 16.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          _buildAnalyticsContainer('Courses Completed', '15'),
          _buildAnalyticsContainer('Ongoing Courses', '3'),
          _buildAnalyticsContainer('Hours Spent', '120h'),
        ],
      ),
    );
  }

  Widget _buildAnalyticsContainer(String label, String count) {
    return Expanded(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 5.w),
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: AppColors.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 2,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Text(
              count,
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryColor,
              ),
            ),
            SizedBox(height: 5.h),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileActions() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 30.w, vertical: 20.h),
      child: ElevatedButton(
        onPressed: () {
          // Handle Edit Profile
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryColor,
          padding: EdgeInsets.symmetric(vertical: 15.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
        ),
        child: Text(
          'Edit Profile',
          style: TextStyle(
            color: AppColors.appWhite,
            fontSize: 16.sp,
          ),
        ),
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
        Tab(text: 'My Courses'),
        Tab(text: 'Liked Courses'),
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
          _buildLikedCoursesTab(),
        ],
      ),
    );
  }

  Widget _buildMyCoursesTab() {
    // Replace with dynamic content
    return const Center(child: Text('My Courses'));
  }

  Widget _buildLikedCoursesTab() {
    // Replace with dynamic content
    return const Center(child: Text('Liked Courses'));
  }
}
