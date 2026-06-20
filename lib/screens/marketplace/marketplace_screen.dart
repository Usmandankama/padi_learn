import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:padi_learn/controller/course_controller.dart';
import 'package:padi_learn/controller/marketplace_controller.dart';
import 'package:padi_learn/screens/description/course_description_screen.dart';
import 'package:padi_learn/screens/marketplace/components/course_card.dart';
import 'package:padi_learn/utils/colors.dart';

/// Spacing scale used across the screen.
const double _kGap16 = 16;
const double _kGap24 = 24;

class MarketplaceScreen extends StatefulWidget {
  final String userRole;
  const MarketplaceScreen({super.key, required this.userRole});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  final MarketplaceController _controller = Get.find<MarketplaceController>();
  final TextEditingController _searchController = TextEditingController();

  static const List<String> _categories = [
    'All',
    'Programming',
    'Design',
    'Marketing',
    'Business',
    'Data Science',
  ];

  // Local (presentation-only) filter state.
  String _selectedCategory = 'All';
  RangeValues? _priceRange; // null = no price filter
  double _minRating = 0;
  String _sort = 'Latest'; // 'Latest' | 'Popular'

  bool _showShimmer = true;

  @override
  void initState() {
    super.initState();
    // Show the shimmer briefly; if no data arrives we fall through to the
    // empty state instead of spinning forever.
    Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _showShimmer = false);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int get _activeFilterCount {
    var count = 0;
    if (_selectedCategory != 'All') count++;
    if (_priceRange != null) count++;
    if (_minRating > 0) count++;
    if (_sort != 'Latest') count++;
    return count;
  }

  double _maxPriceBound(List<Map<String, dynamic>> courses) {
    var max = 0.0;
    for (final c in courses) {
      final p = (c['price'] as num?)?.toDouble() ?? 0;
      if (p > max) max = p;
    }
    return max < 1000 ? 1000 : (max / 1000).ceil() * 1000;
  }

  List<Map<String, dynamic>> _applyFilters(
      List<Map<String, dynamic>> courses) {
    final query = _searchController.text.trim().toLowerCase();

    final list = courses.where((c) {
      final title = (c['title'] ?? '').toString().toLowerCase();
      final matchesSearch = query.isEmpty || title.contains(query);
      final matchesCategory =
          _selectedCategory == 'All' || c['category'] == _selectedCategory;
      final price = (c['price'] as num?)?.toDouble() ?? 0;
      final matchesPrice = _priceRange == null ||
          (price >= _priceRange!.start && price <= _priceRange!.end);
      const rating = 4.5; // placeholder until ratings exist in the data
      final matchesRating = rating >= _minRating;
      return matchesSearch && matchesCategory && matchesPrice && matchesRating;
    }).toList();

    if (_sort == 'Popular') {
      list.sort((a, b) => ((b['enrollments'] as num?) ?? 0)
          .compareTo((a['enrollments'] as num?) ?? 0));
    } else {
      list.sort((a, b) => (b['created_at'] ?? '')
          .toString()
          .compareTo((a['created_at'] ?? '').toString()));
    }
    return list;
  }

  void _clearFilters() {
    setState(() {
      _selectedCategory = 'All';
      _priceRange = null;
      _minRating = 0;
      _sort = 'Latest';
      _searchController.clear();
    });
  }

