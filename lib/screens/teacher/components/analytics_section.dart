import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:padi_learn/utils/colors.dart';
import 'analytics_item.dart'; // Import the AnalyticsItem widget

class AnalyticsSection extends StatelessWidget {
  const AnalyticsSection({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        AnalyticsItem(
          title: 'Total Earnings',
          value: '\$5000',
          icon: Icons.monetization_on,
        ),
        SizedBox(width: 10.w),
        AnalyticsItem(
          title: 'Courses Sold',
          value: '200',
          icon: Icons.school,
        ),
        SizedBox(width: 10.w),
        AnalyticsItem(
          title: 'Avg. Rating',
          value: '4.5/5',
          icon: Icons.star,
        ),
      ],
    );
  }
}
