import 'package:flutter/material.dart';

import 'package:padi_learn/services/supabase.dart';

import 'auth_scaffold.dart';

/// Signed in, second factor passed, and still not an admin: is_admin() said
/// no. Usually the wrong account; occasionally an admin whose row was removed.
class NotAdminScreen extends StatelessWidget {
  const NotAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final email = supabase.auth.currentUser?.email ?? 'This account';

    return AuthScaffold(
      title: 'Not an admin account',
      subtitle: '$email is not an admin. If it should be, an existing admin '
          'adds it from the Supabase SQL editor (docs/ADMIN_PANEL.md, '
          '"Managing admins").',
      children: const [SignOutButton()],
    );
  }
}
