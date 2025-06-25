import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:padi_learn/controller/user_controller.dart';
import 'package:padi_learn/utils/colors.dart';
import 'package:padi_learn/screens/settings/settings_screen.dart';

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
    final UserController controller = Get.find<UserController>();

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
            SizedBox(height: 20.h),
            // _buildProfileActions(),
            _buildTabBar(),
            _buildTabBarView(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    final UserController controller = Get.find<UserController>();
    return Center(
      child: Column(
        children: <Widget>[
          CircleAvatar(
            radius: 50.r,
            backgroundImage:  NetworkImage(
              controller.profileImageUrl.value.isNotEmpty
                  ? controller.profileImageUrl.value
                  : 'https://via.placeholder.com/150', // Placeholder image
            ), // Replace with profile image
          ),
          SizedBox(height: 10.h),
          Obx(() => Text(
                controller.userName.value,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 24.sp,
                  color: AppColors.primaryColor,
                ),
              )),
          SizedBox(height: 5.h),
        ],
      ),
    );
  }

  // Widget _buildProfileActions() {
  //   return Padding(
  //     padding: EdgeInsets.symmetric(horizontal: 30.w, vertical: 20.h),
  //     child: ElevatedButton(
  //       onPressed: () {
  //         // Handle Edit Profile
  //       },
  //       style: ElevatedButton.styleFrom(
  //         backgroundColor: AppColors.primaryColor,
  //         padding: const EdgeInsets.all(15),
  //         shape: RoundedRectangleBorder(
  //           borderRadius: BorderRadius.circular(12.r),
  //         ),
  //       ),
  //       child: Text(
  //         'Edit Profile',
  //         style: TextStyle(
  //           color: AppColors.appWhite,
  //           fontSize: 16.sp,
  //         ),
  //       ),
  //     ),
  //   );
  // }

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
