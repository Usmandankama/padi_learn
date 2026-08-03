import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:padi_learn/services/supabase_storage_service.dart';
import 'package:padi_learn/utils/colors.dart';

/// Renders a course cover image, degrading to a branded placeholder.
///
/// Every list, card and header shows the same `courses.thumbnail_url`, so the
/// handling lives in one place rather than being hand-rolled at each site.
///
/// It also short-circuits *known-dead* links: covers uploaded before the
/// storage split point at `/object/public/course-media/…`, and that bucket is
/// private now, so the public endpoint answers 400. Detecting the shape locally
/// avoids a pointless round-trip and the error it logs.
class CourseThumbnail extends StatelessWidget {
  final String? url;
  final BoxFit fit;

  /// Icon size for the placeholder; scale it down inside small cards.
  final double iconSize;

  const CourseThumbnail({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.iconSize = 26,
  });

  /// True when [url] points into the now-private course-media bucket via the
  /// public object endpoint — a link that can no longer resolve.
  static bool isDeadLegacyUrl(String url) =>
      url.contains('/storage/v1/object/public/$kCourseMediaBucket/');

  @override
  Widget build(BuildContext context) {
    final url = this.url?.trim() ?? '';
    if (url.isEmpty || isDeadLegacyUrl(url)) return _placeholder();

    return Image.network(
      url,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => _placeholder(),
    );
  }

  Widget _placeholder() {
    return Container(
      color: AppColors.primaryAccent,
      alignment: Alignment.center,
      child: Icon(
        Icons.play_circle_outline,
        size: iconSize.sp,
        color: AppColors.primaryColor,
      ),
    );
  }
}
