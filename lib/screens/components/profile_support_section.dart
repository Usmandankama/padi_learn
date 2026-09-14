import 'package:flutter/material.dart';

import 'package:padi_learn/config/web_links.dart';
import 'package:padi_learn/screens/components/settings_tile.dart';
import 'package:padi_learn/utils/app_info.dart';
import 'package:padi_learn/utils/external_links.dart';

/// Help, legal pages and About, for whichever profile screen is showing.
///
/// Shared rather than copied because the two profile screens are maintained
/// separately, and that is precisely how teachers ended up with no About dialog
/// at all while students kept theirs. One widget means the two roles cannot
/// drift apart again without someone deciding they should.
///
/// The privacy policy and terms open padilearn.com rather than being bundled
/// into the app, so there is one copy to keep correct — the same one the Play
/// listing links to.
class ProfileSupportSection extends StatelessWidget {
  const ProfileSupportSection({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      title: 'SUPPORT & LEGAL',
      children: [
        SettingsTile(
          icon: Icons.help_outline,
          title: 'Help & Support',
          subtitle: kSupportEmail,
          onTap: () => emailSupport(context),
        ),
        SettingsTile(
          icon: Icons.privacy_tip_outlined,
          title: 'Privacy Policy',
          onTap: () => openWebPage(context, WebLinks.privacyPolicy),
        ),
        SettingsTile(
          icon: Icons.description_outlined,
          title: 'Terms of Service',
          onTap: () => openWebPage(context, WebLinks.terms),
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
