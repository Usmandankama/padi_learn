import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:padi_learn/screens/dashboards/teacher_dashboard.dart';
import 'package:padi_learn/screens/dashboards/student_dashboard.dart';
import 'package:padi_learn/screens/profile/student_profile_screen.dart';
import 'package:padi_learn/screens/profile/teacher_profle.dart';
import 'package:padi_learn/screens/search/search_screen.dart';
import 'package:padi_learn/screens/settings/settings_screen.dart';
import 'package:padi_learn/utils/colors.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  _HomeShellState createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;
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
          if (role == 'Student') {
            _screens = [
              const StudentDashboard(),
              const CoursesScreen(), // You might want to update this screen based on your role
              const SearchScreen(),
              const StudentProfileScreen(),
            ];
          } else if (role == 'Teacher') {
            _screens = [
              const TeacherDashboardScreen(),
              const CoursesScreen(), // You might want to update this screen based on your role
              const SettingsScreen(),
              const TeacherProfileScreen()
            ];
          }
        });
      } else {
        // Handle the case when user is not logged in
        Navigator.pushReplacementNamed(context, '/login');
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
          : Center(child: CircularProgressIndicator()),
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
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.book),
          label: 'Courses',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.search),
          label: 'Search',
        ),
        BottomNavigationBarItem(
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
