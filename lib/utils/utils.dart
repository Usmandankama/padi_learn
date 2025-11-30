// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:padi_learn/controller/course_controller.dart';
import 'package:padi_learn/controller/marketplace_controller.dart';
import 'package:padi_learn/controller/teacherController.dart';
import 'package:padi_learn/controller/user_controller.dart';
import 'package:padi_learn/screens/student/student_dashboard.dart';
import 'package:padi_learn/screens/teacher/my_courses.dart';
import 'package:padi_learn/screens/teacher/teacher_dashboard.dart';
import 'package:padi_learn/screens/teacher/teacher_profle.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/home/home_shell.dart';
import '../screens/login/login_screen.dart';
import '../screens/settings/settings_screen.dart';

Future<void> login(BuildContext context, String email, String password) async {
  try {
    UserCredential userCredential =
        await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const HomeShell(),
      ),
    );

    Get.lazyPut(() => CoursesController()); // Course Controller
    Get.lazyPut(() => MarketplaceController()); // Marketplace Controller
    Get.lazyPut(() => UserController());
    Get.lazyPut(() => TeacherController());
    // Show success message
    Get.snackbar("Success", ' logged in', snackPosition: SnackPosition.BOTTOM);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Login successful'),
        backgroundColor: Colors.green,
      ),
    );
  } catch (e) {
    print('Error logging in: $e');

    // Show error message
    Get.snackbar("Error", 'Error logging in',
        snackPosition: SnackPosition.BOTTOM);
  }
}

Future<void> signOut(BuildContext context) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Sign Out'),
      content: const Text('Are you sure you want to sign out?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Yes, Sign Out'),
        ),
      ],
    ),
  );

  if (confirm != true) return; // cancel if user chose "Cancel"

  try {
    await FirebaseAuth.instance.signOut();

    // Clear GetX controllers and local storage
    Get.deleteAll(force: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    // Navigate to login screen
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error signing out: $e')),
    );
  }
}

Future<String> getUserRole(String uid) async {
  try {
    DocumentSnapshot userDoc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (userDoc.exists) {
      return userDoc['role'] ?? 'unknown';
    } else {
      throw Exception('User document does not exist');
    }
  } catch (e) {
    print('Error fetching user role: $e');
    return 'unknown';
  }
}

Future<void> signUp(BuildContext context, String email, String password,
    String role, name) async {
  try {
    UserCredential userCredential =
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Save user role in Firestore
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userCredential.user!.uid)
        .set({
      'name': name,
      'email': email,
      'role': role, // 'student' or 'teacher'
    });

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Registration successful'),
        backgroundColor: Colors.green,
      ),
    );
  } catch (e) {
    print('Error signing up: $e');

    // Show error message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error signing up: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

Future<void> _initializeUserRole(BuildContext context) async {
  List<Widget> screens = []; // Empty list to start with

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

      if (role == 'student') {
        screens = [
          const StudentDashboard(),
          // const TeacherMyCoursesPage(), // You might want to update this screen based on your role
          const SettingsScreen(),
          const TeacherProfileScreen(), // If you need different profile screens, adjust accordingly
        ];
      } else if (role == 'teacher') {
        screens = [
          TeacherDashboardScreen(),
          const TeacherMyCoursesPage(), // You might want to update this screen based on your role
          // const SettingsScreen(),
          const TeacherProfileScreen(),
        ];
      }
    } else {
      // Handle the case when user is not logged in
      Navigator.pushReplacementNamed(context, '/login');
    }
  } catch (e) {
    print('Error fetching user role: $e');
  }
}

Future<List<QueryDocumentSnapshot>> _fetchAllCourses() async {
  final querySnapshot =
      await FirebaseFirestore.instance.collection('courses').get();
  return querySnapshot.docs;
}
