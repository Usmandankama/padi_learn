import 'package:get/get.dart';
import 'package:padi_learn/services/course_service.dart';
import 'package:padi_learn/services/supabase.dart';
import 'package:padi_learn/services/transaction_service.dart';

class TeacherController extends GetxController {
  // Observable variables
  var teacherName = 'Loading...'.obs;
  var profileImageUrl = ''.obs;

  /// Courses that have been uploaded, live or archived. Drafts are not
  /// courses yet and are counted in [draftCount].
  var totalCoursesUploaded = 0.obs;
  var draftCount = 0.obs;

  /// Naira this teacher has earned, less what refunds took back. From
  /// `my_teacher_balance()`, the same figures the admin panel pays from.
  var totalEarnings = 0.0.obs;

  /// Number of paid sales behind [totalEarnings].
  var totalSales = 0.obs;

  /// Already transferred to the teacher's bank.
  var paidOut = 0.0.obs;

  /// Ready to be paid out now.
  var payable = 0.0.obs;

  /// Earned but still inside the 7-day hold.
  var clearing = 0.0.obs;

  /// Payouts are held while the account is suspended.
  var payoutsHeld = false.obs;
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

  /// Course count, plus earnings from the teacher's balance.
  ///
  /// This first estimated earnings as `price × enrollments`, which counted
  /// free enrolments as revenue and ignored the platform fee. It then summed
  /// the `transactions` ledger, which was real money but blind to refunds
  /// taken back and payouts made. `my_teacher_balance()` is the definition the
  /// admin panel pays from, so the card and the payout now agree.
  Future<void> fetchTeacherEarningsAndCourses() async {
    final userId = _userId;
    if (userId == null) return;

    try {
      // Whole rows, not just ids: a draft is told apart by a column that a
      // narrower select would have to name, and naming it fails outright on a
      // database from before drafts.
      final rows =
          await supabase.from('courses').select().eq('user_id', userId);
      final drafts = rows.where(isDraftCourse).length;
      totalCoursesUploaded.value = rows.length - drafts;
      draftCount.value = drafts;
    } catch (e) {
      // Leave the previous count on failure.
    }

    try {
      final balance = await TransactionService.myBalance();
      totalEarnings.value = balance.earned;
      totalSales.value = balance.salesCount;
      paidOut.value = balance.paidOut;
      payable.value = balance.payable;
      clearing.value = balance.clearing;
      payoutsHeld.value = balance.payoutsHeld;
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
