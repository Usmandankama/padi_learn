import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:padi_learn/services/supabase.dart';

/// A Nigerian bank as listed by Paystack.
class Bank {
  final String name;
  final String code;
  const Bank({required this.name, required this.code});

  factory Bank.fromJson(Map<String, dynamic> json) => Bank(
        name: (json['name'] ?? '').toString(),
        code: (json['code'] ?? '').toString(),
      );
}

/// Where a teacher's earnings should be sent.
class PayoutAccount {
  final String bankCode;
  final String bankName;
  final String accountNumber;
  final String accountName;
  final DateTime? verifiedAt;

  const PayoutAccount({
    required this.bankCode,
    required this.bankName,
    required this.accountNumber,
    required this.accountName,
    required this.verifiedAt,
  });

  factory PayoutAccount.fromRow(Map<String, dynamic> row) => PayoutAccount(
        bankCode: (row['bank_code'] ?? '').toString(),
        bankName: (row['bank_name'] ?? '').toString(),
        accountNumber: (row['account_number'] ?? '').toString(),
        accountName: (row['account_name'] ?? '').toString(),
        verifiedAt:
            DateTime.tryParse(row['verified_at']?.toString() ?? '')?.toLocal(),
      );

  /// `••••••1234` — enough to recognise, not enough to be shoulder-surfed.
  String get maskedNumber {
    if (accountNumber.length < 4) return accountNumber;
    return '••••••${accountNumber.substring(accountNumber.length - 4)}';
  }
}

/// Reads and updates the signed-in teacher's payout destination.
///
/// Every write goes through the `payout-account` edge function, which resolves
/// the number with Paystack first — the table itself rejects client inserts and
/// updates. That is what makes the stored account name trustworthy rather than
/// whatever someone typed.
class PayoutAccountService {
  /// The current payout account, or null if none has been set up.
  static Future<PayoutAccount?> current() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return null;

    final row = await supabase
        .from('payout_accounts')
        .select('bank_code, bank_name, account_number, account_name, verified_at')
        .eq('user_id', uid)
        .maybeSingle();

    return row == null ? null : PayoutAccount.fromRow(Map<String, dynamic>.from(row));
  }

  /// Nigerian banks, alphabetical.
  static Future<List<Bank>> banks() async {
    final data = await _invoke({'action': 'banks'});
    final list = (data['banks'] as List?) ?? const [];
    return list
        .map((b) => Bank.fromJson(Map<String, dynamic>.from(b as Map)))
        .toList();
  }

  /// Looks up the name on an account without saving anything.
  static Future<String> resolve({
    required String bankCode,
    required String accountNumber,
  }) async {
    final data = await _invoke({
      'action': 'resolve',
      'bankCode': bankCode,
      'accountNumber': accountNumber,
    });
    return (data['account_name'] ?? '').toString();
  }

  /// Verifies and stores the account. Returns the resolved account name.
  static Future<String> save({
    required String bankCode,
    required String accountNumber,
  }) async {
    final data = await _invoke({
      'action': 'save',
      'bankCode': bankCode,
      'accountNumber': accountNumber,
    });
    return (data['account_name'] ?? '').toString();
  }

  /// Removes the payout account. Allowed directly — RLS limits it to the owner.
  static Future<void> remove() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    await supabase.from('payout_accounts').delete().eq('user_id', uid);
  }

  static Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    try {
      final res = await supabase.functions.invoke('payout-account', body: body);
      final data = Map<String, dynamic>.from(res.data as Map);
      final error = data['error'];
      if (error != null) throw Exception(error.toString());
      return data;
    } on FunctionException catch (e) {
      throw Exception(_message(e.details) ?? 'Something went wrong.');
    }
  }

  static String? _message(dynamic details) {
    if (details is Map) {
      return (details['error'] ?? details['message'])?.toString();
    }
    return null;
  }
}
