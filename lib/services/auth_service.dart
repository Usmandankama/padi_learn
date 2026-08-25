import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:padi_learn/config/supabase_config.dart';
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

/// The signed-in user's id, or null when there is no session.
String? get currentUserId => supabase.auth.currentUser?.id;

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

// ---------------------------------------------------------------------------
// Social sign-in
//
// These use the *native* flow (platform account picker → ID token →
// `signInWithIdToken`) rather than `signInWithOAuth`, which bounces the user
// out to a browser and back through a deep link. Besides the better UX it
// means no custom URL scheme has to be registered for Google or Apple.
//
// None of them can carry a role: a provider returns an identity and nothing
// else. The `profiles` row is therefore created with `role` null, and
// `HomeShell` sends the user to the role picker on the strength of that. See
// `supabase/migrations/20260803000001_role_claiming.sql`.
// ---------------------------------------------------------------------------

/// Whether the Google button has been configured enough to work.
///
/// Better to hide the button than to offer one that throws the moment it is
/// tapped, which is what an unset client ID would do.
bool get isGoogleSignInConfigured =>
    SupabaseConfig.googleWebClientId.isNotEmpty;

/// Apple requires "Sign in with Apple" on iOS whenever another social login is
/// offered, and is unavailable everywhere else.
bool get isAppleSignInAvailable =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

bool _googleInitialized = false;

/// `initialize` is required before `authenticate` in google_sign_in 7.x, and
/// must not run twice.
Future<void> _ensureGoogleInitialized() async {
  if (_googleInitialized) return;
  await GoogleSignIn.instance.initialize(
    // Android reads `serverClientId`; iOS reads `clientId`. Passing both lets
    // one call cover the two platforms — each ignores the one it does not use.
    clientId: SupabaseConfig.googleIosClientId.isEmpty
        ? null
        : SupabaseConfig.googleIosClientId,
    serverClientId: SupabaseConfig.googleWebClientId,
  );
  _googleInitialized = true;
}

/// Signs in with the device's Google account.
///
/// Returns `true` when a Supabase session exists afterwards. The caller is
/// responsible for navigating — role resolution happens in `HomeShell`.
Future<bool> signInWithGoogle(BuildContext context) async {
  try {
    await _ensureGoogleInitialized();

    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;

    if (idToken == null) {
      // Almost always a configuration problem: on Android the ID token is only
      // issued when `serverClientId` matches a Web client whose SHA-1 covers
      // the signing key in use, so debug builds fail here until the debug
      // keystore's fingerprint is registered too.
      if (!context.mounted) return false;
      _showAuthError(context, 'Google sign-in did not return a token.');
      return false;
    }

    await supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
    );
    return true;
  } on GoogleSignInException catch (e) {
    // Backing out of the account picker is a normal thing to do, not an error
    // worth a red snackbar.
    if (e.code == GoogleSignInExceptionCode.canceled) return false;
    if (!context.mounted) return false;
    _showAuthError(context, e.description ?? 'Google sign-in failed.');
    return false;
  } on AuthException catch (e) {
    if (!context.mounted) return false;
    _showAuthError(context, e.message);
    return false;
  } catch (e) {
    debugPrint('Google sign-in failed: $e');
    if (!context.mounted) return false;
    _showAuthError(context, 'Could not sign in with Google. Please try again.');
    return false;
  }
}

/// Signs in with Apple.
///
/// Apple only ever discloses the user's name on the *first* authorization, so
/// it is folded into the session's metadata here; the `profiles` trigger has
/// already run by then, so the name is written to the row directly.
Future<bool> signInWithApple(BuildContext context) async {
  try {
    // Apple signs a nonce we choose, and Supabase re-derives it to prove the
    // token was minted for this sign-in attempt. Apple sees only the hash.
    final rawNonce = _generateNonce();
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: sha256.convert(utf8.encode(rawNonce)).toString(),
    );

    final idToken = credential.identityToken;
    if (idToken == null) {
      if (!context.mounted) return false;
      _showAuthError(context, 'Apple sign-in did not return a token.');
      return false;
    }

    final res = await supabase.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
      nonce: rawNonce,
    );

    await _backfillAppleName(res.user?.id, credential);
    return true;
  } on SignInWithAppleAuthorizationException catch (e) {
    if (e.code == AuthorizationErrorCode.canceled) return false;
    if (!context.mounted) return false;
    _showAuthError(context, e.message);
    return false;
  } on AuthException catch (e) {
    if (!context.mounted) return false;
    _showAuthError(context, e.message);
    return false;
  } catch (e) {
    debugPrint('Apple sign-in failed: $e');
    if (!context.mounted) return false;
    _showAuthError(context, 'Could not sign in with Apple. Please try again.');
    return false;
  }
}

/// Writes the name Apple disclosed, if this is the first authorization.
///
/// Silent on failure: a missing display name is a cosmetic problem, and the
/// user is already signed in by this point.
Future<void> _backfillAppleName(
  String? uid,
  AuthorizationCredentialAppleID credential,
) async {
  if (uid == null) return;

  final name = [credential.givenName, credential.familyName]
      .whereType<String>()
      .where((part) => part.isNotEmpty)
      .join(' ');
  if (name.isEmpty) return;

  try {
    // Only fill a blank — a returning user who has since edited their name
    // should keep it, and Apple would not have sent one anyway.
    await supabase
        .from('profiles')
        .update({'name': name})
        .eq('id', uid)
        .isFilter('name', null);
  } catch (e) {
    debugPrint('Could not save the name Apple provided: $e');
  }
}

/// A cryptographically random string for use as an OAuth nonce.
String _generateNonce([int length = 32]) {
  const chars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._';
  final random = Random.secure();
  return List.generate(length, (_) => chars[random.nextInt(chars.length)])
      .join();
}

/// Claims [role] for the signed-in user, returning the role now in force.
///
/// Goes through the `claim_role` function rather than updating `profiles`
/// directly because clients no longer hold an UPDATE grant on that column —
/// the point being that this can only ever fill a blank, never overwrite an
/// existing role. Throws on failure so the caller can keep the picker open.
Future<String> claimRole(String role) async {
  final result = await supabase.rpc('claim_role', params: {'p_role': role});
  return result as String;
}

void _showAuthError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), backgroundColor: Colors.red),
  );
}
