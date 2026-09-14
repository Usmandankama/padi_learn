import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:padi_learn/screens/components/settings_tile.dart';
import 'package:padi_learn/utils/app_info.dart';

/// Help and About, for whichever profile screen is showing.
///
/// Shared rather than copied because the two profile screens are maintained
/// separately, and that is precisely how teachers ended up with no About dialog
/// at all while students kept theirs. One widget means the two roles cannot
/// drift apart again without someone deciding they should.
class ProfileSupportSection extends StatelessWidget {
  const ProfileSupportSection({super.key});

  /// Opens the user's email app addressed to support.
  ///
  /// Plenty of phones have no mail app set up, so when nothing handles the
  /// link the address is copied instead — the user can always paste it into
  /// Gmail on the web. The version goes in the subject line because the first
  /// question support asks is which build they are on.
  Future<void> _contactSupport(BuildContext context) async {
    final subject = Uri.encodeComponent('$kAppName support (v$kAppVersion)');
    final uri = Uri.parse('mailto:$kSupportEmail?subject=$subject');

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

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      title: 'SUPPORT',
      children: [
        SettingsTile(
          icon: Icons.help_outline,
          title: 'Help & Support',
          subtitle: kSupportEmail,
          onTap: () => _contactSupport(context),
        ),
        SettingsTile(
          icon: Icons.info_outline,
          title: 'About',
          onTap: () => showAboutDialog(
            context: context,
            applicationName: kAppName,
            applicationVersion: kAppVersion,
            applicationLegalese: kAppLegalese,
          ),
        ),
      ],
    );
  }
}
