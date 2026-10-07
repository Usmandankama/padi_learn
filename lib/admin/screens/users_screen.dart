import 'dart:async';

import 'package:flutter/material.dart';

import 'package:padi_learn/utils/colors.dart';
import 'package:padi_learn/utils/money.dart';

import '../data/admin_api.dart';
import '../widgets/format.dart';
import '../widgets/panel.dart';
import '../widgets/reason_dialog.dart';

/// Users (docs/ADMIN_PANEL.md, item 12c): find an account, see everything
/// about it, correct its role, suspend it or lift a suspension.
///
/// Search on the left, the selected account on the right; on a narrow window
/// the account opens as its own page instead.
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key, this.api = const AdminApi()});

  final AdminApi api;

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _query = '';
  String? _selectedId;

  /// Bumped when an action on the selected account changes how it should
  /// appear in the list (a badge, a role).
  int _version = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  void _listChanged() => setState(() {
        _version++;
      });

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);

    return LayoutBuilder(builder: (context, constraints) {
      final split = constraints.maxWidth >= 900;

      final list = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: _onSearchChanged,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search by email, name or user id',
              ),
            ),
          ),
          Expanded(
            child: AdminLoader<List<Map<String, dynamic>>>(
              key: ValueKey('$_query/$_version'),
              load: () => widget.api.searchUsers(_query),
              builder: (context, users) {
                if (users.isEmpty) {
                  return Center(
                    child: Text('No accounts match.',
                        style: TextStyle(color: palette.inkSoft)),
                  );
                }
                return ListView.builder(
                  itemCount: users.length + 1,
                  itemBuilder: (context, i) {
                    if (i == users.length) {
                      return users.length < AdminApi.userPageSize
                          ? const SizedBox.shrink()
                          : Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'Showing the newest ${AdminApi.userPageSize} '
                                'matches. Search to narrow it down.',
                                style: TextStyle(color: palette.inkSoft),
                              ),
                            );
                    }
                    final user = users[i];
                    final id = user['id'] as String;
                    return _UserTile(
                      user: user,
                      selected: split && id == _selectedId,
                      onTap: () {
                        if (split) {
                          setState(() => _selectedId = id);
                        } else {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => Scaffold(
                              appBar: AppBar(title: const Text('Account')),
                              body: UserDetail(
                                userId: id,
                                api: widget.api,
                                onChanged: _listChanged,
                              ),
                            ),
                          ));
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      );

      if (!split) return list;

      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: 380, child: list),
          VerticalDivider(width: 1, color: palette.hairline),
          Expanded(
            child: _selectedId == null
                ? Center(
                    child: Text('Choose an account.',
                        style: TextStyle(color: palette.inkSoft)),
                  )
                : UserDetail(
                    key: ValueKey(_selectedId),
                    userId: _selectedId!,
                    api: widget.api,
                    onChanged: _listChanged,
                  ),
          ),
        ],
      );
    });
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.user,
    required this.selected,
    required this.onTap,
  });

  final Map<String, dynamic> user;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final stats = [
      'Joined ${formatWhen(user['created_at']).split(',').first}',
      if (asCount(user['course_count']) > 0)
        '${asCount(user['course_count'])} courses',
      if (asCount(user['enrollment_count']) > 0)
        '${asCount(user['enrollment_count'])} enrolled',
      if (asCount(user['purchase_count']) > 0)
        '${asCount(user['purchase_count'])} bought',
    ].join(' · ');

    return ListTile(
      selected: selected,
      selectedTileColor: AppColors.primaryAccent,
      onTap: onTap,
      title: Text(
        (user['name'] as String?)?.trim().isNotEmpty == true
            ? user['name'] as String
            : '(no name)',
        style: TextStyle(color: palette.ink, fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${user['email'] ?? ''}',
              style: TextStyle(color: palette.inkSoft)),
          const SizedBox(height: 4),
          _Badges(account: user),
          const SizedBox(height: 2),
          Text(stats,
              style: TextStyle(color: palette.inkSoft, fontSize: 12)),
        ],
      ),
    );
  }
}

