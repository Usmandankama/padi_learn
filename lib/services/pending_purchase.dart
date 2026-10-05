import 'package:shared_preferences/shared_preferences.dart';

/// A purchase that was handed to Paystack and has not been confirmed yet.
///
/// Only web needs this. Paying on web means leaving the page, so the running
/// app — and every variable in it — is gone by the time Paystack sends the
/// student back. This is the one thing that survives the round trip.
class PendingPurchase {
  static const _kReference = 'pending_purchase_reference';
  static const _kCourseId = 'pending_purchase_course_id';
  static const _kCourseTitle = 'pending_purchase_course_title';

  final String reference;
  final String courseId;
  final String courseTitle;

  const PendingPurchase({
    required this.reference,
    required this.courseId,
    required this.courseTitle,
  });

  static Future<void> save({
    required String reference,
    required String courseId,
    required String courseTitle,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kReference, reference);
    await prefs.setString(_kCourseId, courseId);
    await prefs.setString(_kCourseTitle, courseTitle);
  }

  static Future<PendingPurchase?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final reference = prefs.getString(_kReference);
    if (reference == null || reference.isEmpty) return null;
    return PendingPurchase(
      reference: reference,
      courseId: prefs.getString(_kCourseId) ?? '',
      courseTitle: prefs.getString(_kCourseTitle) ?? '',
    );
  }

  /// Clears the record. Call once the server has given a verdict — including
  /// a failure, so a declined card is not retried forever on every load.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kReference);
    await prefs.remove(_kCourseId);
    await prefs.remove(_kCourseTitle);
  }
}
