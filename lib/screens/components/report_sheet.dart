import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:padi_learn/screens/components/primary_button.dart';
import 'package:padi_learn/services/report_service.dart';
import 'package:padi_learn/utils/colors.dart';

/// Asks why a course or comment is being reported, then files the report.
///
/// Pass exactly one of [courseId] or [commentId]. The outcome is shown as a
/// snackbar here, so callers only need to open the sheet.
Future<void> showReportSheet(
  BuildContext context, {
  String? courseId,
  String? commentId,
}) {
  assert((courseId == null) != (commentId == null),
      'Report exactly one of a course or a comment');

  final messenger = ScaffoldMessenger.of(context);

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.palette.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
    ),
    builder: (_) => _ReportSheet(
      courseId: courseId,
      commentId: commentId,
      messenger: messenger,
    ),
  );
}

class _ReportSheet extends StatefulWidget {
  final String? courseId;
  final String? commentId;

  /// Captured from the opening screen: the sheet's own context is gone by the
  /// time the result comes back and it has closed.
  final ScaffoldMessengerState messenger;

  const _ReportSheet({
    required this.courseId,
    required this.commentId,
    required this.messenger,
  });

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  final _details = TextEditingController();
  ReportReason? _reason;
  bool _sending = false;

  String get _subject => widget.courseId != null ? 'course' : 'comment';

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null || _sending) return;
    setState(() => _sending = true);

    String message;
    try {
      final outcome = widget.courseId != null
          ? await ReportService.reportCourse(widget.courseId!, reason,
              details: _details.text)
          : await ReportService.reportComment(widget.commentId!, reason,
              details: _details.text);
      message = outcome == ReportOutcome.alreadyReported
          ? "You've already reported this $_subject. We're looking into it."
          : "Thanks. We'll review this $_subject.";
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      widget.messenger.showSnackBar(
        const SnackBar(
            content: Text('Could not send the report. Please try again.')),
      );
      return;
    }

    if (mounted) Navigator.pop(context);
    widget.messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    // Subscribes to theme changes; without this the screen keeps
    // painting the previous theme's colours when the mode flips.
    AppColors.watch(context);
    final media = MediaQuery.of(context);

    return Padding(
      // viewInsets keeps the details field above the keyboard; padding keeps
      // the button above the device's navigation bar.
      padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w,
          media.viewInsets.bottom + media.padding.bottom + 24.h),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: AppColors.palette.hairline,
                  borderRadius: BorderRadius.circular(4.r),
                ),
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              'Report $_subject',
              style: GoogleFonts.poppins(
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.palette.ink,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              "Tell us what's wrong. Whoever posted it won't see that you "
              'reported it.',
              style: GoogleFonts.poppins(
                fontSize: 12.sp,
                color: AppColors.palette.inkSoft,
              ),
            ),
            SizedBox(height: 8.h),
            RadioGroup<ReportReason>(
              groupValue: _reason,
              onChanged: (value) => setState(() => _reason = value),
              child: Column(
                children: [
                  for (final reason in ReportReason.values)
                    RadioListTile<ReportReason>(
                      value: reason,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppColors.primaryColor,
                      title: Text(
                        reason.label,
                        style: GoogleFonts.poppins(
                          fontSize: 13.sp,
                          color: AppColors.palette.ink,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: 8.h),
            TextField(
              controller: _details,
              maxLength: 1000,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Anything else we should know? (optional)',
              ),
            ),
            SizedBox(height: 12.h),
            PrimaryButton(
              label: 'Send report',
              isLoading: _sending,
              onPressed: _reason == null ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
