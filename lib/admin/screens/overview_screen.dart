import 'package:flutter/material.dart';

import 'package:padi_learn/utils/colors.dart';

import '../data/admin_api.dart';
import '../shell/sections.dart';
import '../widgets/format.dart';
import '../widgets/panel.dart';

/// The first screen: what needs doing, then how things stand.
///
/// Everything comes from one call, admin_overview(), which takes its sums from
/// the same functions as the detail screens, so a figure here always matches
/// the screen it links to.
class OverviewScreen extends StatefulWidget {
  const OverviewScreen({
    super.key,
    required this.onOpen,
    this.api = const AdminApi(),
  });

  /// Jumps to another section of the panel.
  final void Function(AdminSection section) onOpen;

  final AdminApi api;

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  final _loader = GlobalKey<AdminLoaderState<Map<String, dynamic>>>();

  @override
  Widget build(BuildContext context) {
    return AdminLoader<Map<String, dynamic>>(
      key: _loader,
      load: widget.api.overview,
      builder: (context, overview) => _Overview(
        overview: overview,
        onOpen: widget.onOpen,
        onRefresh: () => _loader.currentState?.reload(),
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({
    required this.overview,
    required this.onOpen,
    required this.onRefresh,
  });

  final Map<String, dynamic> overview;
  final void Function(AdminSection section) onOpen;
  final VoidCallback onRefresh;

  Map<String, dynamic> _part(String key) =>
      Map<String, dynamic>.from(overview[key] as Map? ?? const {});

  @override
  Widget build(BuildContext context) {
    final waiting = _part('waiting');
    final accounts = _part('accounts');
    final catalogue = _part('catalogue');
    final learning = _part('learning');
    final money = _part('money');
    final palette = AppColors.of(context);

    String count(Map<String, dynamic> m, String key) => '${asCount(m[key])}';
    String kobo(Map<String, dynamic> m, String key) =>
        formatKobo(asCount(m[key]));

    StatRow waitingRow(String label, String key, AdminSection section,
        {String? amountKey}) {
      final n = asCount(waiting[key]);
      final amount = amountKey == null ? '' : ' · ${kobo(waiting, amountKey)}';
      return StatRow(
        label: label,
        value: '$n$amount',
        highlight: n > 0,
        onTap: () => onOpen(section),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Updated ${formatWhen(overview['generated_at'])}',
                style: TextStyle(color: palette.inkSoft),
              ),
            ),
            TextButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            AdminCard(
              title: 'Waiting for you',
              children: [
                waitingRow('Open reports', 'open_reports', AdminSection.reports),
                waitingRow('Category suggestions', 'category_suggestions',
                    AdminSection.categories),
                waitingRow('Refunds owed', 'refunds_owed', AdminSection.refunds,
                    amountKey: 'refunds_owed_kobo'),
                waitingRow('Payout requests', 'payout_requests',
                    AdminSection.payouts,
                    amountKey: 'payout_requests_kobo'),
                waitingRow('Teachers to pay', 'teachers_payable',
                    AdminSection.payouts),
                StatRow(
                  label: 'without a verified bank account',
                  value: count(waiting, 'teachers_payable_without_bank_account'),
                  indent: true,
                ),
                StatRow(
                  label: 'Payouts held (suspended teachers)',
                  value: count(waiting, 'teachers_payouts_held'),
                ),
              ],
            ),
            AdminCard(
              title: 'Money',
              children: [
                StatRow(label: 'Sales', value: count(money, 'sales')),
                StatRow(
                    label: 'last 7 days',
                    value: count(money, 'sales_7d'),
                    indent: true),
                StatRow(
                    label: 'last 30 days',
                    value: count(money, 'sales_30d'),
                    indent: true),
                StatRow(label: 'Gross', value: kobo(money, 'gross_kobo')),
                StatRow(
                    label: 'last 30 days',
                    value: kobo(money, 'gross_30d_kobo'),
                    indent: true),
                StatRow(
                    label: 'Paystack fees',
                    value: kobo(money, 'paystack_fees_kobo')),
                StatRow(
                    label: 'PadiLearn commission',
                    value: kobo(money, 'platform_fees_kobo')),
                StatRow(
                    label: 'less refund costs',
                    value: kobo(money, 'refund_cost_to_platform_kobo'),
                    indent: true),
                StatRow(
                  label: 'PadiLearn net',
                  value: kobo(money, 'platform_net_kobo'),
                  highlight: true,
                ),
                StatRow(
                  label: 'Refunds',
                  value: '${count(money, 'refunds')} · '
                      '${kobo(money, 'refunded_kobo')}',
                ),
              ],
            ),
            AdminCard(
              title: 'Teachers',
              children: [
                StatRow(
                    label: 'Teacher earnings',
                    value: kobo(money, 'teacher_earnings_kobo')),
                StatRow(
                    label: 'Paid out',
                    value: '${count(money, 'payouts')} · '
                        '${kobo(money, 'paid_out_kobo')}'),
                StatRow(
                    label: 'Owed',
                    value: kobo(money, 'teachers_owed_kobo'),
                    onTap: () => onOpen(AdminSection.payouts)),
                StatRow(
                    label: 'payable now',
                    value: kobo(money, 'teachers_available_kobo'),
                    indent: true),
                StatRow(
                    label: 'pending (7-day hold)',
                    value: kobo(money, 'teachers_pending_kobo'),
                    indent: true),
                StatRow(
                    label: 'Negative balances',
                    value: kobo(money, 'teachers_negative_kobo')),
              ],
            ),
            AdminCard(
              title: 'Accounts',
              children: [
                StatRow(
                    label: 'Accounts',
                    value: count(accounts, 'total'),
                    onTap: () => onOpen(AdminSection.users)),
                StatRow(
                    label: 'teachers',
                    value: count(accounts, 'teachers'),
                    indent: true),
                StatRow(
                    label: 'students',
                    value: count(accounts, 'students'),
                    indent: true),
                StatRow(
                    label: 'role not chosen',
                    value: count(accounts, 'role_not_chosen'),
                    indent: true),
                StatRow(
                    label: 'New in 7 days', value: count(accounts, 'new_7d')),
                StatRow(
                    label: 'New in 30 days',
                    value: count(accounts, 'new_30d')),
                StatRow(
                    label: 'Suspended', value: count(accounts, 'suspended')),
                StatRow(label: 'Admins', value: count(accounts, 'admins')),
              ],
            ),
            AdminCard(
              title: 'Catalogue',
              children: [
                StatRow(
                    label: 'Courses',
                    value: count(catalogue, 'courses'),
                    onTap: () => onOpen(AdminSection.courses)),
                StatRow(
                    label: 'live',
                    value: count(catalogue, 'live'),
                    indent: true),
                StatRow(
                    label: 'archived by their teacher',
                    value: count(catalogue, 'archived'),
                    indent: true),
                StatRow(
                    label: 'taken down',
                    value: count(catalogue, 'taken_down'),
                    indent: true),
                StatRow(
                    label: 'Paid courses', value: count(catalogue, 'paid')),
                StatRow(label: 'Lessons', value: count(catalogue, 'lessons')),
                StatRow(
                    label: 'Teachers with live courses',
                    value: count(catalogue, 'teachers_with_live_courses')),
              ],
            ),
            AdminCard(
              title: 'Learning',
              children: [
                StatRow(
                    label: 'Enrolments', value: count(learning, 'enrollments')),
                StatRow(
                    label: 'paid',
                    value: count(learning, 'paid_enrollments'),
                    indent: true),
                StatRow(
                    label: 'New in 7 days',
                    value: count(learning, 'enrollments_7d')),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
