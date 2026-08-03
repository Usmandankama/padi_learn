import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:padi_learn/services/auth_service.dart';
import 'package:padi_learn/services/supabase.dart';
import 'package:padi_learn/screens/components/primary_button.dart';
import 'package:padi_learn/screens/home/components/bottom_nav_bar.dart';
import 'package:padi_learn/screens/marketplace/marketplace_screen.dart';
import 'package:padi_learn/screens/student/student_dashboard.dart';
import 'package:padi_learn/screens/login/login_screen.dart';
import 'package:padi_learn/screens/teacher/my_courses.dart';
import 'package:padi_learn/utils/colors.dart';
import '../student/student_profile_screen.dart';
import '../teacher/teacher_dashboard.dart';
import '../teacher/teacher_profle.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  _HomeShellState createState() => _HomeShellState();
}

/// What the shell is currently able to show.
enum _ShellStatus { loading, ready, offline }

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;
  bool isStudent = true;
  List<Widget> _screens = [];
  _ShellStatus _status = _ShellStatus.loading;

  @override
  void initState() {
    super.initState();
    _initializeUserRole();
  }

  /// Resolves which shell to build.
  ///
  /// The three outcomes are deliberately kept apart. A failed *request* is not
  /// the same as a missing account: this used to treat both as "go to login",
  /// so launching without a network bounced a signed-in user to a login screen
  /// that also needs the network — a dead end that never reached any of the
  /// offline-cached data.
  Future<void> _initializeUserRole() async {
    if (mounted) setState(() => _status = _ShellStatus.loading);

    final user = supabase.auth.currentUser;
    if (user == null) {
      _goToLogin(); // No session at all.
      return;
    }

    String? role;
    var usedCache = false;

    try {
      final data = await supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();

      // The request succeeded and there is genuinely no profile row (an
      // orphaned session, or a signup whose profile was never created). That
      // is a real dead session, so clear it.
      if (data == null || data['role'] == null) {
        await supabase.auth.signOut();
        _goToLogin();
        return;
      }

      role = data['role'] as String;
      await cacheUserRole(user.id, role);
    } catch (e) {
      // Could not reach the server. Carry on with the last known role instead
      // of throwing the user out.
      debugPrint('Could not fetch user role: $e');
      role = await cachedUserRole(user.id);
      usedCache = true;
    }

    if (!mounted) return;

    if (role == null) {
      // Offline with nothing cached — offer a retry rather than a login form
      // that cannot succeed either.
      setState(() => _status = _ShellStatus.offline);
      return;
    }

    setState(() {
      isStudent = role == 'Student';
      _screens = isStudent
          ? [
              const StudentDashboard(),
              const MarketplaceScreen(
                userRole: 'Student',
              ),
              const StudentProfileScreen()
            ]
          : [
              // The dashboard links to the Courses tab rather than
              // duplicating the list.
              TeacherDashboardScreen(
                onOpenCourses: () => _onItemTapped(1),
              ),
              const TeacherMyCoursesPage(),
              const TeacherProfileScreen()
            ];
      _status = _ShellStatus.ready;
    });

    if (usedCache && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("You're offline — showing your saved courses."),
        ),
      );
    }
  }

  void _goToLogin() {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ready = _status == _ShellStatus.ready && _screens.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.appWhite,
      body: _buildBody(ready),
      // The bar is only meaningful once there are screens behind it.
      bottomNavigationBar: ready
          ? CustomBottomNavBar(
              selectedIndex: _selectedIndex,
              onItemTapped: _onItemTapped,
              // isStudent: isStudent,
            )
          : null,
    );
  }

  Widget _buildBody(bool ready) {
    if (ready) return _screens[_selectedIndex];
    if (_status == _ShellStatus.offline) return _buildOffline();
    return const AppLoader();
  }

  Widget _buildOffline() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 48.sp, color: AppColors.lightGrey),
            SizedBox(height: 16.h),
            Text(
              "You're offline",
              style: GoogleFonts.poppins(
                fontSize: 17.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.richBlack,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'We could not reach PadiLearn. Check your connection and try '
              'again — you stay signed in.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12.5.sp,
                color: AppColors.fontGrey,
              ),
            ),
            SizedBox(height: 24.h),
            ElevatedButton.icon(
              onPressed: _initializeUserRole,
              icon: const Icon(Icons.refresh),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: AppColors.appWhite,
                padding:
                    EdgeInsets.symmetric(horizontal: 28.w, vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              label: Text(
                'Try again',
                style: GoogleFonts.poppins(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(height: 8.h),
            TextButton(
              onPressed: () => signOut(context),
              child: Text(
                'Sign out',
                style: GoogleFonts.poppins(
                  fontSize: 12.5.sp,
                  color: AppColors.fontGrey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
