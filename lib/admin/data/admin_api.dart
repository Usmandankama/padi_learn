import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:padi_learn/services/supabase.dart';

/// Every call the admin app makes, in one place.
///
/// Each method is a thin wrapper over one admin function in the database
/// (supabase/migrations/20261006*). The database does all the checking, so
/// nothing here validates or decides anything; it only turns the JSON into
/// the shapes the screens read.
class AdminApi {
  AdminApi._();

  /// The overview document: `waiting`, `accounts`, `catalogue`, `learning`,
  /// `money`. See 20261006000010 for the shape.
  static Future<Map<String, dynamic>> overview() async {
    final result = await supabase.rpc('admin_overview');
    return Map<String, dynamic>.from(result as Map);
  }
}

/// A failed admin call, in words an admin can act on.
///
/// The admin functions raise three kinds of error on purpose:
///   42501  not an admin, or the second factor has lapsed
///   22023  the request makes no sense (no reason given, already done, ...)
///   P0002  the thing asked about does not exist
/// The last two already carry a readable message from the function. The first
/// almost always means the session should be renewed.
String adminErrorMessage(Object error) {
  if (error is PostgrestException) {
    if (error.code == '42501') {
      return 'Not allowed. Your admin session may have lapsed: sign out and '
          'in again.';
    }
    return error.message;
  }
  if (error is AuthException) return error.message;
  return 'Something went wrong: $error';
}
