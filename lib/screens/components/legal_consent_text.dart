import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:padi_learn/config/web_links.dart';
import 'package:padi_learn/utils/colors.dart';
import 'package:padi_learn/utils/external_links.dart';

/// "By continuing, you agree to our Terms and Privacy Policy", with both
/// linked to padilearn.com.
///
/// Shown wherever an account can be created — the register form, and the
/// login screen, because Google sign-in there creates an account too.
class LegalConsentText extends StatelessWidget {
  const LegalConsentText({super.key});

  @override
  Widget build(BuildContext context) {
    // Subscribes to theme changes; without this the screen keeps
    // painting the previous theme's colours when the mode flips.
    AppColors.watch(context);
    final base = TextStyle(fontSize: 12.sp, color: AppColors.palette.inkSoft);
    final link = base.copyWith(
      color: AppColors.primaryColor,
      fontWeight: FontWeight.w600,
    );

    Widget linkTo(String label, String url) => InkWell(
          onTap: () => openWebPage(context, url),
          borderRadius: BorderRadius.circular(4.r),
          child: Padding(
            // Enough padding to be tappable without looking like a button.
            padding: EdgeInsets.symmetric(vertical: 4.h, horizontal: 2.w),
            child: Text(label, style: link),
          ),
        );

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('By continuing, you agree to our ', style: base),
        linkTo('Terms', WebLinks.terms),
        Text(' and ', style: base),
        linkTo('Privacy Policy', WebLinks.privacyPolicy),
      ],
    );
  }
}
