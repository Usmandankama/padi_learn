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

  /// Every course id this student is enrolled in, free or paid.
  ///
  /// Derived from the rows already streamed above rather than from a second
  /// query: the marketplace needs to know what to hide and the cards need to
  /// know what to label, and opening another realtime subscription on
  /// `enrollments` for the same user to answer that would double this screen's
  /// share of the connection budget for no new information.
  /// A plain `Rx<Set<...>>` rather than `RxSet`, whose `value` GetX marks
  /// protected — and whose `contains()` reads the backing field directly, so
  /// calling it inside an `Obx` registers no dependency and the list would
  /// never update when a purchase landed.
  final Rx<Set<String>> ownedIds = Rx<Set<String>>(<String>{});

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
      _apply(decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList());
      isLoading.value = false; // We have something to render.
    } catch (_) {
      // Corrupt cache — ignore and wait for the network.
    }
  }

  void _saveToCache(List<Map<String, dynamic>> courses) {
    _prefs?.setString(_cacheKey, jsonEncode(courses));
  }

  /// Single place the rows land, so `ownedIds` cannot drift from the list.
  void _apply(List<Map<String, dynamic>> mapped) {
    ongoingCourses.value = mapped;
    ownedIds.value = mapped
        .map((c) => (c['id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet();
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
        // Most recently enrolled first. Without this the rows arrive in
        // whatever order Postgres returns them, so "Continue learning" put the
        // course you just bought wherever it happened to land — usually not
        // first, which is the one place a user expects to find it.
        .order('enrolled_at', ascending: false)
        .listen((rows) {
          final mapped = _mapRows(rows);
          _apply(mapped);
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

  /// The instance for the signed-in student, or null when there isn't one.
  ///
  /// Registered per user id (see [OngoingCoursesWidget]), so callers that only
  /// want to *read* enrolment state — the marketplace, a course card — go
  /// through here rather than guessing the tag. Returning null instead of
  /// throwing matters: a teacher has no enrolments controller, and neither
  /// does a signed-out user.
  static OngoingCoursesController? forCurrentUser() {
    final uid = supabase.auth.currentUser?.id ?? '';
    if (uid.isEmpty) return null;
    return Get.isRegistered<OngoingCoursesController>(tag: uid)
        ? Get.find<OngoingCoursesController>(tag: uid)
        : null;
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
          .eq('user_id', userId)
          // Same order as the stream, so a pull-to-refresh cannot reshuffle
          // the list into a different order than the one it just had.
          .order('enrolled_at', ascending: false);

      final mapped = _mapRows(List<Map<String, dynamic>>.from(rows));
      _apply(mapped);
      _saveToCache(mapped);
      errorMessage.value = '';
    } catch (_) {
      // Keep the last-known list; no need to disrupt the user when offline.
    }
  }
}
