import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:padi_learn/screens/components/course_thumbnail.dart';
import 'package:padi_learn/utils/colors.dart';

/// A row in the teacher's course list.
///
/// Deliberately has no Edit/Delete buttons: management actions live on the
/// course detail screen, where there is room to explain what they do. The card
/// is one big tap target that opens that screen.
class TeacherCourseCard extends StatelessWidget {
  final Map<String, dynamic> course;
  final VoidCallback onTap;

  const TeacherCourseCard({
    super.key,
    required this.course,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = (course['title'] ?? 'Untitled course').toString();
    final thumbnail = (course['thumbnail_url'] ?? '').toString();
    final price = (course['price'] as num?)?.toDouble() ?? 0;
    final students = (course['enrollments'] as num?)?.toInt() ?? 0;
    final ratingAvg = (course['rating_avg'] as num?)?.toDouble() ?? 0;
    final ratingCount = (course['rating_count'] as num?)?.toInt() ?? 0;
    final archived = course['archived_at'] != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(10.w),
        decoration: BoxDecoration(
          color: AppColors.appWhite,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            _thumbnail(thumbnail),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.richBlack,
                          ),
                        ),
                      ),
                      if (archived) ...[
                        SizedBox(width: 6.w),
                        const CourseStatusChip(archived: true),
                      ],
                    ],
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    price == 0 ? 'Free' : 'NGN ${price.toStringAsFixed(0)}',
                    style: GoogleFonts.poppins(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryColor,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      _stat(Icons.people_outline, '$students'),
                      SizedBox(width: 14.w),
                      _stat(
                        Icons.star_rounded,
                        ratingCount == 0
                            ? '—'
                            : '${ratingAvg.toStringAsFixed(1)} ($ratingCount)',
                        color: const Color(0xFFFFC107),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: AppColors.fontGrey, size: 22.sp),
          ],
        ),
      ),
    );
  }

  Widget _thumbnail(String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12.r),
      child: SizedBox(
        width: 84.w,
        height: 84.w,
        child: CourseThumbnail(url: url, iconSize: 24),
      ),
    );
  }

  Widget _stat(IconData icon, String value, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15.sp, color: color ?? AppColors.fontGrey),
        SizedBox(width: 4.w),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 11.5.sp,
            color: AppColors.fontGrey,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Small pill showing whether a course is live or archived.
class CourseStatusChip extends StatelessWidget {
  final bool archived;
  const CourseStatusChip({super.key, required this.archived});

  @override
  Widget build(BuildContext context) {
    final color = archived ? AppColors.fontGrey : AppColors.primaryColor;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(
        archived ? 'Archived' : 'Live',
        style: GoogleFonts.poppins(
          fontSize: 9.5.sp,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
