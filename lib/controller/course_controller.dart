import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:padi_learn/services/supabase.dart';
import 'user_controller.dart';

class CoursesController extends GetxController {
  var courses = <Map<String, dynamic>>[].obs; // Observable list of courses
  var selectedCourseId = ''.obs;
  var selectedCourseTitle = ''.obs;
  var selectedCourseImage = ''.obs;
  var selectedCoursePrice = 0.0.obs; // numeric price (0 == free)
  var selectedCourseDescription = ''.obs;
  var selectedCourseAuthor = ''.obs;
  var selectedCourseVideoUrl = ''.obs;

  final UserController userController = Get.find<UserController>();

  @override
  void onInit() {
    super.onInit();
    fetchCourses();
  }

  Future<void> fetchCourses() async {
    try {
      final rows = await supabase
          .from('courses')
          .select()
          .order('created_at', ascending: false);
      courses.value = List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      // Leave list empty on failure.
    }
  }

  /// Stores the tapped course's details for the description screen.
  void selectCourse(String id, String title, String image, num price,
      String description, String author, String videoUrl) {
    selectedCourseId.value = id;
    selectedCourseTitle.value = title;
    selectedCourseImage.value = image;
    selectedCoursePrice.value = price.toDouble();
    selectedCourseAuthor.value = author;
    selectedCourseDescription.value = description;
    selectedCourseVideoUrl.value = videoUrl;
  }

  String getCurrentUserName() => userController.userName.value;

  User? getCurrentUser() => supabase.auth.currentUser;
}
