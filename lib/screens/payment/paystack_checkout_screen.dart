import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:padi_learn/utils/colors.dart';

/// Hosts the Paystack checkout page in a WebView. Pops `true` once Paystack
/// redirects to the callback URL (payment attempt finished — the server still
/// verifies), or `null` if the user backs out.
class PaystackCheckoutScreen extends StatefulWidget {
  final String authorizationUrl;
  final String callbackUrl;

  const PaystackCheckoutScreen({
    super.key,
    required this.authorizationUrl,
    required this.callbackUrl,
  });

  @override
  State<PaystackCheckoutScreen> createState() => _PaystackCheckoutScreenState();
}

class _PaystackCheckoutScreenState extends State<PaystackCheckoutScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onNavigationRequest: (request) {
            if (request.url.startsWith(widget.callbackUrl)) {
              Navigator.of(context).pop(true);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.authorizationUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Payment'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: AppColors.appWhite,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const Center(
              child: CircularProgressIndicator(color: AppColors.primaryColor),
            ),
        ],
      ),
    );
  }
}
