import 'dart:async';

import 'package:get/get.dart';
import 'package:padi_learn/services/supabase.dart';

/// Keeps the marketplace catalogue live.
///
/// Search and category filtering are presentation state owned by
/// `MarketplaceScreen`, not this controller — it is only responsible for the
/// list being current.
class MarketplaceController extends GetxController {
  var courses = <Map<String, dynamic>>[].obs; // Observable list of courses

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

  /// One-shot re-fetch for pull-to-refresh. The realtime stream already keeps
  /// the list live, but this lets the user force a reload (and recover if the
  /// stream silently dropped). Failures are swallowed so the last good list
  /// stays on screen when offline. Named `reload` to avoid overriding
  /// GetxController's own `refresh()`.
  Future<void> reload() async {
    try {
      final rows = await supabase
          .from('courses')
          .select()
          .order('created_at', ascending: false);
      courses.assignAll(List<Map<String, dynamic>>.from(rows));
    } catch (_) {
      // Keep the last good list.
    }
  }
}
