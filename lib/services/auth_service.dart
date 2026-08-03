import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:padi_learn/services/supabase.dart';
import '../screens/home/home_shell.dart';
import '../screens/login/login_screen.dart';

/// Signs the user in with email + password and enters the app.
Future<void> login(BuildContext context, String email, String password) async {
  try {
    await supabase.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );

    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const HomeShell()),
      (route) => false, // Clear the auth stack.
    );
  } on AuthException catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.message), backgroundColor: Colors.red),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Something went wrong. Please try again.'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

/// Confirms, then signs the user out and clears local state.
Future<void> signOut(BuildContext context) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Sign Out'),
      content: const Text('Are you sure you want to sign out?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Yes, Sign Out'),
        ),
      ],
    ),
  );

  if (confirm != true) return;

  final uid = supabase.auth.currentUser?.id;

  try {
    await supabase.auth.signOut();
  } catch (e) {
    // gotrue clears the local session *before* it notifies the server, so the
    // user is signed out on this device whether or not that request lands.
    // Failing the whole teardown here (as this used to) left them signed out
    // but still sitting on the previous screen — worst of both.
    debugPrint('Sign-out request failed, continuing locally: $e');
  }

  // Dispose the user-scoped controllers so the next account starts clean.
  // They are registered with `fenix: true` (see `registerAppControllers`),
  // so the registrations survive and each is rebuilt on the next `Get.find`.
  // Passing `force: false` also spares the permanent SettingsController,
  // keeping the device's theme choice across sign-outs.
  Get.deleteAll();
  await _clearUserCache(uid);

  if (!context.mounted) return;
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (context) => const LoginScreen()),
    (route) => false,
  );
}

const String _kRoleKeyPrefix = 'user_role_';

/// Remembers a user's role locally.
///
/// The role decides which shell the app builds, so without a cached copy an
/// offline launch has nothing to go on and can only bounce the user to a login
/// screen that also needs the network.
Future<void> cacheUserRole(String uid, String role) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('$_kRoleKeyPrefix$uid', role);
}

/// The last role we successfully read for [uid], if any.
Future<String?> cachedUserRole(String uid) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('$_kRoleKeyPrefix$uid');
}

/// Drops the cached data belonging to the signed-out user.
///
/// Deliberately not `prefs.clear()`: that also wiped the device's theme and
/// notification preferences, and every *other* account's cached course list.
Future<void> _clearUserCache(String? uid) async {
  final prefs = await SharedPreferences.getInstance();
  final stale = prefs.getKeys().where((key) {
    if (key.startsWith('progress_')) return true; // Video resume positions.
    if (uid == null) return false;
    return key == 'ongoing_courses_$uid' || key == '$_kRoleKeyPrefix$uid';
  }).toList();

  for (final key in stale) {
    await prefs.remove(key);
  }
}

/// Returns the role ('Student' | 'Teacher') for [uid], or 'unknown'.
Future<String> getUserRole(String uid) async {
  try {
    final data = await supabase
        .from('profiles')
        .select('role')
        .eq('id', uid)
        .maybeSingle();
    return (data?['role'] as String?) ?? 'unknown';
  } catch (e) {
    return 'unknown';
  }
}

/// Registers a new user. The matching `profiles` row is created automatically
/// by a database trigger from the name/role passed here as auth metadata.
///
/// Returns `true` when the account has an active session (ready to enter the
/// app), and `false` on failure or when email confirmation is still pending.
Future<bool> signUp(BuildContext context, String email, String password,
    String role, String name) async {
  try {
    final res = await supabase.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'name': name, 'role': role},
    );

    if (res.session != null) {
      return true; // Email confirmation disabled — signed in immediately.
    }

    // Email confirmation is enabled on the project: account created, but the
    // user must confirm via email before they can sign in.
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Account created. Check your email to confirm, then log in.'),
        backgroundColor: Colors.green,
      ),
    );
    return false;
  } on AuthException catch (e) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.message), backgroundColor: Colors.red),
    );
    return false;
  } catch (e) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error signing up: $e'), backgroundColor: Colors.red),
    );
    return false;
  }
}
