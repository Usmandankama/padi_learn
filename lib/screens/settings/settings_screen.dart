// settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:padi_learn/screens/login/login_screen.dart';
import 'package:padi_learn/screens/teacher/editprofile_screen.dart';
import 'package:padi_learn/utils/colors.dart';
import 'package:padi_learn/utils/utils.dart'; // Import the utils file

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: TextStyle(
            color: AppColors.primaryColor,
            fontSize: 22.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primaryColor),
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: 16.0.w, vertical: 20.0.h),
        children: <Widget>[
          _buildSectionTitle('Account Settings'),
          _buildSettingsItem(
            context,
            icon: Icons.person,
            title: 'Edit Profile',
            onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context)=>const EditTeacherProfileScreen()));
            },
          ),
          _buildSettingsItem(
            context,
            icon: Icons.lock,
            title: 'Change Password',
            onTap: () {
              // Navigate to change password screen
            },
          ),
          SizedBox(height: 20.h),
          _buildSectionTitle('Preferences'),
          _buildSettingsItem(
            context,
            icon: Icons.notifications,
            title: 'Notifications',
            trailing: Switch(
              value: true, // Set to user's preference
              onChanged: (bool value) {
                // Handle notification toggle
              },
              activeColor: AppColors.primaryColor,
            ),
            onTap: () {},
          ),
          _buildSettingsItem(
            context,
            icon: Icons.brightness_6,
            title: 'Dark Mode',
            trailing: Switch(
              value: false, // Set to user's theme preference
              onChanged: (bool value) {
                // Handle theme toggle
              },
              activeColor: AppColors.primaryColor,
            ),
            onTap: () {},
          ),
          SizedBox(height: 20.h),
          _buildSectionTitle('General'),
          _buildSettingsItem(
            context,
            icon: Icons.info,
            title: 'About',
            onTap: () {
              // Navigate to about screen
            },
          ),
          _buildSettingsItem(
            context,
            icon: Icons.logout,
            title: 'Logout',
            onTap: () {
              signOut(context); // Use the sign-out method from utils.dart
            },
            titleColor: Colors.red,
          ),
          SizedBox(height: 40.h),
          Center(
            child: Text(
              'Version 1.0.0',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.0.h),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18.sp,
          fontWeight: FontWeight.bold,
          color: AppColors.primaryColor,
        ),
      ),
    );
  }

  Widget _buildSettingsItem(BuildContext context,
      {required IconData icon,
      required String title,
      Widget? trailing,
      Color? titleColor,
      required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primaryColor),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16.sp,
          color: titleColor ?? Colors.black,
        ),
      ),
      trailing: trailing ?? Icon(Icons.arrow_forward_ios, size: 16.sp),
      onTap: onTap,
    );
  }
}
