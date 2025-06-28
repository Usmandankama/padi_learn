import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

class OngoingCoursesController extends GetxController {
  final String userId;

  OngoingCoursesController({required this.userId});

  // Observable list of ongoing courses
  var ongoingCourses = <Map<String, dynamic>>[].obs;
  var isLoading = true.obs;
  var errorMessage = ''.obs;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void onInit() {
    super.onInit();
    fetchOngoingCourses();
  }

  void fetchOngoingCourses() {
    _firestore
        .collection('enrollments')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
      final data = snapshot.docs.map((doc) => doc.data()).toList();

      ongoingCourses.value = data.map((course) {
        return {
          'id': course['courseId'],
          'title': course['title'],
          'image': course['image'],
          'progress': course['progress'] ?? 0,
        };
      }).toList();

      isLoading.value = false;
      errorMessage.value = '';
    }, onError: (e) {
      errorMessage.value = 'Error fetching ongoing courses: $e';
      isLoading.value = false;
    });
  }
}
