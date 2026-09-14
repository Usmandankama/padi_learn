import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:padi_learn/controller/teacher_controller.dart';
import 'package:padi_learn/controller/user_controller.dart';
import 'package:padi_learn/screens/components/custom_textfield.dart';
import 'package:padi_learn/screens/components/primary_button.dart';
import 'package:padi_learn/services/supabase.dart';
import 'package:padi_learn/utils/colors.dart';

class EditTeacherProfileScreen extends StatefulWidget {
  const EditTeacherProfileScreen({super.key});

  @override
  State<EditTeacherProfileScreen> createState() =>
      _EditTeacherProfileScreenState();
}

class _EditTeacherProfileScreenState extends State<EditTeacherProfileScreen> {
  File? _image;
  String? _profileImageUrl;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String _initialEmail = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = supabase.auth.currentUser;

    // Every path below must clear `_loading` — an early return or a thrown
    // request used to leave the screen on a spinner with no way out.
    try {
      if (user == null) return;

      final data = await supabase
          .from('profiles')
          .select('name, profile_image_url')
          .eq('id', user.id)
          .maybeSingle();

      _nameController.text = (data?['name'] as String?) ?? '';
      _emailController.text = user.email ?? '';
      _initialEmail = user.email ?? '';
      _profileImageUrl = data?['profile_image_url'] as String?;
    } catch (e) {
      if (mounted) {
        Get.snackbar('Error', 'Could not load your profile.',
            snackPosition: SnackPosition.BOTTOM);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() => _image = File(picked.path));
    }
  }

  Future<void> _uploadProfileImage(String userId) async {
    if (_image == null) return;
    final path = '$userId/avatar.jpg';
    await supabase.storage.from('profile-images').upload(
          path,
          _image!,
          fileOptions:
              const FileOptions(contentType: 'image/jpeg', upsert: true),
        );
    final publicUrl =
        supabase.storage.from('profile-images').getPublicUrl(path);
    final bustedUrl = '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';
    await supabase
        .from('profiles')
        .update({'profile_image_url': bustedUrl}).eq('id', userId);
    _profileImageUrl = bustedUrl;
  }

  Future<void> _updateProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      Get.snackbar('Name required', 'Please enter your name.',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    setState(() => _saving = true);
    final user = supabase.auth.currentUser;
    if (user == null) {
      setState(() => _saving = false);
      return;
    }

    final newEmail = _emailController.text.trim();
    final emailChanged = newEmail.isNotEmpty && newEmail != _initialEmail;

    try {
      // 1. Name in the profiles table.
      await supabase.from('profiles').update({'name': name}).eq('id', user.id);

      // 2. Avatar (if a new one was picked).
      await _uploadProfileImage(user.id);

      // 3. Email (Supabase sends a confirmation link to the new address).
      if (emailChanged) {
        await supabase.auth.updateUser(UserAttributes(email: newEmail));
      }

      // 4. Refresh in-memory controllers so the change shows app-wide.
      if (Get.isRegistered<UserController>()) {
        await Get.find<UserController>().fetchUserInfo();
      }
      if (Get.isRegistered<TeacherController>()) {
        await Get.find<TeacherController>().fetchTeacherInfo();
      }

      if (!mounted) return;
      Get.snackbar(
        'Profile updated',
        emailChanged
            ? 'Saved. Check your new email to confirm the address change.'
            : 'Your profile has been updated.',
        snackPosition: SnackPosition.BOTTOM,
      );
      Navigator.pop(context);
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        Get.snackbar('Error', e.message, snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        Get.snackbar('Error', 'Could not update profile.',
            snackPosition: SnackPosition.BOTTOM);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Subscribes to theme changes; without this the screen keeps
    // painting the previous theme's colours when the mode flips.
    AppColors.watch(context);
    return Scaffold(
      backgroundColor: AppColors.palette.ground,
      appBar: AppBar(
        backgroundColor: AppColors.palette.ground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.palette.ink),
        title: Text(
          'Edit Profile',
          style: GoogleFonts.poppins(
            color: AppColors.primaryColor,
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _loading
          ? const AppLoader()
          : SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 32.h),
              child: Column(
                children: [
                  _buildAvatar(),
                  SizedBox(height: 28.h),
                  CustomTextfield(
                    controller: _nameController,
                    label: 'Full Name',
                    icon: Icons.person_outline,
                  ),
                  SizedBox(height: 16.h),
                  CustomTextfield(
                    controller: _emailController,
                    label: 'Email',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  SizedBox(height: 8.h),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Changing your email requires confirmation via a link sent to the new address.',
                      style: GoogleFonts.poppins(
                        fontSize: 10.5.sp,
                        color: AppColors.palette.inkSoft,
                      ),
                    ),
                  ),
                  SizedBox(height: 32.h),
                  PrimaryButton(
                    label: 'Save Changes',
                    isLoading: _saving,
                    onPressed: _updateProfile,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildAvatar() {
    final name = _nameController.text.trim();
    final initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';

    ImageProvider? bg;
    if (_image != null) {
      bg = FileImage(_image!);
    } else if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      bg = NetworkImage(_profileImageUrl!);
    }

    return Stack(
      children: [
        Container(
          width: 112.w,
          height: 112.w,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primaryAccent,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primaryColor, width: 2),
            image: bg != null
                ? DecorationImage(image: bg, fit: BoxFit.cover)
                : null,
          ),
          child: bg != null
              ? null
              : Text(
                  initial,
                  style: GoogleFonts.poppins(
                    fontSize: 40.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryColor,
                  ),
                ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: 36.w,
              height: 36.w,
              decoration: BoxDecoration(
                color: AppColors.primaryColor,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.palette.ground, width: 3),
              ),
              child: Icon(Icons.camera_alt, color: Colors.white, size: 18.sp),
            ),
          ),
        ),
      ],
    );
  }
}
