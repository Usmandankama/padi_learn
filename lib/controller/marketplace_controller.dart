import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

class MarketplaceController extends GetxController {
  var courses = <QueryDocumentSnapshot>[].obs;  // Observable list of courses
  var searchQuery = ''.obs;
  var selectedFilter = 'All'.obs;
  late StreamSubscription<QuerySnapshot> courseSubscription;

  @override
  void onInit() {
    super.onInit();
    fetchAllCourses();  // Start listening to the course collection on init
  }

  @override
  void onClose() {
    // Cancel the subscription when the controller is disposed
    courseSubscription.cancel();
    super.onClose();
  }

  void fetchAllCourses() {
    try {
      // Listen to real-time changes in the "courses" collection
      courseSubscription = FirebaseFirestore.instance
          .collection('courses')
          .snapshots()
          .listen((querySnapshot) {
        courses.assignAll(querySnapshot.docs);  // Update the observable list
      });
    } catch (e) {
      print('Error fetching courses: $e');
    }
  }

  // Method to filter courses based on search and selected category
  List<QueryDocumentSnapshot> filterCourses() {
    return courses.where((course) {
      final courseData = course.data() as Map<String, dynamic>;
      final title = courseData['title'].toString().toLowerCase();
      return title.contains(searchQuery.value.toLowerCase()) &&
          (selectedFilter.value == 'All' || courseData['category'] == selectedFilter.value);
    }).toList();
  }

  List<QueryDocumentSnapshot> allCourses() {
    return courses.where((course) {
      final courseData = course.data() as Map<String, dynamic>;
      final title = courseData['title'].toString().toLowerCase();
      return title.contains(searchQuery.value.toLowerCase());
    }).toList();
  }
}
