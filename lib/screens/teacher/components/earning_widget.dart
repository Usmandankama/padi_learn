import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:padi_learn/utils/colors.dart';

import 'analytic_item.dart';

class EarningsWidget extends StatefulWidget {
  const EarningsWidget({super.key});

  @override
  State<EarningsWidget> createState() => _EarningsWidgetState();
}

class _EarningsWidgetState extends State<EarningsWidget> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Store the fetched data
  int totalEarnings = 0;
  int coursesSold = 0;

  @override
  void initState() {
    super.initState();
    _fetchEarningsAndCourses();
  }

  // Method to fetch earnings and courses data from Firestore
  Future<void> _fetchEarningsAndCourses() async {
    try {
      final docSnapshot =
          await _firestore.collection('teachers').doc('teacherId').get();

      if (docSnapshot.exists) {
        setState(() {
          totalEarnings = docSnapshot.data()?['totalEarnings'] ?? 0;
          coursesSold = docSnapshot.data()?['coursesSold'] ?? 0;
        });
      }
    } catch (e) {
      print('Error fetching earnings and courses data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        const SizedBox(height: 25),
        Container(
          height: 150.h,
          width: 500.w,
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
          decoration: const BoxDecoration(
            color: AppColors.primaryColor,
            borderRadius: BorderRadius.all(
              Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, 2),
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Earnings',
                style: TextStyle(
                  color: AppColors.appWhite,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '\$$totalEarnings',
                style: TextStyle(
                  color: AppColors.appWhite,
                  fontSize: 35.sp,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            AnalyticItem(
              title: 'Enrollments',
              statsData: totalEarnings,
            ),
            SizedBox(width: 5.w),
            AnalyticItem(
              title: 'Courses Sold',
              statsData: coursesSold,
            ),
            SizedBox(width: 5.w),
          ],
        ),
      ],
    );
  }
}
