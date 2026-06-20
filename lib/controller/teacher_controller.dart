import 'package:get/get.dart';
import 'package:padi_learn/services/supabase.dart';

class TeacherController extends GetxController {
  // Observable variables
  var teacherName = 'Loading...'.obs;
  var profileImageUrl = ''.obs;
  var totalCoursesUploaded = 0.obs;
  var totalEarnings = 0.0.obs;
  var userCourses = <Map<String, dynamic>>[].obs;

  @override
  void onInit() {
    super.onInit();
    fetchTeacherInfo();
    fetchTeacherEarningsAndCourses();
    fetchUserCourses();
  }

  String? get _userId => supabase.auth.currentUser?.id;

  Future<void> fetchTeacherInfo() async {
    try {
      final userId = _userId;
      if (userId == null) {
        teacherName.value = 'User not logged in';
        return;
      }

      final data = await supabase
          .from('profiles')
          .select('name, profile_image_url')
          .eq('id', userId)
          .maybeSingle();

      if (data != null) {
        teacherName.value = (data['name'] as String?) ?? 'Unknown Name';
        profileImageUrl.value = (data['profile_image_url'] as String?) ?? '';
      } else {
        teacherName.value = 'Profile not found';
      }
    } catch (e) {
      teacherName.value = 'Error loading name';
    }
  }

  Future<void> fetchTeacherEarningsAndCourses() async {
    try {
      final userId = _userId;
      if (userId == null) return;

      final rows = await supabase
          .from('courses')
          .select('price, enrollments')
          .eq('user_id', userId);

      double earnings = 0.0;
      for (final row in rows) {
        final price = (row['price'] as num?)?.toDouble() ?? 0.0;
        final enrollments = (row['enrollments'] as num?)?.toInt() ?? 0;
        earnings += price * enrollments;
      }

      totalCoursesUploaded.value = rows.length;
      totalEarnings.value = earnings;
    } catch (e) {
      // Leave defaults on failure.
    }
  }

  Future<void> fetchUserCourses() async {
    try {
      final userId = _userId;
      if (userId == null) return;

      final rows = await supabase
          .from('courses')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      userCourses.value = List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      // Leave defaults on failure.
    }
  }

  /// Live stream of the signed-in teacher's courses (newest first).
  Stream<List<Map<String, dynamic>>> courseStream() {
    final userId = _userId;
    if (userId == null) return Stream.value(<Map<String, dynamic>>[]);

    return supabase
        .from('courses')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false);
  }
}
