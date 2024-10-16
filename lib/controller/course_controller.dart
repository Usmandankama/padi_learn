// lib/controllers/courses_controller.dart
import 'package:get/get.dart';
import 'user_controller.dart'; // Import the UserController
import 'package:cloud_firestore/cloud_firestore.dart';

class CoursesController extends GetxController {
  var courses = <QueryDocumentSnapshot>[].obs; // Observable list of courses
  var selectedCourseTitle = ''.obs;
  var selectedCourseImage = ''.obs;
  var selectedCoursePrice = ''.obs;
  var selectedCourseDescription = ''.obs;

  // Get UserController instance
  final UserController userController = Get.find<UserController>();

  @override
  void onInit() {
    super.onInit();
    fetchCourses(); // Fetch courses on initialization
  }

  // Fetch courses from Firestore
  Future<void> fetchCourses() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance.collection('courses').get();
      courses.value = querySnapshot.docs;
    } catch (e) {
      print('Error fetching courses: $e');
    }
  }

  // Method to set the selected course details
  void selectCourse(String title, String image, String price, String description) {
    selectedCourseTitle.value = title;
    selectedCourseImage.value = image;
    selectedCoursePrice.value = price;
    selectedCourseDescription.value = description;
  }

  // Access current user's name from UserController
  String getCurrentUserName() {
    return userController.userName.value; // Use the userName from UserController
  }
}
