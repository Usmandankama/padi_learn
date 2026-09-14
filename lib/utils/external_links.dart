import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:padi_learn/utils/app_info.dart';

/// Opens [url] in the phone's browser.
///
/// The external browser, not an in-app view: legal pages are read, bookmarked
/// and shared, and a browser tab does all of that for free. If nothing can
/// open it, the link is copied so the user isn't left with a dead tap.
Future<void> openWebPage(BuildContext context, String url) async {
  var opened = false;
  try {
    opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    // No browser — fall through to copying.
  }
  if (opened || !context.mounted) return;

  await Clipboard.setData(ClipboardData(text: url));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Could not open a browser. Link copied: $url')),
  );
}

/// Opens the user's email app addressed to support, with [subject] filled in.
///
/// Plenty of phones have no mail app set up, so when nothing handles the link
/// the address is copied instead — the user can paste it into Gmail on the
/// web. The version goes in the subject because the first thing support needs
/// to know is which build someone is on.
Future<void> emailSupport(BuildContext context, {String? subject}) async {
  final fullSubject =
      Uri.encodeComponent('${subject ?? '$kAppName support'} (v$kAppVersion)');
  final uri = Uri.parse('mailto:$kSupportEmail?subject=$fullSubject');

  var opened = false;
  try {
    opened = await launchUrl(uri);
  } catch (_) {
    // No handler — fall through to copying the address.
  }
  if (opened || !context.mounted) return;

  await Clipboard.setData(const ClipboardData(text: kSupportEmail));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('No email app found. $kSupportEmail copied.'),
    ),
  );
}
