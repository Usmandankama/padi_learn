import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

class OngoingCoursesController extends GetxController {
  final String userId;

  OngoingCoursesController({required this.userId});

  // Observable list of courses
  var ongoingCourses = <Map<String, dynamic>>[].obs;
  var isLoading = false.obs;
  var errorMessage = ''.obs;

  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void onInit() {
    super.onInit();
    fetchOngoingCourses();
  }

  Future<void> fetchOngoingCourses() async {
    isLoading.value = true;
    errorMessage.value = ''; // Reset error message on new fetch
    try {
      // Fetch the user document from Firestore
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (userDoc.exists) {
        // Log the entire user document data for debugging
        print('User Document Data: ${userDoc.data()}');

        // Check if ongoingCourses is a field (list of course maps)
        final ongoingCoursesData = userDoc.data()?['ongoingCourses'] as List<dynamic>? ?? [];

        // Log the ongoing courses data for debugging
        print('Ongoing Courses Data: $ongoingCoursesData');

        if (ongoingCoursesData.isNotEmpty) {
          ongoingCourses.value = ongoingCoursesData.map((course) {
            // Create a map for each ongoing course
            return {
              'id': course['id'], // Assuming the course ID is included
              'title': course['title'], // Assuming title is available
              'thumbnailUrl': course['thumbnailUrl'], // Assuming thumbnail URL is available
              'progress': course['progress'] ?? 0, // Assuming progress is available, default to 0
            };
          }).toList();
        } else {
          ongoingCourses.clear();
          print('No ongoing courses found for userId: $userId'); // Debug statement
        }
      } else {
        errorMessage.value = 'User document not found';
        print('User document not found for userId: $userId');
      }
    } catch (e) {
      errorMessage.value = 'Error fetching ongoing courses: $e';
      print('Error fetching ongoing courses: $e'); // Debug statement
    } finally {
      isLoading.value = false;
    }
  }
}
