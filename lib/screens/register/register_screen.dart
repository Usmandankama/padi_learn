import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:padi_learn/screens/components/custom_role_dropdown.dart';
import 'package:padi_learn/screens/components/custom_textfield.dart';
import 'package:padi_learn/screens/home/home_shell.dart';
import 'package:padi_learn/screens/register/register_screen.dart';
import 'package:padi_learn/screens/forgot_password/forgot_password_screen.dart';
import 'package:padi_learn/utils/colors.dart';
import 'package:padi_learn/utils/utils.dart'; // Import your auth service

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  String? selectedRole = 'Select role';
  final List<String> roles = ['Select role', 'Student', 'Teacher'];

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void _submitForm() async {
    final email = emailController.text;
    final password = passwordController.text;
    final role = selectedRole;

    if (passwordController.text != confirmPasswordController.text) {
      // Show error for password mismatch
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Passwords do not match'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (role == 'Select role') {
      // Show error for role selection
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a role'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await signUp(context, email, password, role!);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const HomeShell(),
        ),
      );
    } catch (e) {
      // This block is optional since errors are already handled in the signUp method
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error signing up: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appWhite,
      body: Padding(
        padding: EdgeInsets.all(16.0.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'Register',
              style: TextStyle(
                fontSize: 28.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryColor,
              ),
            ),
            SizedBox(height: 40.h),
            CustomTextfield(
              label: 'Name',
              icon: Icons.person,
              controller: nameController,
            ),
            SizedBox(height: 20.h),
            CustomTextfield(
              label: 'Email',
              icon: Icons.email,
              controller: emailController,
            ),
            SizedBox(height: 20.h),
            CustomTextfield(
              label: 'Password',
              icon: Icons.lock,
              obscureText: true,
              controller: passwordController,
            ),
            SizedBox(height: 20.h),
            CustomTextfield(
              label: 'Confirm Password',
              icon: Icons.lock,
              obscureText: true,
              controller: confirmPasswordController,
            ),
            SizedBox(height: 20.h),
            CustomRoleDropdown(
              value: selectedRole,
              items: roles,
              onChanged: (String? newValue) {
                setState(() {
                  selectedRole = newValue;
                });
              },
            ),
            SizedBox(height: 40.h),
            ElevatedButton(
              onPressed: _submitForm,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                padding:
                    EdgeInsets.symmetric(horizontal: 80.0.w, vertical: 20.0.h),
              ),
              child: Text(
                'Register',
                style: TextStyle(
                  fontSize: 18.sp,
                  color: AppColors.appWhite,
                ),
              ),
            ),
            SizedBox(height: 20.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Text('Already have an account?'),
                TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RegisterScreen(),
                      ),
                    );
                  },
                  child: Text(
                    'Login',
                    style: TextStyle(
                      color: AppColors.primaryColor,
                      fontSize: 14.sp,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
