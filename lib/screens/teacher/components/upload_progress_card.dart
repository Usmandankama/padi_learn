import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:padi_learn/services/supabase_storage_service.dart';
import 'package:padi_learn/utils/colors.dart';

/// Shown in place of the submit button while media is uploading.
///
/// Names the current step, shows a byte-accurate bar and an estimate, so a slow
/// upload reads as "still working" rather than "possibly hung".
class UploadProgressCard extends StatelessWidget {
  final UploadProgress? progress;

  const UploadProgressCard({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    // Subscribes to theme changes; without this the screen keeps
    // painting the previous theme's colours when the mode flips.
    AppColors.watch(context);
    final progress = this.progress;
    // Before the first chunk lands (and while the row is being written) there
    // is nothing meaningful to measure, so the bar runs indeterminate.
    final indeterminate = progress == null ||
        progress.stage == UploadStage.preparing ||
        progress.stage == UploadStage.saving;
    final remaining = progress?.remainingLabel;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.palette.hairline,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 16.w,
                height: 16.w,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  (progress?.stage ?? UploadStage.preparing).label,
                  style: TextStyle(
                    color: AppColors.primaryColor,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (!indeterminate)
                Text(
                  '${progress.percent}%',
                  style: TextStyle(
                    color: AppColors.primaryColor,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          SizedBox(height: 12.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(4.r),
            child: LinearProgressIndicator(
              value: indeterminate ? null : progress.fraction,
              minHeight: 6.h,
              backgroundColor: AppColors.palette.surface,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            [
              if (progress != null && !indeterminate) progress.sizeLabel,
              if (remaining != null) remaining,
            ].join(' · '),
            style: TextStyle(color: AppColors.palette.inkSoft, fontSize: 12.sp),
          ),
          SizedBox(height: 4.h),
          Text(
            'Keep this screen open until the upload finishes.',
            style: TextStyle(color: AppColors.palette.inkSoft, fontSize: 11.sp),
          ),
        ],
      ),
    );
  }
}
