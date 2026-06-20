import 'dart:async';

import 'package:get/get.dart';
import 'package:padi_learn/services/supabase.dart';

class OngoingCoursesController extends GetxController {
  final String userId;

  OngoingCoursesController({required this.userId});

  var ongoingCourses = <Map<String, dynamic>>[].obs;
  var isLoading = true.obs;
  var errorMessage = ''.obs;

  StreamSubscription<List<Map<String, dynamic>>>? _sub;

  @override
  void onInit() {
    super.onInit();
    _listen();
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }

  void _listen() {
    if (userId.isEmpty) {
      isLoading.value = false;
      return;
    }

    _sub = supabase
        .from('enrollments')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .listen((rows) {
      ongoingCourses.value = rows
          .map((course) => <String, dynamic>{
                'id': course['course_id'],
                'title': course['title'],
                'image': course['image'],
                'progress': course['progress'] ?? 0,
              })
          .toList();
      isLoading.value = false;
      errorMessage.value = '';
    }, onError: (Object e) {
      errorMessage.value = 'Error fetching ongoing courses: $e';
      isLoading.value = false;
    });
  }
}
