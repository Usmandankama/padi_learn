import 'package:flutter/material.dart';
import 'package:padi_learn/config/deep_links.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:padi_learn/screens/login/login_screen.dart';
import 'package:padi_learn/utils/colors.dart';
import 'package:padi_learn/services/supabase.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  /// Owned by the State: as a local in `build` it was recreated on every
  /// rebuild (losing the typed text) and never disposed.
  final TextEditingController emailController = TextEditingController();

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Subscribes to theme changes; without this the screen keeps
    // painting the previous theme's colours when the mode flips.
    AppColors.watch(context);
    return Scaffold(
      backgroundColor: AppColors.palette.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                'Forgot Password',
                style: TextStyle(
                  fontSize: 28.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryColor,
                ),
              ),
              SizedBox(height: 40.h),
              Text(
                'Enter your email to receive a link to reset your password.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 16.sp, color: AppColors.palette.inkSoft),
              ),
              SizedBox(height: 40.h),
              _buildTextField(emailController, 'Email', Icons.email),
              SizedBox(height: 40.h),
              ElevatedButton(
                onPressed: () {
                  _resetPassword(context, emailController.text.trim());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 80.0, vertical: 20.0),
                ),
                child: Text(
                  'Send Link',
                  style: TextStyle(
                    fontSize: 18.sp,
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
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String label, IconData icon) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primaryColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
      ),
    );
  }

  Future<void> _resetPassword(BuildContext context, String email) async {
    try {
      // Without redirectTo the mail returns to the project's site URL —
      // a web page that knows nothing about this app — so the user could
      // open the link and still never set a password.
      await supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: DeepLinks.passwordReset,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset email sent. Check your inbox.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
