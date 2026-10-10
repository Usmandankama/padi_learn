import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:padi_learn/screens/components/primary_button.dart';
import 'package:padi_learn/utils/colors.dart';

/// Heads a draft's own screen: that it is a draft, what it still needs, and
/// the button that uploads it.
///
/// [gaps] comes from `publishGaps`. The button stays live while things are
/// missing, because tapping it is how a teacher asks "why can't I?"; the
/// screen answers with the same list as a sentence.
class DraftPanel extends StatelessWidget {
  final List<String> gaps;
  final bool busy;
  final VoidCallback onUpload;

  const DraftPanel({
    super.key,
    required this.gaps,
    required this.busy,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    // Subscribes to theme changes; without this the screen keeps
    // painting the previous theme's colours when the mode flips.
    AppColors.watch(context);
    final accent = AppColors.draftOf(context);

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This course is a draft',
            style: GoogleFonts.poppins(
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            'Only you can see it. Upload it when it is ready and it goes live '
            'in the marketplace straight away.',
            style: GoogleFonts.poppins(
              fontSize: 12.5.sp,
              color: AppColors.palette.ink,
            ),
          ),
          SizedBox(height: 10.h),
          if (gaps.isEmpty)
            _line(Icons.check_circle_outline, 'Everything it needs is here.',
                AppColors.primaryColor)
          else ...[
            Text(
              'Still needed before you can upload:',
              style: GoogleFonts.poppins(
                fontSize: 12.5.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.palette.ink,
              ),
            ),
            SizedBox(height: 4.h),
            for (final gap in gaps)
              _line(Icons.radio_button_unchecked, _sentenceCase(gap), accent),
            SizedBox(height: 4.h),
            Text(
              'Details and the cover are under Edit course. Videos go in the '
              'Lessons tab.',
              style: GoogleFonts.poppins(
                fontSize: 11.sp,
                color: AppColors.palette.inkSoft,
              ),
            ),
          ],
          SizedBox(height: 12.h),
          PrimaryButton(
            label: 'Upload',
            isLoading: busy,
            onPressed: onUpload,
          ),
        ],
      ),
    );
  }

  Widget _line(IconData icon, String text, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2.h),
      child: Row(
        children: [
          Icon(icon, size: 15.sp, color: color),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 12.5.sp,
                color: AppColors.palette.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// `a cover image` -> `A cover image`
  String _sentenceCase(String text) =>
      text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
}
