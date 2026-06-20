import 'dart:async';

import 'package:get/get.dart';
import 'package:padi_learn/services/supabase.dart';

class MarketplaceController extends GetxController {
  var courses = <Map<String, dynamic>>[].obs; // Observable list of courses
  var searchQuery = ''.obs;
  var selectedFilter = 'All'.obs;

  StreamSubscription<List<Map<String, dynamic>>>? _coursesSub;

  @override
  void onInit() {
    super.onInit();
    _listenToCourses();
  }

  @override
  void onClose() {
    _coursesSub?.cancel();
    super.onClose();
  }

  /// Subscribe to real-time changes in the `courses` table.
  void _listenToCourses() {
    _coursesSub = supabase
        .from('courses')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .listen((rows) {
      courses.assignAll(List<Map<String, dynamic>>.from(rows));
    }, onError: (Object e) {
      // Keep the last good list on transient errors.
    });
  }

  /// Filter by search text AND the selected category.
  List<Map<String, dynamic>> filterCourses() {
    return courses.where((course) {
      final title = (course['title'] ?? '').toString().toLowerCase();
      final matchesSearch = title.contains(searchQuery.value.toLowerCase());
      final matchesFilter = selectedFilter.value == 'All' ||
          course['category'] == selectedFilter.value;
      return matchesSearch && matchesFilter;
    }).toList();
  }

  /// Filter by search text only.
  List<Map<String, dynamic>> allCourses() {
    return courses.where((course) {
      final title = (course['title'] ?? '').toString().toLowerCase();
      return title.contains(searchQuery.value.toLowerCase());
    }).toList();
  }
}
