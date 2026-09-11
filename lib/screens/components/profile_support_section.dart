import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      title: 'SUPPORT',
      children: [
        SettingsTile(
          icon: Icons.help_outline,
          title: 'Help & Support',
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Support is coming soon')),
          ),
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
