import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'package:padi_learn/screens/home/home_shell.dart';
import 'package:padi_learn/services/auth_service.dart';
import 'package:padi_learn/utils/colors.dart';

/// The "or continue with" block shared by the login and register screens.
///
/// Both screens end in the same place, so the whole flow lives here rather
/// than being written twice: sign in, then hand over to [HomeShell], which
/// resolves the role and diverts to the picker if the provider could not
/// supply one. Renders nothing at all when no provider is configured, so an
/// unconfigured build simply looks like the app did before.
class SocialSignIn extends StatefulWidget {
  const SocialSignIn({super.key});

  @override
  State<SocialSignIn> createState() => _SocialSignInState();
}

class _SocialSignInState extends State<SocialSignIn> {
  /// Which provider is mid-flight, so the other button can be disabled without
  /// a second flag.
  String? _busy;

  Future<void> _run(String provider, Future<bool> Function() signIn) async {
    if (_busy != null) return;
    setState(() => _busy = provider);

    final ok = await signIn();

    if (!mounted) return;
    setState(() => _busy = null);
    if (!ok) return; // Cancelled, or already reported by the service.

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const HomeShell()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final showGoogle = isGoogleSignInConfigured;
    final showApple = isAppleSignInAvailable;
    if (!showGoogle && !showApple) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: 20.h),
        Row(
          children: [
            const Expanded(child: Divider(color: AppColors.lightGrey)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              child: Text(
                'or continue with',
                style: TextStyle(color: AppColors.fontGrey, fontSize: 12.sp),
              ),
            ),
            const Expanded(child: Divider(color: AppColors.lightGrey)),
          ],
        ),
        SizedBox(height: 20.h),
        if (showGoogle)
          _GoogleButton(
            isLoading: _busy == 'google',
            onPressed: _busy != null
                ? null
                : () => _run('google', () => signInWithGoogle(context)),
          ),
        if (showGoogle && showApple) SizedBox(height: 12.h),
        if (showApple)
          SizedBox(
            height: 52.h,
            // Apple's own widget rather than a themed copy: the mark, wording
            // and proportions are prescribed by their Human Interface
            // Guidelines, and App Review does check.
            child: SignInWithAppleButton(
              height: 52.h,
              borderRadius: BorderRadius.circular(14.r),
              onPressed: () => _run('apple', () => signInWithApple(context)),
            ),
          ),
      ],
    );
  }
}

class _GoogleButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onPressed;

  const _GoogleButton({required this.isLoading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52.h,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.appWhite,
          side: const BorderSide(color: AppColors.lightGrey),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.r),
          ),
        ),
        child: isLoading
            ? SizedBox(
                width: 20.w,
                height: 20.w,
                child: const CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Google's guidelines require their own mark, which cannot be
                  // redrawn or substituted — drop the official PNG in as
                  // `assets/branding/google_logo.png`. Until it is there the
                  // button still works, just without the mark.
                  Image.asset(
                    'assets/branding/google_logo.png',
                    height: 20.sp,
                    width: 20.sp,
                    errorBuilder: (_, __, ___) => SizedBox(width: 20.sp),
                  ),
                  SizedBox(width: 12.w),
                  Text(
                    'Continue with Google',
                    style: GoogleFonts.poppins(
                      fontSize: 14.5.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.richBlack,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
