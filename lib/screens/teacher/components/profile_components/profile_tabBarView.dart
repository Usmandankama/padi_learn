import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ProfileTabBarView extends StatelessWidget {
  final TabController tabController;

  const ProfileTabBarView({required this.tabController});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 400.h,
      child: TabBarView(
        controller: tabController,
        children: <Widget>[
          _buildMyCoursesTab(),
          _buildCourseReviewsTab(),
        ],
      ),
    );
  }

  Widget _buildMyCoursesTab() {
    return const Center(child: Text('My Courses'));
  }

  Widget _buildCourseReviewsTab() {
    return const Center(child: Text('Course Reviews'));
  }
}
