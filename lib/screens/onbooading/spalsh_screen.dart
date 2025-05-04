import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:padi_learn/utils/colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    // Check the authentication status after 3 seconds
    Timer(const Duration(seconds: 3), _checkUserSignIn);
  }

  // Check if the user is already signed in
  Future<void> _checkUserSignIn() async {
    User? user = FirebaseAuth.instance.currentUser;

    if (mounted) {
      if (user != null) {
        // User is signed in, navigate to HomeShell
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeShell()),
        );
      } else {
        // User is not signed in, navigate to OnboardingScreen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const OnboardingScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryColor,
      body: Center(
        child: CircleAvatar(
          backgroundColor: Colors.white,
          maxRadius: 100.r,
          child: Text(
            'PadiLearn',
            style: TextStyle(
              color: AppColors.primaryColor,
              fontSize: 25.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
