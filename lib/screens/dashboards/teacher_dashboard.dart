import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:padi_learn/utils/colors.dart';

class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  _TeacherDashboardScreenState createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  final String teacherName = "John Doe"; // Replace with actual teacher's name
  final String profileImageUrl =
      "https://via.placeholder.com/150"; // Replace with actual profile image URL

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
        iconTheme: IconThemeData(color: AppColors.primaryColor),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 16.0.w, vertical: 16.0.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildProfileSection(),
            SizedBox(height: 20.h),
            Text(
              'Course Analytics',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryColor,
              ),
            ),
            SizedBox(height: 10.h),
            _buildAnalyticsSection(),
            SizedBox(height: 20.h),
            Text(
              'Your Courses',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryColor,
              ),
            ),
            SizedBox(height: 10.h),
            _buildYourCoursesList(),
            SizedBox(height: 20.h),
            _buildUploadCourseButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: <Widget>[
        CircleAvatar(
          radius: 30.r,
          backgroundImage: NetworkImage(profileImageUrl),
        ),
        SizedBox(width: 15.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              teacherName,
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryColor,
              ),
            ),
            Text(
              'Teacher',
              style: TextStyle(
                fontSize: 16.sp,
                color: AppColors.primaryColor.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAnalyticsSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        _buildAnalyticsItem('Total Earnings', '\$5000', Icons.monetization_on),
        SizedBox(width: 10.w),
        _buildAnalyticsItem('Courses Sold', '200', Icons.school),
        SizedBox(width: 10.w),
        _buildAnalyticsItem('Avg. Rating', '4.5/5', Icons.star),
      ],
    );
  }

  Widget _buildAnalyticsItem(String title, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(16.0.w),
        decoration: BoxDecoration(
          color: AppColors.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15.r),
        ),
        child: Column(
          children: <Widget>[
            Icon(icon, color: AppColors.primaryColor, size: 30.sp),
            SizedBox(height: 10.h),
            Text(
              title,
              style: TextStyle(
                fontSize: 14.sp,
                color: AppColors.primaryColor,
              ),
            ),
            SizedBox(height: 5.h),
            Text(
              value,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildYourCoursesList() {
    return ListView.builder(
      physics: NeverScrollableScrollPhysics(), // Prevent scrolling
      shrinkWrap: true,
      itemCount: 5, // Replace with your dynamic item count
      itemBuilder: (context, index) {
        return Container(
          margin: EdgeInsets.only(bottom: 16.h),
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: AppColors.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Course Title',
                    style: TextStyle(
                      color: AppColors.primaryColor,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 5.h),
                  Text(
                    'Students Enrolled: 50', // Placeholder for student count
                    style: TextStyle(
                      color: AppColors.primaryColor,
                      fontSize: 14.sp,
                    ),
                  ),
                ],
              ),
              Row(
                children: <Widget>[
                  IconButton(
                    icon: Icon(Icons.edit, color: AppColors.primaryColor),
                    onPressed: () {
                      // Handle course edit
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.delete, color: AppColors.primaryColor),
                    onPressed: () {
                      // Handle course delete
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUploadCourseButton(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () {
        // Navigate to course upload screen
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryColor,
        padding: EdgeInsets.symmetric(horizontal: 60.0.w, vertical: 20.0.h),
      ),
      icon: Icon(Icons.upload_file, color: AppColors.appWhite),
      label: Text(
        'Upload Course',
        style: TextStyle(
          fontSize: 18.sp,
          color: AppColors.appWhite,
        ),
      ),
    );
  }
}
