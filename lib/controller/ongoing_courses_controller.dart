import 'dart:async';
import 'dart:convert';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:padi_learn/services/supabase.dart';

class OngoingCoursesController extends GetxController {
  final String userId;

  OngoingCoursesController({required this.userId});

  var ongoingCourses = <Map<String, dynamic>>[].obs;
  var isLoading = true.obs;
  var errorMessage = ''.obs;

  StreamSubscription<List<Map<String, dynamic>>>? _sub;
  SharedPreferences? _prefs;

  /// Per-user cache key for the lightweight ongoing-courses metadata. We only
  /// cache the card data (id / title / image / progress) so the list survives a
  /// cold start with no network — never the video itself.
  String get _cacheKey => 'ongoing_courses_$userId';

  @override
  void onInit() {
    super.onInit();
    _start();
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }

  Future<void> _start() async {
    if (userId.isEmpty) {
      isLoading.value = false;
      return;
    }

    _prefs = await SharedPreferences.getInstance();
    _loadFromCache(); // Show last-known data instantly, before the network.
    _listen();
  }

  /// Hydrate the list from the on-device cache so an offline launch still shows
  /// the user's current courses instead of a spinner or an error.
  void _loadFromCache() {
    final raw = _prefs?.getString(_cacheKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      ongoingCourses.value =
          decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      isLoading.value = false; // We have something to render.
    } catch (_) {
      // Corrupt cache — ignore and wait for the network.
    }
  }

  void _saveToCache(List<Map<String, dynamic>> courses) {
    _prefs?.setString(_cacheKey, jsonEncode(courses));
  }

  List<Map<String, dynamic>> _mapRows(List<Map<String, dynamic>> rows) {
    return rows
        .map((course) => <String, dynamic>{
              'id': course['course_id'],
              'title': course['title'],
              'image': course['image'],
              'progress': course['progress'] ?? 0,
            })
        .toList();
  }

  void _listen() {
    _sub = supabase
        .from('enrollments')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .listen((rows) {
      final mapped = _mapRows(rows);
      ongoingCourses.value = mapped;
      _saveToCache(mapped);
      isLoading.value = false;
      errorMessage.value = '';
    }, onError: (Object e) {
      isLoading.value = false;
      // Offline / transient error: keep showing the cached list if we have one,
      // and only surface an error when there is nothing to fall back on.
      if (ongoingCourses.isEmpty) {
        errorMessage.value = 'Error fetching ongoing courses: $e';
      }
    });
  }

  /// One-shot re-fetch for pull-to-refresh. Falls back silently to the cached
  /// list (already on screen) when the device is offline. Named `reload` to
  /// avoid overriding GetxController's own `refresh()`.
  Future<void> reload() async {
    if (userId.isEmpty) return;
    try {
      final rows = await supabase
          .from('enrollments')
          .select('course_id, title, image, progress')
          .eq('user_id', userId);

      final mapped = _mapRows(List<Map<String, dynamic>>.from(rows));
      ongoingCourses.value = mapped;
      _saveToCache(mapped);
      errorMessage.value = '';
    } catch (_) {
      // Keep the last-known list; no need to disrupt the user when offline.
    }
  }
}
