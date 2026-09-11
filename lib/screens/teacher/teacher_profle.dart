import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:padi_learn/controller/teacher_controller.dart';
import 'package:padi_learn/screens/components/settings_tile.dart';
import 'package:padi_learn/screens/notifications/notification_bell.dart';
import 'package:padi_learn/screens/settings/settings_screen.dart';
import 'package:padi_learn/screens/teacher/editprofile_screen.dart';
import 'package:padi_learn/screens/teacher/payout_account_screen.dart';
import 'package:padi_learn/services/auth_service.dart';
import 'package:padi_learn/utils/colors.dart';
import 'package:padi_learn/utils/money.dart';
import 'package:padi_learn/screens/components/profile_support_section.dart';

class TeacherProfileScreen extends StatelessWidget {
  const TeacherProfileScreen({super.key});

  void _editProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditTeacherProfileScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Subscribes to theme changes; without this the screen keeps
    // painting the previous theme's colours when the mode flips.
    AppColors.watch(context);
    final TeacherController controller = Get.find<TeacherController>();

    return Scaffold(
      backgroundColor: AppColors.palette.ground,
      appBar: AppBar(
        backgroundColor: AppColors.palette.ground,
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
        actions: const [NotificationBell()],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 32.h),
        children: [
          _buildHeader(context, controller),
          SizedBox(height: 16.h),
          _buildStats(controller),
          SizedBox(height: 24.h),
          // Two entries only. "My Courses" used to sit here as well — it is the
          // Courses tab in the bottom bar, a shorter route to the same screen —
          // and "Edit Profile" was a third, duplicating the button in the
          // header card directly above, which is where you look to change the
          // name and photo it edits.
          SettingsSection(
            title: 'ACCOUNT',
            children: [
              SettingsTile(
                icon: Icons.account_balance_outlined,
                title: 'Payout Account',
                subtitle: 'Where your earnings are sent',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const PayoutAccountScreen()),
                ),
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
          const ProfileSupportSection(),
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

  Widget _buildHeader(BuildContext context, TeacherController controller) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 24.h, horizontal: 20.w),
      decoration: BoxDecoration(
        color: AppColors.palette.surface,
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
            final name = controller.teacherName.value.trim();
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
                controller.teacherName.value,
                style: GoogleFonts.poppins(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.palette.ink,
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
              'Instructor',
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
              onPressed: () => _editProfile(context),
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

  Widget _buildStats(TeacherController controller) {
    return Obx(
      () => Row(
        children: [
          Expanded(
            child: _statCard(
              icon: Icons.video_library_outlined,
              value: '${controller.totalCoursesUploaded.value}',
              label: 'Courses',
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: _statCard(
              icon: Icons.account_balance_wallet_outlined,
              value: formatNaira(controller.totalEarnings.value),
              label: 'Earnings',
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 18.h, horizontal: 12.w),
      decoration: BoxDecoration(
        color: AppColors.palette.surface,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primaryColor, size: 24.sp),
          SizedBox(height: 8.h),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.palette.ink,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11.sp,
              color: AppColors.palette.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}
