import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        String role = userDoc['role'] ?? 'unknown';

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
      } else {
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const LoginScreen(),
            ));
      }
    } catch (e) {
      print('Error fetching user role: $e');
    }
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
