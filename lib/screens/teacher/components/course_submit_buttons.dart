import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:padi_learn/screens/components/primary_button.dart';
import 'package:padi_learn/utils/colors.dart';

/// The two ways off the create-course screen, side by side.
///
/// "Upload" puts the course in the marketplace now and needs the whole form.
/// "Save to drafts" needs only a title and keeps the course where nobody but
/// its teacher can see it. Null callbacks grey both out, which the screen uses
/// while it is still reading a chosen video.
class CourseSubmitButtons extends StatelessWidget {
  final VoidCallback? onSaveDraft;
  final VoidCallback? onUpload;

  const CourseSubmitButtons({
    super.key,
    required this.onSaveDraft,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    // Subscribes to theme changes; without this the screen keeps
    // painting the previous theme's colours when the mode flips.
    AppColors.watch(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: SecondaryButton(
                label: 'Save to drafts',
                onPressed: onSaveDraft,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: PrimaryButton(
                label: 'Upload',
                isLoading: false,
                onPressed: onUpload,
              ),
            ),
          ],
        ),
        SizedBox(height: 10.h),
        Text(
          'Upload puts the course in the marketplace now. A draft needs only '
          'a title: it is kept in your account, where only you can see it, '
          'until you finish and upload it.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 11.sp,
            color: AppColors.palette.inkSoft,
          ),
        ),
      ],
    );
  }
}
