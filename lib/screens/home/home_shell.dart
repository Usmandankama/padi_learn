import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:padi_learn/screens/student/student_dashboard.dart';
import 'package:padi_learn/screens/login/login_screen.dart';
import 'package:padi_learn/screens/search/search_screen.dart';
import 'package:padi_learn/screens/settings/settings_screen.dart';
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
  List<Widget> _screens = []; // Empty list to start with

  @override
  void initState() {
    super.initState();
    _initializeUserRole();
  }

  Future<void> _initializeUserRole() async {
    try {
      // Get the current user
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Fetch the user's role
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        String role = userDoc['role'] ?? 'unknown';

        // Update the screens list based on role
        setState(() {
          isStudent = role == 'Student';
          if (isStudent) {
            _screens = [
              const StudentDashboard(),
              const SearchScreen(),
              const StudentProfileScreen(),
            ];
          } else if (role == 'Teacher') {
            _screens = [
              const TeacherDashboardScreen(),
              const CoursesScreen(), // Update as necessary for the teacher
              const SettingsScreen(),
              const TeacherProfileScreen()
            ];
          }
        });
      } else {
        // Handle the case when user is not logged in
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
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: _onItemTapped,
      backgroundColor: AppColors.appWhite,
      selectedItemColor: AppColors.primaryColor,
      unselectedItemColor: Colors.grey,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      items: isStudent
          ? [
              const BottomNavigationBarItem(
                icon: Icon(Icons.dashboard),
                label: 'Dashboard',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.search),
                label: 'Search',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: 'Profile',
              ),
            ]
          : [
              const BottomNavigationBarItem(
                icon: Icon(Icons.dashboard),
                label: 'Dashboard',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.book),
                label: 'Courses',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.settings),
                label: 'Settings',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
    );
  }
}

class CoursesScreen extends StatelessWidget {
  const CoursesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Courses Content',
        style: TextStyle(
          fontSize: 24.sp,
          color: AppColors.primaryColor,
        ),
      ),
    );
  }
}
