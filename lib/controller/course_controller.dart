import 'package:get/get.dart';

/// Carries the course the user tapped from a list to the description screen.
///
/// It used to also hold its own `courses` list, filled by a `select()` over
/// the whole `courses` table on every app start. Nothing ever read it —
/// `MarketplaceController` owns the catalogue, and both the marketplace and
/// the student dashboard read it from there — so that was a full-table fetch,
/// every column including descriptions, thrown away each launch.
class CoursesController extends GetxController {
  var selectedCourseId = ''.obs;
  var selectedCourseTitle = ''.obs;
  var selectedCourseImage = ''.obs;
  var selectedCoursePrice = 0.0.obs; // numeric price (0 == free)
  var selectedCourseDescription = ''.obs;
  var selectedCourseAuthor = ''.obs;

  /// Stores the tapped course's details for the description screen.
  ///
  /// No video here: a course is a list of lessons now, and the description
  /// screen loads those itself.
  void selectCourse(String id, String title, String image, num price,
      String description, String author) {
    selectedCourseId.value = id;
    selectedCourseTitle.value = title;
    selectedCourseImage.value = image;
    selectedCoursePrice.value = price.toDouble();
    selectedCourseAuthor.value = author;
    selectedCourseDescription.value = description;
  }
}
