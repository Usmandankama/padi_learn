import 'package:get/get.dart';
import 'package:padi_learn/services/supabase.dart';
import 'package:padi_learn/services/transaction_service.dart';

class TeacherController extends GetxController {
  // Observable variables
  var teacherName = 'Loading...'.obs;
  var profileImageUrl = ''.obs;
  var totalCoursesUploaded = 0.obs;

  /// Naira actually owed to this teacher, summed from the payment ledger.
  var totalEarnings = 0.0.obs;

  /// Number of paid sales behind [totalEarnings].
  var totalSales = 0.obs;
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

  /// Course count, plus real earnings read from the payment ledger.
  ///
  /// This used to estimate earnings as `price × enrollments`, which counted
  /// free enrolments as revenue, ignored the platform fee, and moved whenever a
  /// teacher edited their price. `transactions` records what was actually
  /// charged, so the figure is now money that genuinely changed hands.
  Future<void> fetchTeacherEarningsAndCourses() async {
    final userId = _userId;
    if (userId == null) return;

    try {
      final rows =
          await supabase.from('courses').select('id').eq('user_id', userId);
      totalCoursesUploaded.value = rows.length;
    } catch (e) {
      // Leave the previous count on failure.
    }

    try {
      final sales = await TransactionService.salesForTeacher();
      totalEarnings.value = TransactionService.totalEarnings(sales);
      totalSales.value = sales.length;
    } catch (e) {
      // Leave the previous totals on failure.
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

  /// Re-fetches everything shown on the teacher screens. Used for
  /// pull-to-refresh; the realtime course stream stays the source of truth for
  /// the list itself. Named `reload` to avoid overriding GetxController's own
  /// `refresh()`.
  Future<void> reload() async {
    await Future.wait([
      fetchTeacherInfo(),
      fetchTeacherEarningsAndCourses(),
      fetchUserCourses(),
    ]);
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
