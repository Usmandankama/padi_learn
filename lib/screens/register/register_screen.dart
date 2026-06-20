import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:padi_learn/screens/components/custom_role_dropdown.dart';
import 'package:padi_learn/screens/components/custom_textfield.dart';
import 'package:padi_learn/screens/home/home_shell.dart';
import 'package:padi_learn/screens/login/login_screen.dart';
import 'package:padi_learn/utils/colors.dart';
import 'package:padi_learn/services/auth_service.dart';

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

    final success = await signUp(context, email, password, role!, name);
    if (!mounted) return;

    // Only enter the app if registration actually succeeded. Clear the whole
    // navigation stack so the back button can't return to login/register.
    if (success) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const HomeShell(),
        ),
        (route) => false,
      );
    }
  }

  Widget _fieldError(String? message) {
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: 6.h, left: 4.w),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          message,
          style: TextStyle(color: Colors.red, fontSize: 12.sp),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(), // Dismiss keyboard on tap
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: AppColors.appWhite,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Brand mark
                Center(
                  child: Container(
                    height: 64.r,
                    width: 64.r,
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor,
                      borderRadius: BorderRadius.circular(18.r),
                    ),
                    child: Icon(
                      Icons.school_rounded,
                      color: AppColors.appWhite,
                      size: 34.sp,
                    ),
                  ),
                ),
                SizedBox(height: 24.h),
                Text(
                  'Create account',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.playfair(
                    color: AppColors.primaryColor,
                    fontSize: 32.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Join PadiLearn and start learning',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.fontGrey,
                    fontSize: 14.sp,
                  ),
                ),
                SizedBox(height: 32.h),
                CustomTextfield(
                  label: 'Name',
                  icon: Icons.person_outline,
                  controller: nameController,
                  borderColor: nameError != null ? Colors.red : null,
                ),
                _fieldError(nameError),
                SizedBox(height: 16.h),
                CustomTextfield(
                  label: 'Email',
                  icon: Icons.email_outlined,
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  borderColor: emailError != null ? Colors.red : null,
                ),
                _fieldError(emailError),
                SizedBox(height: 16.h),
                CustomTextfield(
                  label: 'Password',
                  icon: Icons.lock_outline,
                  obscureText: true,
                  controller: passwordController,
                  borderColor: passwordError != null ? Colors.red : null,
                ),
                _fieldError(passwordError),
                SizedBox(height: 16.h),
                CustomTextfield(
                  label: 'Confirm Password',
                  icon: Icons.lock_outline,
                  obscureText: true,
                  controller: confirmPasswordController,
                  borderColor: confirmPasswordError != null ? Colors.red : null,
                ),
                _fieldError(confirmPasswordError),
                SizedBox(height: 16.h),
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
                _fieldError(roleError),
                SizedBox(height: 28.h),
                SizedBox(
                  height: 54.h,
                  child: ElevatedButton(
                    onPressed: _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: AppColors.appWhite,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                    ),
                    child: Text(
                      'Register',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 20.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      'Already have an account?',
                      style: TextStyle(
                        color: AppColors.fontGrey,
                        fontSize: 13.sp,
                      ),
                    ),
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
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
