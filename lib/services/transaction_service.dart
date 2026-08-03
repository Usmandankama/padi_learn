import 'package:padi_learn/services/supabase.dart';

/// One completed payment, as recorded in the ledger by `verify-payment`.
///
/// Amounts are stored in kobo (integer minor units) so nothing is lost to
/// floating point; the getters convert to naira only for display.
class Sale {
  final String reference;
  final String? courseId;
  final String courseTitle;
  final int amountKobo;
  final int paystackFeeKobo;
  final int netKobo;
  final int platformFeeKobo;
  final int teacherEarningKobo;
  final DateTime? paidAt;

  const Sale({
    required this.reference,
    required this.courseId,
    required this.courseTitle,
    required this.amountKobo,
    required this.paystackFeeKobo,
    required this.netKobo,
    required this.platformFeeKobo,
    required this.teacherEarningKobo,
    required this.paidAt,
  });

  factory Sale.fromRow(Map<String, dynamic> row) => Sale(
        reference: (row['reference'] ?? '').toString(),
        courseId: row['course_id'] as String?,
        courseTitle: (row['course_title'] ?? 'Course').toString(),
        amountKobo: (row['amount_kobo'] as num?)?.toInt() ?? 0,
        paystackFeeKobo: (row['paystack_fee_kobo'] as num?)?.toInt() ?? 0,
        netKobo: (row['net_kobo'] as num?)?.toInt() ?? 0,
        platformFeeKobo: (row['platform_fee_kobo'] as num?)?.toInt() ?? 0,
        teacherEarningKobo: (row['teacher_earning_kobo'] as num?)?.toInt() ?? 0,
        paidAt: DateTime.tryParse(row['paid_at']?.toString() ?? '')?.toLocal(),
      );

  /// What the student was charged, in naira.
  double get amount => amountKobo / 100;

  /// Paystack's processing fee, in naira. Deducted before settlement, so this
  /// never reaches the platform account.
  double get paystackFee => paystackFeeKobo / 100;

  /// What actually settled into the platform account, in naira.
  double get net => netKobo / 100;

  /// The platform's cut, in naira.
  double get fee => platformFeeKobo / 100;

  /// What the teacher is owed for this sale, in naira.
  double get earning => teacherEarningKobo / 100;
}

/// Reads the payment ledger.
///
/// The table is append-only from the client: RLS lets a buyer see their own
/// payments and a teacher see sales of their courses, and inserts/updates are
/// revoked outright — only `verify-payment` writes to it.
class TransactionService {
  static const String _columns =
      'reference, course_id, course_title, amount_kobo, paystack_fee_kobo, '
      'net_kobo, platform_fee_kobo, teacher_earning_kobo, paid_at';

  /// Sales of the signed-in teacher's courses, newest first.
  static Future<List<Sale>> salesForTeacher({int limit = 500}) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return const [];

    final rows = await supabase
        .from('transactions')
        .select(_columns)
        .eq('teacher_id', uid)
        .order('paid_at', ascending: false)
        .limit(limit);

    return rows.map((row) => Sale.fromRow(Map<String, dynamic>.from(row))).toList();
  }

  /// Sales of one course, newest first.
  static Future<List<Sale>> salesForCourse(String courseId) async {
    final rows = await supabase
        .from('transactions')
        .select(_columns)
        .eq('course_id', courseId)
        .order('paid_at', ascending: false);

    return rows.map((row) => Sale.fromRow(Map<String, dynamic>.from(row))).toList();
  }

  /// Total naira owed to the teacher across [sales].
  static double totalEarnings(List<Sale> sales) =>
      sales.fold<double>(0, (sum, sale) => sum + sale.earning);
}
