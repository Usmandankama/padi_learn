import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:padi_learn/controller/settings_controller.dart';
import 'package:padi_learn/screens/components/settings_tile.dart';
import 'package:padi_learn/services/supabase.dart';
import 'package:padi_learn/utils/colors.dart';
import 'package:padi_learn/utils/app_info.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Subscribes to theme changes; without this the screen keeps
    // painting the previous theme's colours when the mode flips.
    AppColors.watch(context);
    final settings = Get.find<SettingsController>();

    return Scaffold(
      backgroundColor: AppColors.palette.ground,
      appBar: AppBar(
        backgroundColor: AppColors.palette.ground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.palette.ink),
        title: Text(
          'Settings',
          style: GoogleFonts.poppins(
            color: AppColors.primaryColor,
            fontSize: 20.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 32.h),
        children: [
          // Just the password here. Editing your name and photo is the button
          // under the name card on the Profile screen, beside the things it
          // changes — and account actions keep one home rather than two.
          SettingsSection(
            title: 'ACCOUNT',
            children: [
              SettingsTile(
                icon: Icons.lock_outline,
                title: 'Change Password',
                onTap: () => _changePassword(context),
              ),
            ],
          ),
          SizedBox(height: 24.h),
          SettingsSection(
            title: 'PREFERENCES',
            children: [
              SettingsTile(
                icon: Icons.notifications_none_rounded,
                title: 'Notifications',
                onTap: () => settings
                    .setNotifications(!settings.notificationsEnabled.value),
                trailing: Obx(
                  () => Switch.adaptive(
                    value: settings.notificationsEnabled.value,
                    activeColor: AppColors.primaryColor,
                    onChanged: settings.setNotifications,
                  ),
                ),
              ),
              SettingsTile(
                icon: Icons.dark_mode_outlined,
                title: 'Dark Mode',
                onTap: () => settings.setDarkMode(!settings.isDarkMode.value),
                trailing: Obx(
                  () => Switch.adaptive(
                    value: settings.isDarkMode.value,
                    activeColor: AppColors.primaryColor,
                    onChanged: settings.setDarkMode,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 24.h),
          SizedBox(height: 32.h),
          Center(
            child: Text(
              'Version $kAppVersion',
              style: GoogleFonts.poppins(
                color: AppColors.palette.inkSoft,
                fontSize: 12.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _changePassword(BuildContext context) {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final isSaving = false.obs;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
          child: Container(
            // Keeps Save clear of the device navigation bar. `padding` (not
            // `viewPadding`) so it collapses when the keyboard covers that bar,
            // which the outer viewInsets padding is already accounting for.
            padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w,
                24.h + MediaQuery.of(sheetContext).padding.bottom),
            decoration: BoxDecoration(
              color: Theme.of(sheetContext).scaffoldBackgroundColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'Change Password',
                    style: GoogleFonts.poppins(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  TextFormField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: _fieldDecoration('New password'),
                    validator: (v) => (v == null || v.length < 6)
                        ? 'Must be at least 6 characters'
                        : null,
                  ),
                  SizedBox(height: 12.h),
                  TextFormField(
                    controller: confirmController,
                    obscureText: true,
                    decoration: _fieldDecoration('Confirm password'),
                    validator: (v) => v != passwordController.text
                        ? 'Passwords do not match'
                        : null,
                  ),
                  SizedBox(height: 20.h),
                  Obx(
                    () => SizedBox(
                      width: double.infinity,
                      height: 50.h,
                      child: ElevatedButton(
                        onPressed: isSaving.value
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                isSaving.value = true;
                                try {
                                  await supabase.auth.updateUser(
                                    UserAttributes(
                                        password: passwordController.text),
                                  );
                                  if (sheetContext.mounted) {
                                    Navigator.pop(sheetContext);
                                  }
                                  Get.snackbar('Success',
                                      'Your password has been updated.',
                                      snackPosition: SnackPosition.BOTTOM);
                                } on AuthException catch (e) {
                                  isSaving.value = false;
                                  Get.snackbar('Error', e.message,
                                      snackPosition: SnackPosition.BOTTOM);
                                } catch (e) {
                                  isSaving.value = false;
                                  Get.snackbar(
                                      'Error', 'Could not update password.',
                                      snackPosition: SnackPosition.BOTTOM);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                        ),
                        child: isSaving.value
                            ? SizedBox(
                                width: 22.w,
                                height: 22.w,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : Text(
                                'Update Password',
                                style: GoogleFonts.poppins(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFFF4F6F5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.r),
        borderSide: BorderSide.none,
      ),
    );
  }
}
