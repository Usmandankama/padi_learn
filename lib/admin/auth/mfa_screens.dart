import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:padi_learn/services/supabase.dart';
import 'package:padi_learn/utils/colors.dart';

import 'auth_scaffold.dart';

/// First sign-in: pair an authenticator app with the account.
///
/// Verifying the first code both confirms the pairing and raises the session to
/// aal2, which is what is_admin() asks for, so this screen ends the same way
/// the challenge screen does: Supabase fires mfaChallengeVerified and
/// [AdminGate] moves on.
class MfaEnrolScreen extends StatefulWidget {
  const MfaEnrolScreen({super.key});

  @override
  State<MfaEnrolScreen> createState() => _MfaEnrolScreenState();
}

class _MfaEnrolScreenState extends State<MfaEnrolScreen> {
  final _code = TextEditingController();
  AuthMFAEnrollResponse? _enrolment;
  String? _loadError;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      // An enrolment abandoned halfway leaves an unverified factor behind.
      // Clearing it first means reloading this page always offers a fresh
      // code instead of failing on the leftover.
      final factors = await supabase.auth.mfa.listFactors();
      for (final factor in factors.all) {
        if (factor.factorType == FactorType.totp &&
            factor.status == FactorStatus.unverified) {
          await supabase.auth.mfa.unenroll(factor.id);
        }
      }

      final enrolment = await supabase.auth.mfa.enroll(
        factorType: FactorType.totp,
        // The name the authenticator app lists the code under.
        issuer: 'PadiLearn Admin',
        // Must be unique per user; the timestamp keeps a re-enrolment from
        // colliding with the factor it replaces.
        friendlyName:
            'Authenticator ${DateTime.now().toUtc().toIso8601String()}',
      );
      if (mounted) setState(() => _enrolment = enrolment);
    } on AuthException catch (e) {
      if (mounted) setState(() => _loadError = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _loadError =
            'Could not start the setup. Check that the authenticator (TOTP) '
            'factor is enabled for this Supabase project.');
      }
    }
  }

  Future<void> _verify() async {
    final enrolment = _enrolment;
    if (_busy || enrolment == null || _code.text.length != 6) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await supabase.auth.mfa.challengeAndVerify(
        factorId: enrolment.id,
        code: _code.text,
      );
    } on AuthException catch (e) {
      if (mounted) {
        _code.clear();
        setState(() => _error = e.message);
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not check the code.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enrolment = _enrolment;
    final totp = enrolment?.totp;

    if (_loadError != null) {
      return AuthScaffold(
        title: 'Set up your authenticator',
        children: [
          ErrorText(_loadError),
          const SizedBox(height: 16),
          const SignOutButton(),
        ],
      );
    }

    if (totp == null) {
      return const AuthScaffold(
        title: 'Set up your authenticator',
        children: [Center(child: CircularProgressIndicator())],
      );
    }

    final palette = AppColors.of(context);

    return AuthScaffold(
      title: 'Set up your authenticator',
      subtitle: 'Admin accounts need a code from an authenticator app '
          '(Google Authenticator, Microsoft Authenticator, 1Password) as well '
          'as the password. You only do this once.',
      children: [
        Text('1. Scan this with the app.',
            style: TextStyle(color: palette.ink)),
        const SizedBox(height: 12),
        Center(
          // Always dark on white, whatever the theme: phone cameras read
          // inverted QR codes badly.
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: QrImageView(
              data: totp.uri,
              size: 200,
              backgroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _SetupKey(secret: totp.secret),
        const SizedBox(height: 20),
        Text('2. Enter the 6-digit code it shows.',
            style: TextStyle(color: palette.ink)),
        const SizedBox(height: 12),
        CodeField(controller: _code, enabled: !_busy, onComplete: _verify),
        ErrorText(_error),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy ? null : _verify,
          child: Text(_busy ? 'Checking…' : 'Confirm'),
        ),
        const SizedBox(height: 8),
        const SignOutButton(),
      ],
    );
  }
}

/// The same secret as the QR code, for typing in when scanning is not an
/// option. Grouped in fours because that is how authenticator apps ask for it.
class _SetupKey extends StatelessWidget {
  const _SetupKey({required this.secret});

  final String secret;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final grouped = RegExp('.{1,4}')
        .allMatches(secret)
        .map((m) => m.group(0))
        .join(' ');

    return Column(
      children: [
        Text("Can't scan it? Enter this key instead:",
            style: TextStyle(color: palette.inkSoft, fontSize: 13)),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: SelectableText(
                grouped,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: palette.ink,
                  fontFamily: 'monospace',
                  letterSpacing: 1,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Copy key',
              icon: const Icon(Icons.copy, size: 18),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: secret));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Key copied')),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

/// Every sign-in after the first: the code from the paired app.
class MfaChallengeScreen extends StatefulWidget {
  const MfaChallengeScreen({super.key, required this.factor});

  final Factor factor;

  @override
  State<MfaChallengeScreen> createState() => _MfaChallengeScreenState();
}

class _MfaChallengeScreenState extends State<MfaChallengeScreen> {
  final _code = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_busy || _code.text.length != 6) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await supabase.auth.mfa.challengeAndVerify(
        factorId: widget.factor.id,
        code: _code.text,
      );
    } on AuthException catch (e) {
      if (mounted) {
        _code.clear();
        setState(() => _error = e.message);
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not check the code.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);

    return AuthScaffold(
      title: 'Enter your code',
      subtitle: 'The 6-digit code from your authenticator app, under '
          '"PadiLearn Admin".',
      children: [
        CodeField(controller: _code, enabled: !_busy, onComplete: _verify),
        ErrorText(_error),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy ? null : _verify,
          child: Text(_busy ? 'Checking…' : 'Continue'),
        ),
        const SizedBox(height: 16),
        // There is deliberately no self-service reset: a lost authenticator
        // that could be bypassed from this screen would make the second
        // factor decoration.
        Text(
          'Lost the authenticator? The factor has to be removed in the '
          'Supabase dashboard (Authentication → Users), then set up again.',
          style: TextStyle(color: palette.inkSoft, fontSize: 12),
        ),
        const SizedBox(height: 8),
        const SignOutButton(),
      ],
    );
  }
}
