import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final data = await supabase
        .from('profiles')
        .select('name, profile_image_url')
        .eq('id', user.id)
        .maybeSingle();

    _nameController.text = (data?['name'] as String?) ?? '';
    _emailController.text = user.email ?? '';
    setState(() {
      _profileImageUrl = data?['profile_image_url'] as String?;
    });
  }

  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<void> _uploadProfileImage(String userId) async {
    if (_image == null) return;

    final path = '$userId/avatar.jpg';
    await supabase.storage.from('profile-images').upload(
          path,
          _image!,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );

    // Cache-bust the public URL so the new avatar shows immediately.
    final publicUrl = supabase.storage.from('profile-images').getPublicUrl(path);
    final bustedUrl = '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';

    await supabase
        .from('profiles')
        .update({'profile_image_url': bustedUrl}).eq('id', userId);

    setState(() {
      _profileImageUrl = bustedUrl;
    });
  }

  Future<void> _updateProfile() async {
    setState(() => _isLoading = true);

    final user = supabase.auth.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Update display name in the profiles table.
      await supabase
          .from('profiles')
          .update({'name': _nameController.text.trim()}).eq('id', user.id);

      // Update auth email / password if changed.
      if (_emailController.text.trim() != user.email) {
        await supabase.auth
            .updateUser(UserAttributes(email: _emailController.text.trim()));
      }
      if (_passwordController.text.isNotEmpty) {
        await supabase.auth
            .updateUser(UserAttributes(password: _passwordController.text));
      }

      // Upload a new avatar if one was picked.
      await _uploadProfileImage(user.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile',
            style: TextStyle(color: AppColors.primaryColor)),
        backgroundColor: AppColors.appWhite,
        iconTheme: const IconThemeData(color: AppColors.primaryColor),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: <Widget>[
                  Center(
                    child: Stack(
                      children: <Widget>[
                        CircleAvatar(
                          radius: 50.r,
                          backgroundImage: _image != null
                              ? FileImage(_image!)
                              : (_profileImageUrl != null &&
                                          _profileImageUrl!.isNotEmpty
                                      ? NetworkImage(_profileImageUrl!)
                                      : const AssetImage(
                                          'assets/logo/logo_icon_only.png'))
                                  as ImageProvider,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: IconButton(
                            icon: const Icon(Icons.camera_alt,
                                color: AppColors.primaryColor),
                            onPressed: _pickImage,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20.h),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 20.h),
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 20.h),
                  TextField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'New Password',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                  ),
                  SizedBox(height: 20.h),
                  ElevatedButton(
                    onPressed: _updateProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      padding: EdgeInsets.symmetric(vertical: 15.h),
                    ),
                    child: Text('Update Profile',
                        style: TextStyle(
                            color: AppColors.appWhite, fontSize: 16.sp)),
                  ),
                ],
              ),
            ),
    );
  }
}
