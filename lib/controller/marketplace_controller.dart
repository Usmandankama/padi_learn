import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

class MarketplaceController extends GetxController {
  var courses = <QueryDocumentSnapshot>[].obs;  // Observable list of courses
  var searchQuery = ''.obs;
  var selectedFilter = 'All'.obs;

  @override
  void onInit() {
    super.onInit();
    fetchAllCourses();
  }

  Future<void> fetchAllCourses() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance.collection('courses').get();
      courses.assignAll(querySnapshot.docs); // Assign fetched courses to observable list
    } catch (e) {
      print('Error fetching courses: $e');
    }
  }

  List<QueryDocumentSnapshot> filterCourses() {
    return courses.where((course) {
      final courseData = course.data() as Map<String, dynamic>;
      final title = courseData['title'].toString().toLowerCase();
      return title.contains(searchQuery.value.toLowerCase()) &&
          (selectedFilter.value == 'All' || courseData['category'] == selectedFilter.value);
    }).toList();
  }
}
