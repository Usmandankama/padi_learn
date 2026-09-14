import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:padi_learn/screens/components/primary_button.dart';
import 'package:padi_learn/screens/home/home_shell.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:padi_learn/services/supabase.dart';
import 'package:padi_learn/utils/colors.dart';

/// Where the password-reset email lands.
///
/// Opening the emailed link signs the user into a short-lived recovery session,
/// which is what lets `updateUser` change the password without asking for the
/// old one. So this screen is only ever reached from that link — it is pushed
/// by the `passwordRecovery` listener in `main.dart`, never navigated to
/// directly.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _saving = false;
  bool _obscure = true;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      await supabase.auth.updateUser(
        UserAttributes(password: _password.text),
      );
      if (!mounted) return;

      // The recovery session is a real session, so there is nowhere to send
      // them but in — asking them to log in again with the password they just
      // set would be busywork.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated.')),
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeShell()),
        (route) => false,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      _fail(e.message);
    } catch (_) {
      if (!mounted) return;
      // Most often the recovery link has already been used or has expired.
      _fail('That reset link has expired. Request a new one.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _fail(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Set a new password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              24.w, 16.h, 24.w, 24.h + MediaQuery.of(context).padding.bottom),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose a new password',
                  style: GoogleFonts.poppins(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w700,
                    color: palette.ink,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'You are signed in from the link in your email. Set a '
                  'password and we will take you straight to your courses.',
                  style: GoogleFonts.poppins(
                    fontSize: 13.sp,
                    color: palette.inkSoft,
                  ),
                ),
                SizedBox(height: 28.h),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'New password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.length < 6) {
                      return 'Use at least 6 characters.';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16.h),
                TextFormField(
                  controller: _confirm,
                  obscureText: _obscure,
                  decoration: const InputDecoration(
                    labelText: 'Confirm password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (v) =>
                      v == _password.text ? null : 'Passwords do not match.',
                ),
                SizedBox(height: 32.h),
                PrimaryButton(
                  label: 'Save password',
                  isLoading: _saving,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
