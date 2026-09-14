import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:padi_learn/config/deep_links.dart';
import 'package:padi_learn/screens/components/primary_button.dart';
import 'package:padi_learn/services/auth_service.dart';
import 'package:padi_learn/services/supabase.dart';
import 'package:padi_learn/utils/colors.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  /// Owned by the State: as a local in `build` it was recreated on every
  /// rebuild (losing the typed text) and never disposed.
  final TextEditingController emailController = TextEditingController();

  bool _sending = false;
  String? _emailError;

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
        child: Center(
          child: SingleChildScrollView(
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
                  'Enter the email you signed up with. We will send you a '
                  'link to set a new password.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 16.sp, color: AppColors.palette.inkSoft),
                ),
                SizedBox(height: 40.h),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  onChanged: (_) {
                    if (_emailError != null) {
                      setState(() => _emailError = null);
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Email',
                    errorText: _emailError,
                    prefixIcon:
                        const Icon(Icons.email, color: AppColors.primaryColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                  ),
                ),
                SizedBox(height: 32.h),
                PrimaryButton(
                  label: 'Send Link',
                  isLoading: _sending,
                  onPressed: _resetPassword,
                ),
                SizedBox(height: 20.h),
                TextButton(
                  // Pop, not push: this screen is only ever opened from the
                  // login screen, and pushing another login stacked a copy
                  // of it on every round trip.
                  onPressed: () => Navigator.maybePop(context),
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
      ),
    );
  }

  Future<void> _resetPassword() async {
    final email = emailController.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _emailError = 'Enter a valid email address');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      // Without redirectTo the mail returns to the project's site URL —
      // a web page that knows nothing about this app — so the user could
      // open the link and still never set a password.
      await supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: DeepLinks.passwordReset,
      );
      // Same wording whether or not the account exists. Supabase doesn't say
      // either, and the app shouldn't become a way to test which emails are
      // registered.
      messenger.showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 8),
          content: Text(
            'If that email has an account, a reset link is on its way from '
            'PadiLearn. Open it on this phone. Check spam if it is not there '
            'in a few minutes.',
          ),
        ),
      );
    } on AuthException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(authEmailErrorMessage(e)),
          backgroundColor: Colors.red,
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not send the email. Check your connection.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}
