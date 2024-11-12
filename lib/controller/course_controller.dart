import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'user_controller.dart'; // Import the UserController
import 'package:cloud_firestore/cloud_firestore.dart';

class CoursesController extends GetxController {
  var courses = <QueryDocumentSnapshot>[].obs; // Observable list of courses
  var selectedCourseId = ''.obs; // Observable for selected course ID
  var selectedCourseTitle = ''.obs;
  var selectedCourseImage = ''.obs;
  var selectedCoursePrice = ''.obs;
  var selectedCourseDescription = ''.obs;
  var selectedCourseAuthor = ''.obs;
  var selectedCourseVideoUrl = ''.obs; // New observable for course video URL

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

  // Method to set the selected course details, now including video URL
  void selectCourse(String id, String title, String image, String price, String description, String author, String videoUrl) {
    selectedCourseId.value = id; // Set the selected course ID
    selectedCourseTitle.value = title;
    selectedCourseImage.value = image;
    selectedCoursePrice.value = price;
    selectedCourseAuthor.value = author;
    selectedCourseDescription.value = description;
    selectedCourseVideoUrl.value = videoUrl; // Set the selected course video URL
  }

  // Access current user's name from UserController
  String getCurrentUserName() {
    return userController.userName.value; // Use the userName from UserController
  }

  User? getCurrentUser() {
    return FirebaseAuth.instance.currentUser;
  }
}
