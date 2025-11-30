import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:padi_learn/screens/description/components/author_tag.dart';
import 'package:padi_learn/screens/description/components/price_tag.dart';

class CourseHeader extends StatelessWidget {
  final String imageUrl;
  final String author;
  final bool isFree;
  final String price;

  const CourseHeader({
    Key? key,
    required this.imageUrl,
    required this.author,
    required this.isFree,
    required this.price,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SizedBox(height: 350.h, width: double.infinity),
        Container(
          height: 300.h,
          width: double.infinity,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: NetworkImage(imageUrl),
              fit: BoxFit.fill,
              filterQuality: FilterQuality.high,
            ),
            borderRadius: BorderRadius.circular(20.r),
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
              PriceTag(isFree: isFree, price: price),
            ],
          ),
        ),
      ],
    );
  }
}
