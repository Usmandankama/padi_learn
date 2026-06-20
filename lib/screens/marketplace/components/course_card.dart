import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:padi_learn/utils/colors.dart';

/// Compact count formatter (e.g. 1200 -> "1.2k").
String formatStudentCount(num value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
  return value.toStringAsFixed(0);
}

/// Price label ("Free" or "NGN 5000").
String formatPriceLabel(num price) =>
    price <= 0 ? 'Free' : 'NGN ${price.toStringAsFixed(0)}';

/// A modern, tappable course card with thumbnail, category tag, rating,
/// instructor, student count and price. Scales up on hover (web/desktop) and
/// dips on press (mobile) for tactile feedback.
class CourseCard extends StatefulWidget {
  final Map<String, dynamic> course;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final double rating;

  const CourseCard({
    super.key,
    required this.course,
    required this.onTap,
    this.onLongPress,
    this.rating = 4.5,
  });

  @override
  State<CourseCard> createState() => _CourseCardState();
}

class _CourseCardState extends State<CourseCard> {
  bool _hovered = false;
  bool _pressed = false;

  double get _scale => _pressed ? 0.97 : (_hovered ? 1.03 : 1.0);

  @override
  Widget build(BuildContext context) {
    final course = widget.course;
    final title = (course['title'] ?? 'Untitled course').toString();
    final author = (course['author'] ?? 'Unknown').toString();
    final category = (course['category'] ?? '').toString();
    final thumbnail = (course['thumbnail_url'] ?? '').toString();
    final price = (course['price'] as num?) ?? 0;
    final students = (course['enrollments'] as num?) ?? 0;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _scale,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: AppColors.appWhite,
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(color: Colors.black.withOpacity(0.04)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(_hovered ? 0.14 : 0.07),
                  blurRadius: _hovered ? 22 : 14,
                  offset: Offset(0, _hovered ? 10 : 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 11,
                    child: _Thumbnail(
                      url: thumbnail,
                      category: category,
                      rating: widget.rating,
                    ),
                  ),
                  Expanded(
                    flex: 10,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 12.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 13.5.sp,
                              height: 1.25,
                              fontWeight: FontWeight.w600,
                              color: AppColors.richBlack,
                            ),
                          ),
                          Row(
                            children: [
                              _InitialsAvatar(name: author),
                              SizedBox(width: 6.w),
                              Expanded(
                                child: Text(
                                  author,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    fontSize: 11.sp,
                                    color: AppColors.fontGrey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.people_alt_outlined,
                                      size: 14.sp, color: AppColors.fontGrey),
                                  SizedBox(width: 3.w),
                                  Text(
                                    formatStudentCount(students),
                                    style: GoogleFonts.poppins(
                                      fontSize: 11.sp,
                                      color: AppColors.fontGrey,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                formatPriceLabel(price),
                                style: GoogleFonts.poppins(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final String url;
  final String category;
  final double rating;

  const _Thumbnail({
    required this.url,
    required this.category,
    required this.rating,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        url.isEmpty
            ? _placeholder()
            : Image.network(
                url,
                fit: BoxFit.cover,
                loadingBuilder: (c, child, progress) =>
                    progress == null ? child : _placeholder(),
                errorBuilder: (c, e, s) => _placeholder(),
              ),
        // Bottom gradient overlay for legibility of the rating pill.
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.45)],
                stops: const [0.55, 1.0],
              ),
            ),
          ),
        ),
        if (category.isNotEmpty)
          Positioned(
            top: 10.h,
            left: 10.w,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.88),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Text(
                category,
                style: GoogleFonts.poppins(
                  fontSize: 9.5.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryColor,
                ),
              ),
            ),
          ),
        Positioned(
          bottom: 10.h,
          left: 10.w,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.55),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star_rounded,
                    size: 13.sp, color: const Color(0xFFFFC107)),
                SizedBox(width: 3.w),
                Text(
                  rating.toStringAsFixed(1),
                  style: GoogleFonts.poppins(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _placeholder() => Container(
        color: AppColors.primaryAccent,
        child: Icon(Icons.play_circle_outline,
            color: AppColors.primaryColor, size: 34.sp),
      );
}

class _InitialsAvatar extends StatelessWidget {
  final String name;
  const _InitialsAvatar({required this.name});

  String get _initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22.w,
      height: 22.w,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.primaryAccent,
        shape: BoxShape.circle,
      ),
      child: Text(
        _initials,
        style: GoogleFonts.poppins(
          fontSize: 9.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryColor,
        ),
      ),
    );
  }
}

/// Animated placeholder shown in the grid while courses load.
class CourseCardShimmer extends StatefulWidget {
  const CourseCardShimmer({super.key});

  @override
  State<CourseCardShimmer> createState() => _CourseCardShimmerState();
}

class _CourseCardShimmerState extends State<CourseCardShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.appWhite,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 11, child: _bar(double.infinity, double.infinity)),
            Expanded(
              flex: 10,
              child: Padding(
                padding: EdgeInsets.all(12.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _bar(double.infinity, 12.h),
                    _bar(90.w, 10.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [_bar(40.w, 10.h), _bar(50.w, 10.h)],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bar(double width, double height) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final dx = (_controller.value * 3) - 1.5;
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6.r),
            gradient: LinearGradient(
              begin: Alignment(dx - 0.5, 0),
              end: Alignment(dx + 0.5, 0),
              colors: const [
                Color(0xFFECECEC),
                Color(0xFFF7F7F7),
                Color(0xFFECECEC),
              ],
            ),
          ),
        );
      },
    );
  }
}
