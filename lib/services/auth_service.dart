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

  try {
    await supabase.auth.signOut();

    // Clear GetX controllers and local storage.
    Get.deleteAll(force: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error signing out: $e')),
    );
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
