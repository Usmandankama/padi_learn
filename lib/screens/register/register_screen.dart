import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:padi_learn/screens/components/custom_role_dropdown.dart';
import 'package:padi_learn/screens/components/custom_textfield.dart';
import 'package:padi_learn/screens/home/home_shell.dart';
import 'package:padi_learn/screens/login/login_screen.dart';
import 'package:padi_learn/utils/colors.dart';
import 'package:padi_learn/utils/utils.dart';

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

  // Error messages for each field
  String? nameError, emailError, passwordError, confirmPasswordError, roleError;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void _submitForm() async {
    setState(() {
      // Reset errors
      nameError =
          emailError = passwordError = confirmPasswordError = roleError = null;
    });

    // Validate fields
    if (nameController.text.isEmpty) {
      setState(() => nameError = 'Name is required');
      return;
    }
    if (emailController.text.isEmpty) {
      setState(() => emailError = 'Email is required');
      return;
    }
    if (passwordController.text.isEmpty) {
      setState(() => passwordError = 'Password is required');
      return;
    }
    if (passwordController.text != confirmPasswordController.text) {
      setState(() => confirmPasswordError = 'Passwords do not match');
      return;
    }
    if (selectedRole == 'Select role') {
      setState(() => roleError = 'Please select a role');
      return;
    }

    // Proceed with registration if no errors
    final email = emailController.text;
    final password = passwordController.text;
    final name = nameController.text;
    final role = selectedRole;

    try {
      await signUp(context, email, password, role!, name);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const HomeShell(),
        ),
      );
    } catch (e) {
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
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(), // Dismiss keyboard on tap
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: AppColors.appWhite,
        body: SingleChildScrollView(
          padding: EdgeInsets.all(16.0.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              SizedBox(height: 50.h),
              // Title
              Text(
                'Register',
                style: GoogleFonts.playfair(
                  color: AppColors.primaryColor,
                  fontSize: 50.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 40.h),
              CustomTextfield(
                label: 'Name',
                icon: Icons.person,
                controller: nameController,
                borderColor: nameError != null ? Colors.red : null,
              ),
              if (nameError != null)
                Text(nameError!,
                    style: TextStyle(color: Colors.red, fontSize: 12.sp)),
              SizedBox(height: 20.h),
              CustomTextfield(
                label: 'Email',
                icon: Icons.email,
                controller: emailController,
                borderColor: emailError != null ? Colors.red : null,
              ),
              if (emailError != null)
                Text(emailError!,
                    style: TextStyle(color: Colors.red, fontSize: 12.sp)),
              SizedBox(height: 20.h),
              CustomTextfield(
                label: 'Password',
                icon: Icons.lock,
                obscureText: true,
                controller: passwordController,
                borderColor: passwordError != null ? Colors.red : null,
              ),
              if (passwordError != null)
                Text(passwordError!,
                    style: TextStyle(color: Colors.red, fontSize: 12.sp)),
              SizedBox(height: 20.h),
              CustomTextfield(
                label: 'Confirm Password',
                icon: Icons.lock,
                obscureText: true,
                controller: confirmPasswordController,
                borderColor: confirmPasswordError != null ? Colors.red : null,
              ),
              if (confirmPasswordError != null)
                Text(confirmPasswordError!,
                    style: TextStyle(color: Colors.red, fontSize: 12.sp)),
              SizedBox(height: 20.h),
              CustomRoleDropdown(
                value: selectedRole,
                items: roles,
                onChanged: (String? newValue) {
                  setState(() {
                    selectedRole = newValue;
                  });
                },
                borderColor: roleError != null ? Colors.red : null,
              ),
              if (roleError != null)
                Text(roleError!,
                    style: TextStyle(color: Colors.red, fontSize: 12.sp)),
              SizedBox(height: 40.h),
              ElevatedButton(
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  padding: EdgeInsets.symmetric(
                      horizontal: 80.0.w, vertical: 20.0.h),
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
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
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
      ),
    );
  }
}