  void _openCourse(Map<String, dynamic> course) {
    Get.find<CoursesController>().selectCourse(
      (course['id'] ?? '').toString(),
      (course['title'] ?? '').toString(),
      (course['thumbnail_url'] ?? '').toString(),
      (course['price'] as num?) ?? 0,
      (course['description'] ?? '').toString(),
      (course['author'] ?? '').toString(),
      (course['video_url'] ?? '').toString(),
    );
    Get.to(() => CourseDescriptionScreen());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F8FA),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          'Marketplace',
          style: GoogleFonts.poppins(
            color: AppColors.primaryColor,
            fontSize: 20.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          SizedBox(height: 12.h),
          _buildCategoryChips(),
          SizedBox(height: 8.h),
          Expanded(
            child: Obx(() {
              final all = _controller.courses.toList();

              if (all.isEmpty && _showShimmer) {
                return _buildGrid(
                  itemCount: 6,
                  builder: (_, __) => const CourseCardShimmer(),
                );
              }

              final filtered = _applyFilters(all);
              if (filtered.isEmpty) {
                return _buildEmptyState(hasCourses: all.isNotEmpty);
              }

              return _buildGrid(
                itemCount: filtered.length,
                builder: (_, i) {
                  final course = filtered[i];
                  return CourseCard(
                    course: course,
                    onTap: () => _openCourse(course),
                    onLongPress: () => _showQuickPreview(course),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Search + filters
  // ---------------------------------------------------------------------------

  Widget _buildSearchBar() {
    return Padding(
      padding: EdgeInsets.fromLTRB(_kGap16.w, 8.h, _kGap16.w, 0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.appWhite,
                borderRadius: BorderRadius.circular(14.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                style: GoogleFonts.poppins(fontSize: 13.sp),
                decoration: InputDecoration(
                  hintText: 'Search courses',
                  hintStyle: GoogleFonts.poppins(
                      fontSize: 13.sp, color: AppColors.fontGrey),
                  prefixIcon: const Icon(Icons.search,
                      color: AppColors.primaryColor),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: Icon(Icons.close,
                              size: 18.sp, color: AppColors.fontGrey),
                          onPressed: () =>
                              setState(() => _searchController.clear()),
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.r),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.symmetric(vertical: 14.h),
                ),
              ),
            ),
          ),
          SizedBox(width: 10.w),
          _buildFilterButton(),
        ],
      ),
    );
  }

  Widget _buildFilterButton() {
    final count = _activeFilterCount;
    return GestureDetector(
      onTap: _openFilterSheet,
      child: Container(
        height: 50.h,
        width: 50.h,
        decoration: BoxDecoration(
          color: AppColors.primaryColor,
          borderRadius: BorderRadius.circular(14.r),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryColor.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(Icons.tune, color: Colors.white),
            if (count > 0)
              Positioned(
                top: 8.h,
                right: 8.w,
                child: Container(
                  width: 16.w,
                  height: 16.w,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$count',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 8.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 38.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: _kGap16.w),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => SizedBox(width: 8.w),
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = _selectedCategory == category;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = category),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(horizontal: 18.w),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryColor : AppColors.appWhite,
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primaryColor
                      : Colors.black.withOpacity(0.08),
                ),
              ),
              child: Text(
                category,
                style: GoogleFonts.poppins(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.richBlack,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Grid + states
  // ---------------------------------------------------------------------------

  Widget _buildGrid({
    required int itemCount,
    required Widget Function(BuildContext, int) builder,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 1100 ? 4 : (width >= 720 ? 3 : 2);
        return GridView.builder(
          padding: EdgeInsets.fromLTRB(_kGap16.w, 12.h, _kGap16.w, _kGap24.h),
          itemCount: itemCount,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 14.w,
            mainAxisSpacing: 16.h,
            childAspectRatio: 0.68,
          ),
          itemBuilder: builder,
        );
      },
    );
  }

  Widget _buildEmptyState({required bool hasCourses}) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(_kGap24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 110.w,
              height: 110.w,
              decoration: const BoxDecoration(
                color: AppColors.primaryAccent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasCourses ? Icons.search_off_rounded : Icons.school_outlined,
                size: 52.sp,
                color: AppColors.primaryColor,
              ),
            ),
            SizedBox(height: _kGap24.h),
            Text(
              hasCourses ? 'No courses match your filters' : 'No courses yet',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.richBlack,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              hasCourses
                  ? 'Try adjusting your search or filters.'
                  : 'Check back soon for new courses.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13.sp,
                color: AppColors.fontGrey,
              ),
            ),
            if (hasCourses && _activeFilterCount > 0 ||
                _searchController.text.isNotEmpty) ...[
              SizedBox(height: _kGap16.h),
              TextButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.refresh, color: AppColors.primaryColor),
                label: Text(
                  'Clear filters',
                  style: GoogleFonts.poppins(
                    color: AppColors.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Filter sheet
  // ---------------------------------------------------------------------------

  void _openFilterSheet() {
    final maxPrice = _maxPriceBound(_controller.courses.toList());

    // Temp state local to the sheet; committed on "Apply".
    var tempCategory = _selectedCategory;
    var tempRange = _priceRange ?? RangeValues(0, maxPrice);
    var tempRating = _minRating;
    var tempSort = _sort;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.appWhite,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheet) {
            Widget sectionTitle(String text) => Padding(
                  padding: EdgeInsets.only(bottom: 10.h, top: _kGap16.h),
                  child: Text(
                    text,
                    style: GoogleFonts.poppins(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.richBlack,
                    ),
                  ),
                );

            Widget choice(String label, bool selected, VoidCallback onTap) =>
                GestureDetector(
                  onTap: onTap,
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primaryColor
                          : AppColors.appWhite,
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(
                        color: selected
                            ? AppColors.primaryColor
                            : Colors.black.withOpacity(0.12),
                      ),
                    ),
                    child: Text(
                      label,
                      style: GoogleFonts.poppins(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                        color: selected ? Colors.white : AppColors.richBlack,
                      ),
                    ),
                  ),
                );

            return Padding(
              padding: EdgeInsets.fromLTRB(_kGap24.w, 12.h, _kGap24.w,
                  MediaQuery.of(context).viewInsets.bottom + _kGap24.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filters',
                        style: GoogleFonts.poppins(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.richBlack,
                        ),
                      ),
                      TextButton(
                        onPressed: () => setSheet(() {
                          tempCategory = 'All';
                          tempRange = RangeValues(0, maxPrice);
                          tempRating = 0;
                          tempSort = 'Latest';
                        }),
                        child: Text(
                          'Clear all',
                          style: GoogleFonts.poppins(
                            color: AppColors.fontGrey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  sectionTitle('Category'),
                  Wrap(
                    spacing: 8.w,
                    runSpacing: 8.h,
                    children: _categories
                        .map((c) => choice(c, tempCategory == c,
                            () => setSheet(() => tempCategory = c)))
                        .toList(),
                  ),
                  sectionTitle('Price range (NGN)'),
                  RangeSlider(
                    values: tempRange,
                    min: 0,
                    max: maxPrice,
                    divisions: 20,
                    activeColor: AppColors.primaryColor,
                    inactiveColor: AppColors.primaryAccent,
                    labels: RangeLabels(
                      tempRange.start.toStringAsFixed(0),
                      tempRange.end.toStringAsFixed(0),
                    ),
                    onChanged: (v) => setSheet(() => tempRange = v),
                  ),
                  sectionTitle('Rating'),
                  Wrap(
                    spacing: 8.w,
                    runSpacing: 8.h,
                    children: [
                      choice('Any', tempRating == 0,
                          () => setSheet(() => tempRating = 0)),
                      choice('3.0+', tempRating == 3,
                          () => setSheet(() => tempRating = 3)),
                      choice('4.0+', tempRating == 4,
                          () => setSheet(() => tempRating = 4)),
                      choice('4.5+', tempRating == 4.5,
                          () => setSheet(() => tempRating = 4.5)),
                    ],
                  ),
                  sectionTitle('Sort by'),
                  Wrap(
                    spacing: 8.w,
                    runSpacing: 8.h,
                    children: [
                      choice('Latest', tempSort == 'Latest',
                          () => setSheet(() => tempSort = 'Latest')),
                      choice('Popular', tempSort == 'Popular',
                          () => setSheet(() => tempSort = 'Popular')),
                    ],
                  ),
                  SizedBox(height: _kGap24.h),
                  SizedBox(
                    width: double.infinity,
                    height: 52.h,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _selectedCategory = tempCategory;
                          _priceRange =
                              (tempRange.start == 0 && tempRange.end == maxPrice)
                                  ? null
                                  : tempRange;
                          _minRating = tempRating;
                          _sort = tempSort;
                        });
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                      ),
                      child: Text(
                        'Apply filters',
                        style: GoogleFonts.poppins(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Long-press quick preview
  // ---------------------------------------------------------------------------

  void _showQuickPreview(Map<String, dynamic> course) {
    final title = (course['title'] ?? 'Untitled course').toString();
    final author = (course['author'] ?? 'Unknown').toString();
    final description =
        (course['description'] ?? 'No description available.').toString();
    final thumbnail = (course['thumbnail_url'] ?? '').toString();
    final price = (course['price'] as num?) ?? 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.appWhite,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(_kGap24.w, 12.h, _kGap24.w, _kGap24.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                ),
              ),
              SizedBox(height: _kGap16.h),
              ClipRRect(
                borderRadius: BorderRadius.circular(16.r),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: thumbnail.isEmpty
                      ? Container(color: AppColors.primaryAccent)
                      : Image.network(
                          thumbnail,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Container(color: AppColors.primaryAccent),
                        ),
                ),
              ),
              SizedBox(height: _kGap16.h),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.richBlack,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                'By $author',
                style: GoogleFonts.poppins(
                  fontSize: 12.sp,
                  color: AppColors.fontGrey,
                ),
              ),
              SizedBox(height: 12.h),
              Row(
                children: [
                  Icon(Icons.star_rounded,
                      size: 16.sp, color: const Color(0xFFFFC107)),
                  SizedBox(width: 4.w),
                  Text('4.5',
                      style: GoogleFonts.poppins(
                          fontSize: 12.sp, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text(
                    formatPriceLabel(price),
                    style: GoogleFonts.poppins(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryColor,
                    ),
                  ),
                ],
              ),
              SizedBox(height: _kGap16.h),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: 140.h),
                child: SingleChildScrollView(
                  child: Text(
                    description,
                    style: GoogleFonts.poppins(
                      fontSize: 13.sp,
                      height: 1.5,
                      color: AppColors.fontGrey,
                    ),
                  ),
                ),
              ),
              SizedBox(height: _kGap24.h),
              SizedBox(
                width: double.infinity,
                height: 52.h,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _openCourse(course);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                  ),
                  child: Text(
                    'View course',
                    style: GoogleFonts.poppins(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
