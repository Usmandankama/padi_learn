import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:padi_learn/screens/teacher/components/courseList.dart';
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

    // Categories for the filter
    final List<String> categories = ['All', 'Programming', 'Design', 'Marketing', 'Business'];

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
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(15),
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
          // Horizontal ListView for category selection
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: SizedBox(
              height: 50.h, // Adjust the height as necessary
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  String category = categories[index];
                  bool isSelected = controller.selectedFilter.value == category;
                    
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        controller.selectedFilter.value = category; // Update selected category
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 5.0),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primaryColor : Colors.grey[300],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Text(
                          category,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          // Display the courses in a GridView
          SizedBox(
            // height: 500.h,
            child: controller.courses.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : Builder(builder: (context) {
                    // Apply search and filter
                    final filteredCourses = controller.filterCourses();
                    
                    if (filteredCourses.isEmpty) {
                      return const Center(child: Text('No courses available'));
                    }
                    
                    return Padding(
                      padding: const EdgeInsets.all(15),
                      child: TeacherCourseList(courses: filteredCourses, onEdit: (String ) {  }, onDelete: (String ) {  },));
                  }),
          ),
        ],
      ),
    );
  }
}
