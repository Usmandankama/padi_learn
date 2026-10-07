import 'package:padi_learn/services/supabase.dart';

/// The signed-in user's suspension, if there is one.
///
/// A suspended account can still sign in and watch what it owns, but the
/// database refuses everything else (supabase/migrations/
/// 20261006000010_account_suspension.sql). Without telling them, those
/// refusals arrive as bare "row-level security" errors. RLS lets a user read
/// their own row only, and only the reason and date, not who suspended them.
class Suspension {
  final String reason;
  final DateTime? since;

  const Suspension({required this.reason, required this.since});
}

class SuspensionService {
  /// Null when the account is not suspended, or when the answer cannot be
  /// had (offline): a banner that might be wrong is worse than none.
  static Future<Suspension?> mine() async {
    try {
      final row = await supabase
          .from('suspensions')
          .select('reason, suspended_at')
          .maybeSingle();
      if (row == null) return null;
      return Suspension(
        reason: (row['reason'] ?? '').toString(),
        since: DateTime.tryParse(row['suspended_at']?.toString() ?? ''),
      );
    } catch (_) {
      return null;
    }
  }
}