/// Role, admin, suspension and confirmation at a glance. Reads the same keys
/// from a search row or a detail document (`suspended` vs `suspension`).
class _Badges extends StatelessWidget {
  const _Badges({required this.account});

  final Map<String, dynamic> account;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    final palette = AppColors.of(context);
    final suspended =
        account['suspended'] == true || account['suspension'] != null;
    final confirmed = account['email_confirmed'] == true ||
        account['email_confirmed_at'] != null;

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        _Badge(account['role'] as String? ?? 'No role', palette.inkSoft),
        if (account['is_admin'] == true)
          const _Badge('Admin', AppColors.primaryColor),
        if (suspended) _Badge('Suspended', error),
        if (!confirmed) _Badge('Email unconfirmed', palette.inkSoft),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11)),
    );
  }
}

/// Everything about one account, from admin_user_detail(), with the actions
/// that change it.
class UserDetail extends StatefulWidget {
  const UserDetail({
    super.key,
    required this.userId,
    this.api = const AdminApi(),
    this.onChanged,
  });

  final String userId;
  final AdminApi api;

  /// Told after an action succeeds, so the list can refresh its badges.
  final VoidCallback? onChanged;

  @override
  State<UserDetail> createState() => _UserDetailState();
}

class _UserDetailState extends State<UserDetail> {
  int _version = 0;
  bool _busy = false;

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _act(Future<String> Function() action) async {
    setState(() => _busy = true);
    try {
      final message = await action();
      if (!mounted) return;
      _snack(message);
      setState(() {
        _version++;
      });
      widget.onChanged?.call();
    } catch (e) {
      if (mounted) _snack(adminErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _name(Map<String, dynamic> user) =>
      (user['name'] as String?)?.trim().isNotEmpty == true
          ? user['name'] as String
          : (user['email'] as String? ?? 'this account');

  Future<void> _suspend(Map<String, dynamic> user) async {
    final reason = await askForReason(
      context,
      title: 'Suspend ${_name(user)}?',
      message: 'They can still sign in, watch what they own and delete their '
          'account, but cannot post, upload, rate, report, enrol, buy or '
          'change bank details. Their courses leave the catalogue; students '
          'who bought them keep them. Payouts to them are held. It lasts '
          'until you lift it.',
      confirmLabel: 'Suspend',
      destructive: true,
    );
    if (reason == null) return;

    await _act(() async {
      final result = await widget.api.suspendUser(widget.userId, reason);
      final hidden = asCount(result['courses_hidden']);
      return hidden == 0
          ? 'Suspended.'
          : 'Suspended. $hidden ${hidden == 1 ? 'course' : 'courses'} left '
              'the catalogue.';
    });
  }

  Future<void> _lift(Map<String, dynamic> user) async {
    final reason = await askForReason(
      context,
      title: 'Lift the suspension?',
      message: 'Everything ${_name(user)} could do before comes back, their '
          'courses return to the catalogue, and held payouts can be made.',
      confirmLabel: 'Lift suspension',
    );
    if (reason == null) return;

    await _act(() async {
      await widget.api.liftSuspension(widget.userId, reason);
      return 'Suspension lifted.';
    });
  }

  Future<void> _changeRole(Map<String, dynamic> user) async {
    final choice = await showDialog<(String?, String)>(
      context: context,
      builder: (_) => _RoleDialog(current: user['role'] as String?),
    );
    if (choice == null) return;
    final (role, reason) = choice;

    await _act(() async {
      await widget.api.setRole(widget.userId, role, reason);
      return role == null
          ? 'Role cleared. They choose again on their next launch.'
          : 'Role changed to $role.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AdminLoader<Map<String, dynamic>>(
      key: ValueKey(_version),
      load: () => widget.api.userDetail(widget.userId),
      builder: (context, user) => _detail(context, user),
    );
  }

  Widget _detail(BuildContext context, Map<String, dynamic> user) {
    final palette = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final error = Theme.of(context).colorScheme.error;

    final suspension = user['suspension'] as Map?;
    final isAdmin = user['is_admin'] == true;
    final providers = (user['providers'] as List? ?? const []).join(', ');
    final factors = asCount(user['verified_mfa_factors']);

    final courses = (user['courses'] as List? ?? const []).cast<Map>();
    final enrolments = (user['enrollments'] as List? ?? const []).cast<Map>();
    final purchases = (user['purchases'] as List? ?? const []).cast<Map>();
    final actions = (user['admin_actions'] as List? ?? const []).cast<Map>();
    final balance = user['balance'] as Map?;
    final payout = user['payout_account'] as Map?;
    final against = user['reports_against'] as Map? ?? const {};

    Widget fact(String s) => Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(s, style: text.bodyMedium?.copyWith(color: palette.inkSoft)),
        );

    String courseState(Map c) => c['removed_at'] != null
        ? 'taken down'
        : c['archived_at'] != null
            ? 'archived'
            : 'live';

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(_name(user),
            style: text.headlineSmall?.copyWith(
                color: palette.ink, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        SelectableText('${user['email'] ?? ''}',
            style: text.bodyLarge?.copyWith(color: palette.ink)),
        const SizedBox(height: 8),
        _Badges(account: user),
        const SizedBox(height: 8),
        fact('Joined ${formatWhen(user['created_at'])}'),
        fact(user['last_sign_in_at'] == null
            ? 'Never signed in'
            : 'Last signed in ${formatWhen(user['last_sign_in_at'])}'),
        if (providers.isNotEmpty) fact('Signs in with: $providers'),
        if (isAdmin)
          fact(factors > 0
              ? 'Authenticator: set up'
              : 'Authenticator: not set up yet'),
        const SizedBox(height: 4),
        SelectableText('Id: ${user['id']}',
            style: text.bodySmall?.copyWith(color: palette.inkSoft)),
        const SizedBox(height: 16),
        if (suspension != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: error),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Suspended since ${formatWhen(suspension['suspended_at'])}: '
              '${suspension['reason'] ?? ''}',
              style: TextStyle(color: palette.ink),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton(
              onPressed: _busy ? null : () => _changeRole(user),
              child: const Text('Change role'),
            ),
            if (isAdmin)
              Text('Admins cannot be suspended.',
                  style: TextStyle(color: palette.inkSoft))
            else if (suspension != null)
              FilledButton(
                onPressed: _busy ? null : () => _lift(user),
                child: const Text('Lift suspension'),
              )
            else
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: error),
                onPressed: _busy ? null : () => _suspend(user),
                child: const Text('Suspend'),
              ),
          ],
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            if (courses.isNotEmpty || balance != null || payout != null)
              AdminCard(
                title: 'Teaching',
                width: 420,
                children: [
                  for (final c in courses)
                    StatRow(
                      label: '${c['title']} (${courseState(c)})',
                      value: '${formatPriceLabel(c['price'] as num? ?? 0)} · '
                          '${asCount(c['enrollments'])} enrolled',
                    ),
                  if (balance != null) ...[
                    const Divider(),
                    StatRow(
                        label: 'Earned',
                        value: formatKobo(asCount(balance['earned_kobo']))),
                    StatRow(
                        label: 'taken back by refunds',
                        value: formatKobo(asCount(balance['clawback_kobo'])),
                        indent: true),
                    StatRow(
                        label: 'paid out',
                        value: formatKobo(asCount(balance['paid_out_kobo'])),
                        indent: true),
                    StatRow(
                        label: 'Balance',
                        value: formatKobo(asCount(balance['balance_kobo']))),
                    StatRow(
                        label: 'pending (7-day hold)',
                        value: formatKobo(asCount(balance['pending_kobo'])),
                        indent: true),
                    StatRow(
                      label: 'payable now',
                      value: formatKobo(asCount(balance['available_kobo'])),
                      indent: true,
                      highlight: asCount(balance['available_kobo']) > 0,
                    ),
                  ],
                  const Divider(),
                  StatRow(
                    label: 'Bank account',
                    value: payout == null
                        ? 'none'
                        : '${payout['bank_name']} ····'
                            '${payout['account_last4']}'
                            '${payout['verified'] == true ? '' : ' (unverified)'}',
                  ),
                ],
              ),
            AdminCard(
              title: 'Learning',
              width: 420,
              children: [
                if (enrolments.isEmpty && purchases.isEmpty)
                  fact('Not enrolled in anything.'),
                for (final e in enrolments)
                  StatRow(
                    label: '${e['title']}',
                    value: '${e['is_free'] == true ? 'free' : 'paid'} · '
                        '${asCount(e['progress'])}%',
                  ),
                if (purchases.isNotEmpty) const Divider(),
                for (final p in purchases)
                  StatRow(
                    label: '${p['course_title'] ?? 'a deleted course'}, '
                        '${formatWhen(p['paid_at']).split(',').first}',
                    value: '${formatKobo(asCount(p['amount_kobo']))}'
                        '${p['refunded'] == true ? ' · refunded' : ''}',
                  ),
              ],
            ),
            AdminCard(
              title: 'Conduct',
              width: 420,
              children: [
                StatRow(
                    label: 'Reports filed',
                    value: '${asCount(user['reports_filed'])}'),
                StatRow(
                  label: 'Reports against them',
                  value: '${asCount(against['open'])} open of '
                      '${asCount(against['total'])}',
                  highlight: asCount(against['open']) > 0,
                ),
                if (actions.isNotEmpty) const Divider(),
                for (final a in actions)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      '${_actionLabel(a)}, ${formatWhen(a['created_at'])}: '
                      '${a['reason'] ?? ''}',
                      style: text.bodySmall?.copyWith(color: palette.ink),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  static String _actionLabel(Map action) {
    final details = action['details'] as Map? ?? const {};
    return switch (action['action']) {
      'user.suspend' => 'Suspended',
      'user.unsuspend' => 'Suspension lifted',
      'user.set_role' =>
        'Role ${details['from'] ?? 'none'} → ${details['to'] ?? 'none'}',
      final other => '$other',
    };
  }
}

/// Picks the new role and asks why, in one dialog. Returns `(role, reason)`
/// with a null role meaning "clear it, let them choose again".
class _RoleDialog extends StatefulWidget {
  const _RoleDialog({required this.current});

  final String? current;

  @override
  State<_RoleDialog> createState() => _RoleDialogState();
}

class _RoleDialogState extends State<_RoleDialog> {
  static const _clear = 'none';

  final _reason = TextEditingController();
  String? _choice;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  bool get _ready => _choice != null && _reason.text.trim().isNotEmpty;

  void _confirm() {
    if (!_ready) return;
    Navigator.of(context)
        .pop((_choice == _clear ? null : _choice, _reason.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.current ?? _clear;

    return AlertDialog(
      title: const Text('Change role'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Currently: ${widget.current ?? 'no role'}.'),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              emptySelectionAllowed: true,
              segments: [
                ButtonSegment(
                  value: 'Student',
                  label: const Text('Student'),
                  enabled: current != 'Student',
                ),
                ButtonSegment(
                  value: 'Teacher',
                  label: const Text('Teacher'),
                  enabled: current != 'Teacher',
                ),
                ButtonSegment(
                  value: _clear,
                  label: const Text('Let them choose'),
                  enabled: current != _clear,
                ),
              ],
              selected: {if (_choice != null) _choice!},
              onSelectionChanged: (s) =>
                  setState(() => _choice = s.isEmpty ? null : s.first),
            ),
            const SizedBox(height: 8),
            const Text(
              'A teacher who owns courses cannot be made a student or cleared: '
              'the student side of the app has nowhere to manage courses.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reason,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'Reason',
                helperText: 'Recorded in the audit log.',
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _confirm(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _ready ? _confirm : null,
          child: const Text('Change role'),
        ),
      ],
    );
  }
}
