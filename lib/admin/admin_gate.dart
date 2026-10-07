import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:padi_learn/services/supabase.dart';

import 'auth/auth_scaffold.dart';
import 'auth/mfa_screens.dart';
import 'auth/not_admin_screen.dart';
import 'auth/sign_in_screen.dart';
import 'shell/admin_shell.dart';

/// Decides what the admin app may show, from the session alone.
///
/// The order is the security model in docs/ADMIN_PANEL.md, made visible:
///
///   no session            → sign in
///   password only, no app → set up an authenticator app
///   password only, an app → enter its code
///   password and code     → ask the database, is_admin()
///                             false → "not an admin"
///                             true  → the panel
///
/// is_admin() itself refuses a session that has not passed the second factor,
/// so a stolen password reaches the code prompt and stops there, whatever
/// this widget draws.
class AdminGate extends StatefulWidget {
  const AdminGate({super.key});

  @override
  State<AdminGate> createState() => _AdminGateState();
}

enum _Stage { loading, signedOut, enrol, challenge, notAdmin, admin, failed }

class _AdminGateState extends State<AdminGate> {
  late final StreamSubscription<AuthState> _authSub;

  _Stage _stage = _Stage.loading;
  Factor? _factor;
  Object? _failure;

  /// A newer resolve supersedes one still in flight, so a slow is_admin() call
  /// cannot land after a sign-out and put the panel back on screen.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _authSub = supabase.auth.onAuthStateChange.listen((state) {
      switch (state.event) {
        case AuthChangeEvent.signedIn:
        case AuthChangeEvent.signedOut:
        case AuthChangeEvent.mfaChallengeVerified:
          _resolve();
        default:
          // Token refreshes change nothing the gate decides on, and
          // listFactors() refreshes the session itself, so reacting to them
          // would loop.
          break;
      }
    });
    _resolve();
  }

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }

  Future<void> _resolve() async {
    final generation = ++_generation;
    if (_stage != _Stage.loading) setState(() => _stage = _Stage.loading);

    try {
      final (stage, factor) = await _decide();
      if (!mounted || generation != _generation) return;
      setState(() {
        _stage = stage;
        _factor = factor;
        _failure = null;
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _stage = _Stage.failed;
        _failure = e;
      });
    }
  }

  Future<(_Stage, Factor?)> _decide() async {
    if (supabase.auth.currentSession == null) return (_Stage.signedOut, null);

    final aal = supabase.auth.mfa.getAuthenticatorAssuranceLevel();
    if (aal.currentLevel == AuthenticatorAssuranceLevels.aal2) {
      final isAdmin = await supabase.rpc('is_admin');
      return (isAdmin == true ? _Stage.admin : _Stage.notAdmin, null);
    }

    final factors = await supabase.auth.mfa.listFactors();
    if (factors.totp.isEmpty) return (_Stage.enrol, null);
    return (_Stage.challenge, factors.totp.first);
  }

  @override
  Widget build(BuildContext context) {
    return switch (_stage) {
      _Stage.loading => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      _Stage.signedOut => const SignInScreen(),
      _Stage.enrol => const MfaEnrolScreen(),
      _Stage.challenge => MfaChallengeScreen(factor: _factor!),
      _Stage.notAdmin => const NotAdminScreen(),
      _Stage.admin => const AdminShell(),
      _Stage.failed => AuthScaffold(
          title: 'Could not reach PadiLearn',
          subtitle: '$_failure',
          children: [
            FilledButton(onPressed: _resolve, child: const Text('Try again')),
            const SizedBox(height: 8),
            const SignOutButton(),
          ],
        ),
    };
  }
}
