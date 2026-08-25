import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:padi_learn/screens/components/primary_button.dart';
import 'package:padi_learn/screens/home/home_shell.dart';
import 'package:padi_learn/services/auth_service.dart';
import 'package:padi_learn/utils/colors.dart';

/// Asks a signed-in user whether they are here to learn or to teach.
///
/// Only ever shown when `profiles.role` is null, which in practice means a
/// Google/Apple signup: those hand back an identity and nothing else, so the
/// role that the register form collects has to be asked for separately. An
/// email signup already carries one and never reaches this screen.
///
/// There is deliberately no back button and no skip. The whole app branches on
/// role — `HomeShell` cannot build either shell without one — so leaving here
/// unanswered has nowhere to go but a loop back to this screen.
class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String? _selected;
  bool _isSaving = false;

  Future<void> _confirm() async {
    final role = _selected;
    if (role == null) return;

    setState(() => _isSaving = true);
    try {
      final claimed = await claimRole(role);

      // `claim_role` returns the role actually in force, which can differ from
      // the tap if a previous attempt landed after its response was lost. Cache
      // what the server says, never what the button said.
      final uid = currentUserId;
      if (uid != null) await cacheUserRole(uid, claimed);

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomeShell()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save your choice. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 12.h),
              Text(
                'One last thing',
                textAlign: TextAlign.center,
                style: GoogleFonts.playfair(
                  color: AppColors.primaryColor,
                  fontSize: 30.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 10.h),
              Text(
                'How do you want to use PadiLearn?',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.fontGrey, fontSize: 14.sp),
              ),
              SizedBox(height: 32.h),
              _RoleCard(
                role: 'Student',
                title: 'I want to learn',
                blurb: 'Browse the marketplace, enrol in courses and track '
                    'your progress.',
                icon: Icons.school_rounded,
                selected: _selected == 'Student',
                onTap: _isSaving ? null : () => setState(() => _selected = 'Student'),
              ),
              SizedBox(height: 14.h),
              _RoleCard(
                role: 'Teacher',
                title: 'I want to teach',
                blurb: 'Publish courses, upload lessons and earn from your '
                    'students.',
                icon: Icons.cast_for_education_rounded,
                selected: _selected == 'Teacher',
                onTap: _isSaving ? null : () => setState(() => _selected = 'Teacher'),
              ),
              SizedBox(height: 28.h),
              PrimaryButton(
                label: 'Continue',
                isLoading: _isSaving,
                onPressed: _selected == null ? null : _confirm,
              ),
              SizedBox(height: 16.h),
              Text(
                'This decides which version of the app you see, and cannot be '
                'changed from here later.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.fontGrey, fontSize: 11.5.sp),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String role;
  final String title;
  final String blurb;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  const _RoleCard({
    required this.role,
    required this.title,
    required this.blurb,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.all(18.w),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryAccent : AppColors.appWhite,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: selected ? AppColors.primaryColor : AppColors.lightGrey,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 44.r,
              width: 44.r,
              decoration: BoxDecoration(
                color: AppColors.primaryColor,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(icon, color: AppColors.appWhite, size: 24.sp),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.richBlack,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    blurb,
                    style: GoogleFonts.poppins(
                      fontSize: 12.sp,
                      color: AppColors.fontGrey,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? AppColors.primaryColor : AppColors.lightGrey,
              size: 22.sp,
            ),
          ],
        ),
      ),
    );
  }
}
