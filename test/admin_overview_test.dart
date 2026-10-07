// The admin overview, rendered from the document the live project returned on
// 2026-10-07. Signing in needs a real password and an authenticator, so these
// are what stands between a change to the screen and an admin finding a
// broken layout or a wrong figure: money is shown to the kobo, a waiting item
// links to the screen that deals with it, and a refused call explains itself.

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:padi_learn/admin/screens/overview_screen.dart';
import 'package:padi_learn/admin/shell/sections.dart';
import 'package:padi_learn/admin/widgets/format.dart';

import 'admin_fakes.dart';

/// admin_overview() on the live project, 2026-10-07: one test-mode sale of a
/// NGN 5,000 course, still inside the 7-day hold, and one category suggestion.
Map<String, dynamic> liveOverview() => {
      'generated_at': '2026-10-07T06:40:00+00:00',
      'waiting': {
        'open_reports': 0,
        'category_suggestions': 1,
        'refunds_owed': 0,
        'refunds_owed_kobo': 0,
        'teachers_payable': 0,
        'teachers_payable_without_bank_account': 0,
        'teachers_payouts_held': 0,
      },
      'accounts': {
        'total': 7,
        'teachers': 3,
        'students': 4,
        'role_not_chosen': 0,
        'new_7d': 3,
        'new_30d': 3,
        'suspended': 0,
        'admins': 1,
      },
      'catalogue': {
        'courses': 13,
        'live': 13,
        'archived': 0,
        'taken_down': 0,
        'paid': 1,
        'lessons': 123,
        'teachers_with_live_courses': 1,
      },
      'learning': {
        'enrollments': 2,
        'paid_enrollments': 1,
        'enrollments_7d': 2,
      },
      'money': {
        'sales': 1,
        'sales_7d': 1,
        'sales_30d': 1,
        'gross_kobo': 517767,
        'gross_30d_kobo': 517767,
        'paystack_fees_kobo': 17767,
        'platform_fees_kobo': 75000,
        'teacher_earnings_kobo': 425000,
        'refunds': 0,
        'refunded_kobo': 0,
        'refund_clawbacks_kobo': 0,
        'refund_cost_to_platform_kobo': 0,
        'platform_net_kobo': 75000,
        'payouts': 0,
        'paid_out_kobo': 0,
        'teachers_owed_kobo': 425000,
        'teachers_available_kobo': 0,
        'teachers_pending_kobo': 425000,
        'teachers_negative_kobo': 0,
      },
    };

void main() {
  group('formatKobo', () {
    test('shows the ledger to the kobo', () {
      expect(formatKobo(517767), 'NGN 5,177.67');
      expect(formatKobo(75000), 'NGN 750.00');
      expect(formatKobo(5), 'NGN 0.05');
      expect(formatKobo(0), 'NGN 0.00');
    });

    test('keeps the sign on a refund that cost more than it earned', () {
      expect(formatKobo(-17767), '-NGN 177.67');
    });
  });

  group('overview', () {
    testWidgets('renders the live figures without overflowing',
        (tester) async {
      final api = FakeAdminApi(overviewDoc: liveOverview);
      await pumpAdminScreen(tester, OverviewScreen(onOpen: (_) {}, api: api));

      expect(tester.takeException(), isNull);
      expect(find.text('Waiting for you'), findsOneWidget);
      // Gross, all time and last 30 days.
      expect(find.text('NGN 5,177.67'), findsNWidgets(2));
      // Commission and net, before any refund.
      expect(find.text('NGN 750.00'), findsNWidgets(2));
      // Teacher earnings, owed, and pending under the hold.
      expect(find.text('NGN 4,250.00'), findsNWidgets(3));
    });

    testWidgets('a waiting item opens the screen that deals with it',
        (tester) async {
      AdminSection? opened;
      final api = FakeAdminApi(overviewDoc: liveOverview);
      await pumpAdminScreen(
        tester,
        OverviewScreen(onOpen: (section) => opened = section, api: api),
      );

      await tester.tap(find.text('Category suggestions'));
      expect(opened, AdminSection.categories);
    });

    testWidgets('a refused call says why, and can be retried', (tester) async {
      final api = FakeAdminApi(overviewDoc: liveOverview)
        ..loadError = const PostgrestException(
          message: 'Admin access required',
          code: '42501',
        );
      await pumpAdminScreen(tester, OverviewScreen(onOpen: (_) {}, api: api));

      expect(find.textContaining('session may have lapsed'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(api.count('overview'), 2);
    });
  });
}
