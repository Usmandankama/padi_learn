import 'package:flutter/material.dart';

import 'package:padi_learn/services/supabase.dart';
import 'package:padi_learn/utils/colors.dart';

import '../screens/courses_screen.dart';
import '../screens/overview_screen.dart';
import '../screens/refunds_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/users_screen.dart';
import 'sections.dart';

/// The panel's frame: navigation down the side, the signed-in admin and a way
/// out across the top. Only reached once [AdminGate] has heard is_admin() say
/// true.
///
/// Every section is listed from the first build so the shape of the panel is
/// visible; each gets its screen as item 12 progresses (docs/ADMIN_PANEL.md).
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  AdminSection _section = AdminSection.overview;

  void _open(AdminSection section) => setState(() => _section = section);

  Widget _screen() {
    return switch (_section) {
      AdminSection.overview => OverviewScreen(onOpen: _open),
      AdminSection.reports => const ReportsScreen(),
      AdminSection.users => const UsersScreen(),
      AdminSection.courses => const CoursesScreen(),
      AdminSection.refunds => const RefundsScreen(),
      _ => _ComingSoon(section: _section.label),
    };
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final email = supabase.auth.currentUser?.email ?? '';
    final wide = MediaQuery.sizeOf(context).width >= 1000;

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: wide,
            selectedIndex: _section.index,
            onDestinationSelected: (i) => _open(AdminSection.values[i]),
            labelType: wide ? null : NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                wide ? 'PadiLearn Admin' : 'Admin',
                style: const TextStyle(
                  color: AppColors.primaryColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            destinations: [
              for (final section in AdminSection.values)
                NavigationRailDestination(
                  icon: Icon(section.icon),
                  label: Text(section.label),
                ),
            ],
          ),
          VerticalDivider(width: 1, color: palette.hairline),
          Expanded(
            child: Scaffold(
              appBar: AppBar(
                title: Text(_section.label),
                actions: [
                  Text(email, style: TextStyle(color: palette.inkSoft)),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => supabase.auth.signOut(),
                    child: const Text('Sign out'),
                  ),
                  const SizedBox(width: 12),
                ],
              ),
              // Keyed by section so switching away and back starts the screen
              // afresh, with current data, rather than reviving a stale one.
              body: KeyedSubtree(key: ValueKey(_section), child: _screen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComingSoon extends StatelessWidget {
  const _ComingSoon({required this.section});

  final String section;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '$section arrives with the next item.',
        style: TextStyle(color: AppColors.of(context).inkSoft),
      ),
    );
  }
}
