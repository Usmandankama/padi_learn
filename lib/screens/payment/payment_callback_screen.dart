import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:padi_learn/screens/onboarding/splash_screen.dart';
import 'package:padi_learn/services/payment_service.dart';
import 'package:padi_learn/services/pending_purchase.dart';
import 'package:padi_learn/utils/colors.dart';

/// Where Paystack sends the student back to on web.
///
/// The app has just been reloaded from nothing, so this screen is the only
/// thing that knows a purchase was in flight. It asks the server to verify —
/// the same `verify-payment` function the mobile flow calls — and only then
/// says anything about the outcome. Paystack returning here is not proof of
/// payment; the server's answer is.
class PaymentCallbackScreen extends StatefulWidget {
  /// Path Paystack redirects to. Must be served the app's `index.html` by the
  /// host, not a 404 — see `docs/LAUNCH_WEB.md`.
  static const String path = '/payment-callback';

  const PaymentCallbackScreen({super.key});

  @override
  State<PaymentCallbackScreen> createState() => _PaymentCallbackScreenState();
}

class _PaymentCallbackScreenState extends State<PaymentCallbackScreen> {
  bool _working = true;
  bool _verified = false;
  String _courseTitle = '';
  String _message = '';

  @override
  void initState() {
    super.initState();
    _finish();
  }

  Future<void> _finish() async {
    // Paystack puts the reference in the query string; the stored copy is the
    // fallback for a browser that strips it or a student who reloads.
    final pending = await PendingPurchase.read();
    final fromUrl = Uri.base.queryParameters['reference'] ??
        Uri.base.queryParameters['trxref'];
    final reference = (fromUrl != null && fromUrl.isNotEmpty)
        ? fromUrl
        : pending?.reference;

    if (reference == null || reference.isEmpty) {
      setState(() {
        _working = false;
        _verified = false;
        _message = 'We could not find a payment to confirm.';
      });
      return;
    }

    final ok = await PaymentService.verify(reference);

    // Cleared either way. A declined card must not be retried on every load.
    await PendingPurchase.clear();

    if (!mounted) return;
    setState(() {
      _working = false;
      _verified = ok;
      _courseTitle = pending?.courseTitle ?? '';
      _message = ok
          ? 'Your payment is confirmed and the course is yours to keep.'
          : 'We could not confirm this payment. If you were charged, nothing '
              'is lost — contact support with your reference and we will sort it out.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_working) ...[
                  const CircularProgressIndicator(
                      color: AppColors.primaryColor),
                  const SizedBox(height: 24),
                  Text('Confirming your payment…',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Do not close this page.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ] else ...[
                  Icon(
                    _verified ? Icons.check_circle : Icons.error_outline,
                    size: 48,
                    color: _verified
                        ? AppColors.primaryColor
                        : theme.colorScheme.error,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _verified ? 'Payment confirmed' : 'Not confirmed',
                    style: theme.textTheme.headlineSmall,
                  ),
                  if (_verified && _courseTitle.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(_courseTitle, style: theme.textTheme.titleMedium),
                  ],
                  const SizedBox(height: 12),
                  Text(_message, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 28),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: AppColors.appWhite,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: () => Get.offAll(() => const SplashScreen()),
                    child: Text(_verified ? 'Start learning' : 'Back to PadiLearn'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
