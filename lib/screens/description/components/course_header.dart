import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:padi_learn/screens/components/course_thumbnail.dart';
import 'package:padi_learn/screens/description/components/author_tag.dart';
import 'package:padi_learn/screens/description/components/price_tag.dart';

class CourseHeader extends StatelessWidget {
  final String imageUrl;
  final String author;
  final num price;
  final bool isOwned;

  const CourseHeader({
    super.key,
    required this.imageUrl,
    required this.author,
    required this.price,
    this.isOwned = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SizedBox(height: 350.h, width: double.infinity),
        // ClipRRect + CourseThumbnail rather than a DecorationImage: the
        // decoration form has no error path, so a cover that fails to load left
        // this — the student's buying page — with a blank box.
        ClipRRect(
          borderRadius: BorderRadius.circular(20.r),
          child: SizedBox(
            height: 300.h,
            width: double.infinity,
            child: CourseThumbnail(url: imageUrl, iconSize: 48),
          ),
        ),
        Positioned(
          top: 270.h,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AuthorTag(authorName: author),
              PriceTag(price: price, isOwned: isOwned),
            ],
          ),
        ),
      ],
    );
  }
}
