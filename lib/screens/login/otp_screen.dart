import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:padi_learn/screens/login/login_screen.dart';
import 'package:padi_learn/utils/colors.dart';

class OTPScreen extends StatelessWidget {
  const OTPScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appWhite,
      body: Padding(
        padding: EdgeInsets.all(16.0.w), // Use ScreenUtil for padding
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'Enter OTP',
              style: TextStyle(
                fontSize: 28.sp, // Use ScreenUtil for font size
                fontWeight: FontWeight.bold,
                color: AppColors.primaryColor,
              ),
            ),
            SizedBox(height: 40.h),
            Text(
              'We have sent an OTP to your email. Please enter it below to verify your account.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16.sp, color: AppColors.fontGrey),
            ),
            SizedBox(height: 40.h),
            _buildOtpFields(),
            SizedBox(height: 40.h),
            ElevatedButton(
              onPressed: () {
                // Handle OTP verification logic
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                padding:
                    EdgeInsets.symmetric(horizontal: 80.0.w, vertical: 20.0.h),
              ),
              child: Text(
                'Verify OTP',
                style: TextStyle(
                  fontSize: 18.sp, // Font size for button text
                  color: AppColors.appWhite,
                ),
              ),
            ),
            SizedBox(height: 20.h),
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
                'Back to Login',
                style: TextStyle(
                  color: AppColors.primaryColor,
                  fontSize: 14.sp,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOtpFields() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(6, (index) {
        return SizedBox(
          width: 40.w,
          child: TextField(
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              contentPadding: EdgeInsets.symmetric(vertical: 10.h),
            ),
          ),
        );
      }),
    );
  }
}
