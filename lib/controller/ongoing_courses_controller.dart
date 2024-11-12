import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

class OngoingCoursesController extends GetxController {
  final String userId;

  OngoingCoursesController({required this.userId});

  // Observable list of courses
  var ongoingCourses = <Map<String, dynamic>>[].obs;
  var isLoading = true.obs;
  var errorMessage = ''.obs;

  // Firebase instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void onInit() {
    super.onInit();
    fetchOngoingCourses();
  }

  // Fetch ongoing courses in real-time
  void fetchOngoingCourses() {
    _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen((userDoc) {
      if (userDoc.exists) {
        // Extract the ongoingCourses field
        final ongoingCoursesData = userDoc.data()?['ongoingCourses'] as List<dynamic>? ?? [];

        // Map the courses and update the observable list
        ongoingCourses.value = ongoingCoursesData.map((course) {
          return {
            'id': course['id'], // Assuming the course ID is included
            'title': course['title'], // Assuming title is available
            'image': course['image'], // Assuming thumbnail URL is available
            'progress': course['progress'] ?? 0, // Default progress to 0 if missing
          };
        }).toList();
        
        isLoading.value = false; // Loading complete
        errorMessage.value = ''; // Clear any previous error
      } else {
        errorMessage.value = 'User document not found';
        ongoingCourses.clear();
        isLoading.value = false;
      }
    }, onError: (e) {
      errorMessage.value = 'Error fetching ongoing courses: $e';
      isLoading.value = false;
    });
  }
}
