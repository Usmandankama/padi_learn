import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:padi_learn/controller/user_controller.dart';
import 'package:padi_learn/screens/components/settings_tile.dart';
import 'package:padi_learn/screens/settings/settings_screen.dart';
import 'package:padi_learn/screens/teacher/editprofile_screen.dart';
import 'package:padi_learn/services/auth_service.dart';
import 'package:padi_learn/utils/colors.dart';

class StudentProfileScreen extends StatelessWidget {
  const StudentProfileScreen({super.key});

  void _editProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditTeacherProfileScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final UserController controller = Get.find<UserController>();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F8FA),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          'Profile',
          style: GoogleFonts.poppins(
            color: AppColors.primaryColor,
            fontSize: 20.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined,
                color: AppColors.primaryColor),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 32.h),
        children: [
          _ProfileHeaderCard(
            controller: controller,
            roleLabel: 'Student',
            onEdit: () => _editProfile(context),
          ),
          SizedBox(height: 24.h),
          SettingsSection(
            title: 'ACCOUNT',
            children: [
              SettingsTile(
                icon: Icons.person_outline,
                title: 'Edit Profile',
                onTap: () => _editProfile(context),
              ),
              SettingsTile(
                icon: Icons.settings_outlined,
                title: 'Settings',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
            ],
          ),
          SizedBox(height: 24.h),
          SettingsSection(
            title: 'SUPPORT',
            children: [
              SettingsTile(
                icon: Icons.help_outline,
                title: 'Help & Support',
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Support is coming soon')),
                ),
              ),
              SettingsTile(
                icon: Icons.info_outline,
                title: 'About',
                onTap: () => showAboutDialog(
                  context: context,
                  applicationName: 'PadiLearn',
                  applicationVersion: '1.0.0',
                  applicationLegalese: '© 2026 PadiLearn',
                ),
              ),
            ],
          ),
          SizedBox(height: 24.h),
          SettingsSection(
            children: [
              SettingsTile(
                icon: Icons.logout,
                title: 'Logout',
                iconColor: Colors.red,
                titleColor: Colors.red,
                trailing: const SizedBox.shrink(),
                onTap: () => signOut(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Reusable profile header: avatar (image or initials), name, role chip and an
/// "Edit Profile" button.
class _ProfileHeaderCard extends StatelessWidget {
  final UserController controller;
  final String roleLabel;
  final VoidCallback onEdit;

  const _ProfileHeaderCard({
    required this.controller,
    required this.roleLabel,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 24.h, horizontal: 20.w),
      decoration: BoxDecoration(
        color: AppColors.appWhite,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Obx(() {
            final url = controller.profileImageUrl.value;
            final name = controller.userName.value.trim();
            final initial = (name.isNotEmpty && name != 'Loading...')
                ? name.substring(0, 1).toUpperCase()
                : '?';
            return Container(
              width: 88.w,
              height: 88.w,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primaryAccent,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primaryColor, width: 2),
                image: url.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(url), fit: BoxFit.cover)
                    : null,
              ),
              child: url.isNotEmpty
                  ? null
                  : Text(
                      initial,
                      style: GoogleFonts.poppins(
                        fontSize: 32.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryColor,
                      ),
                    ),
            );
          }),
          SizedBox(height: 14.h),
          Obx(() => Text(
                controller.userName.value,
                style: GoogleFonts.poppins(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.richBlack,
                ),
              )),
          SizedBox(height: 8.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 5.h),
            decoration: BoxDecoration(
              color: AppColors.primaryAccent,
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Text(
              roleLabel,
              style: GoogleFonts.poppins(
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryColor,
              ),
            ),
          ),
          SizedBox(height: 18.h),
          SizedBox(
            width: double.infinity,
            height: 46.h,
            child: OutlinedButton.icon(
              onPressed: onEdit,
              icon: Icon(Icons.edit_outlined,
                  size: 18.sp, color: AppColors.primaryColor),
              label: Text(
                'Edit Profile',
                style: GoogleFonts.poppins(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryColor,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primaryColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
