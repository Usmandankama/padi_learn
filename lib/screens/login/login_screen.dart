import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:padi_learn/screens/components/custom_textfield.dart';
import 'package:padi_learn/screens/register/register_screen.dart';
import 'package:padi_learn/screens/description/forgot_password/forgot_password_screen.dart';
import 'package:padi_learn/utils/colors.dart';
import 'package:padi_learn/utils/utils.dart'; // Import your utils.dart here

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final GlobalKey<ScaffoldMessengerState> _scaffoldKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    await login(context, emailController.text, passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      key: _scaffoldKey,
      backgroundColor: AppColors.appWhite,
      body: Padding(
        padding: EdgeInsets.all(16.0.w), // Use ScreenUtil for padding
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'Login',
              style: TextStyle(
                fontSize: 28.sp, // Use ScreenUtil for font size
                fontWeight: FontWeight.bold,
                color: AppColors.primaryColor,
              ),
            ),
            SizedBox(height: 40.h), // Use ScreenUtil for spacing
            CustomTextfield(
              controller: emailController,
              label: 'Email',
              icon: Icons.email,
              obscureText: false,
            ),
            SizedBox(height: 20.h),
            CustomTextfield(
              controller: passwordController,
              label: 'Password',
              icon: Icons.lock,
              obscureText: true,
            ),
            SizedBox(height: 20.h),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ForgotPasswordScreen(),
                    ),
                  );
                },
                child: Text(
                  'Forgot Password?',
                  style: TextStyle(
                    color: AppColors.primaryColor,
                    fontSize: 14.sp,
                  ),
                ),
              ),
            ),
            SizedBox(height: 40.h),
            ElevatedButton(
              onPressed: _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor, // Background color
                padding: EdgeInsets.symmetric(
                    horizontal: 80.0.w, vertical: 20.0.h), // Button padding
              ),
              child: Text(
                'Login',
                style: TextStyle(
                  fontSize: 18.sp, // Font size for button text
                  color: AppColors.appWhite,
                ),
              ),
            ),
            SizedBox(height: 20.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Text('Don\'t have an account?'),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RegisterScreen(),
                      ),
                    );
                  },
                  child: Text(
                    'Register',
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
