import 'package:flutter/material.dart';

import 'package:padi_learn/services/supabase.dart';
import 'package:padi_learn/utils/colors.dart';

/// The panel's frame: navigation down the side, the signed-in admin and a way
/// out across the top. Only reached once [AdminGate] has heard is_admin() say
/// true.
///
/// The sections are all here so the shape of the panel is visible from the
/// first build; each one gets its screen in item 12 (docs/ADMIN_PANEL.md).
/// Overview already shows what is waiting, which doubles as a check that the
/// whole chain works: second factor, is_admin(), and an admin RPC.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _Section {
  const _Section(this.label, this.icon);

  final String label;
  final IconData icon;
}

const _sections = [
  _Section('Overview', Icons.space_dashboard_outlined),
  _Section('Reports', Icons.flag_outlined),
  _Section('Courses', Icons.video_library_outlined),
  _Section('Users', Icons.people_outline),
  _Section('Refunds', Icons.undo),
  _Section('Payouts', Icons.payments_outlined),
  _Section('Categories', Icons.category_outlined),
  _Section('Audit log', Icons.history),
];

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

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
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
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
              for (final section in _sections)
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
                title: Text(_sections[_index].label),
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
              body: _index == 0
                  ? const _WaitingPreview()
                  : _ComingSoon(section: _sections[_index].label),
            ),
          ),
        ],
      ),
    );
  }
}

/// What is waiting, from admin_overview(). Replaced by the full overview in
/// item 12.
class _WaitingPreview extends StatefulWidget {
  const _WaitingPreview();

  @override
  State<_WaitingPreview> createState() => _WaitingPreviewState();
}

class _WaitingPreviewState extends State<_WaitingPreview> {
  late Future<Map<String, dynamic>> _overview = _load();

  Future<Map<String, dynamic>> _load() async {
    final result = await supabase.rpc('admin_overview');
    return Map<String, dynamic>.from(result as Map);
  }

  static const _labels = {
    'open_reports': 'Open reports',
    'category_suggestions': 'Category suggestions',
    'refunds_owed': 'Refunds owed',
    'teachers_payable': 'Teachers to pay',
    'teachers_payable_without_bank_account':
        'Of those, without a verified bank account',
    'teachers_payouts_held': 'Payouts held (suspended teachers)',
  };

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);

    return FutureBuilder<Map<String, dynamic>>(
      future: _overview,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Could not load the overview: ${snapshot.error}'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => setState(() => _overview = _load()),
                  child: const Text('Try again'),
                ),
              ],
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final waiting =
            Map<String, dynamic>.from(snapshot.data!['waiting'] as Map);

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Waiting for you',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final entry in _labels.entries)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(entry.value),
                trailing: Text(
                  '${waiting[entry.key] ?? 0}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            const SizedBox(height: 16),
            Text(
              'The full overview arrives with the rest of the screens.',
              style: TextStyle(color: palette.inkSoft),
            ),
          ],
        );
      },
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
