import 'package:flutter/material.dart';
import 'package:padi_learn/services/supabase.dart';
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

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;
  bool isStudent = true;
  List<Widget> _screens = [];

  @override
  void initState() {
    super.initState();
    _initializeUserRole();
  }

  Future<void> _initializeUserRole() async {
    try {
      final user = supabase.auth.currentUser;

      // No authenticated user -> go to login.
      if (user == null) {
        _goToLogin();
        return;
      }

      final data = await supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();

      // The auth session exists but there is no matching profile row (e.g. an
      // orphaned session or a signup whose profile row was never created).
      // Don't hang on the spinner: clear the stale session and go to login.
      if (data == null || data['role'] == null) {
        await supabase.auth.signOut();
        _goToLogin();
        return;
      }

      final String role = data['role'] as String;

      if (!mounted) return;
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
                const TeacherDashboardScreen(),
                const TeacherMyCoursesPage(),
                const TeacherProfileScreen()
              ];
      });
    } catch (e) {
      debugPrint('Error fetching user role: $e');
      _goToLogin();
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
    return Scaffold(
      backgroundColor: AppColors.appWhite,
      body: _screens.isNotEmpty
          ? _screens[_selectedIndex]
          : const Center(child: CircularProgressIndicator()),
      bottomNavigationBar: CustomBottomNavBar(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
        // isStudent: isStudent,
      ),
    );
  }
}
