import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:padi_learn/utils/colors.dart';
import 'package:padi_learn/services/supabase.dart';

import '../home/home_shell.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 2), _checkUserSignIn);
  }

  Future<void> _checkUserSignIn() async {
    final session = supabase.auth.currentSession;

    if (!mounted) return;
    if (session != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeShell()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const OnboardingScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Light stacked mark (same asset the native splash uses), so it
            // stays visible on the green background. `assets/logo/` was removed
            // and is not declared in pubspec.yaml — loading from there threw on
            // every cold start.
            Image.asset(
              'assets/branding/icon_light_stacked.png',
              width: 220.w,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(
                Icons.school_rounded,
                size: 96.sp,
                color: AppColors.appWhite,
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              'Learn. Teach. Earn.',
              style: TextStyle(
                fontSize: 14.sp,
                color: AppColors.appWhite.withOpacity(0.85),
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(height: 60.h),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.appWhite),
            ),
          ],
        ),
      ),
    );
  }
}
