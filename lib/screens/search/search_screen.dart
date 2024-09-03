import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:padi_learn/utils/colors.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appWhite,
      appBar: AppBar(
        title: Text(
          'Search',
          style: TextStyle(
            color: AppColors.primaryColor,
            fontSize: 22.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.appWhite,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.primaryColor),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildSearchBar(),
            SizedBox(height: 20.h),
            _buildSearchResultsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      onSubmitted: (query) {
        // Handle search logic here
      },
      decoration: InputDecoration(
        prefixIcon: Icon(Icons.search, color: AppColors.primaryColor),
        hintText: 'Search for courses...',
        hintStyle: TextStyle(color: AppColors.primaryColor.withOpacity(0.7)),
        filled: true,
        fillColor: AppColors.primaryColor.withOpacity(0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0.r),
          borderSide: BorderSide.none,
        ),
        contentPadding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 16.w),
      ),
    );
  }

  Widget _buildSearchResultsSection() {
    return Expanded(
      child: ListView.builder(
        itemCount: 10, // Replace with your dynamic item count
        itemBuilder: (context, index) {
          return _buildSearchResultItem();
        },
      ),
    );
  }

  Widget _buildSearchResultItem() {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Row(
        children: <Widget>[
          Container(
            height: 80.h,
            width: 80.h,
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Center(
              child: Text(
                'Image', // Placeholder for course image
                style: TextStyle(
                  color: AppColors.primaryColor,
                  fontSize: 14.sp,
                ),
              ),
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Course Title', // Placeholder for course title
                  style: TextStyle(
                    color: AppColors.primaryColor,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 5.h),
                Text(
                  'Instructor Name', // Placeholder for instructor name
                  style: TextStyle(
                    color: AppColors.primaryColor.withOpacity(0.7),
                    fontSize: 14.sp,
                  ),
                ),
                SizedBox(height: 10.h),
                Text(
                  '\$49.99', // Placeholder for course price
                  style: TextStyle(
                    color: AppColors.primaryColor,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
