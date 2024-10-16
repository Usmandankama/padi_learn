import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../controller/marketplace_controller.dart';
import '../../utils/colors.dart';
import 'components/courseGrid.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  @override
  Widget build(BuildContext context) {
    final MarketplaceController controller = Get.find<MarketplaceController>();

    return Scaffold(
      backgroundColor: AppColors.appWhite,
      appBar: AppBar(
        backgroundColor: AppColors.appWhite,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          "Marketplace",
          style: TextStyle(
            color: AppColors.primaryColor,
            fontSize: 22.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            // Search Field without Obx, using setState instead for updates
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search courses',
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColors.primaryColor,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: BorderSide(
                      color: AppColors.primaryColor,
                      width: 2.w,
                    ),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    controller.searchQuery.value = value; // Update search query
                  });
                },
              ),
            ),
            // Filter Bar for category selection without Obx
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    // Dropdown filter for category without Obx
                    DropdownButton<String>(
                      value: controller.selectedFilter.value,
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            controller.selectedFilter.value =
                                newValue; // Update selected filter
                          });
                        }
                      },
                      items: <String>[
                        'All',
                        'Programming',
                        'Design',
                        'Marketing'
                      ].map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                    ),
                  ],
                )),

            // Display the courses in a GridView without Obx
            SizedBox(
              height: 500.h,
              child: controller.courses.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : Builder(builder: (context) {
                      // Apply search and filter
                      final filteredCourses = controller.filterCourses();

                      if (filteredCourses.isEmpty) {
                        return const Center(
                            child: Text('No courses available'));
                      }

                      return CoursesGrid(courses: filteredCourses);
                    }),
            ),
          ],
        ),
      ),
    );
  }
}
