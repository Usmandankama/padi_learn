import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

class TeacherController extends GetxController {
  // Observable variables
  var teacherName = 'Loading...'.obs;
  var profileImageUrl = "https://via.placeholder.com/150".obs;
  var totalCoursesUploaded = 0.obs;
  var totalEarnings = 0.0.obs;
  var userCourses = <QueryDocumentSnapshot>[].obs;

  // Firebase Instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void onInit() {
    super.onInit();
    fetchTeacherInfo(); // Fetch teacher's info on controller init
    fetchTeacherEarningsAndCourses(); // Fetch teacher earnings and course count
    fetchUserCourses(); // Fetch user courses
  }

  // Function to fetch teacher info from Firebase
  Future<void> fetchTeacherInfo() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        teacherName.value = 'User not logged in';
        return;
      }

      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        if (data != null && data.containsKey('name')) {
          teacherName.value = data['name'] ?? 'Unknown Name';
          profileImageUrl.value = data['profileImageUrl'] ?? profileImageUrl.value;
        } else {
          teacherName.value = 'Name field missing';
        }
      } else {
        teacherName.value = 'User document not found';
      }
    } catch (e) {
      teacherName.value = 'Error loading name';
      print('Error fetching teacher info: $e');
    }
  }

  // Function to fetch teacher earnings and courses
  Future<void> fetchTeacherEarningsAndCourses() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      // Fetch teacher's courses
      final querySnapshot = await _firestore
          .collection('courses')
          .where('userId', isEqualTo: userId)
          .get();

      int coursesCount = querySnapshot.docs.length;
      double earnings = 0.0;

      for (var courseDoc in querySnapshot.docs) {
        final courseData = courseDoc.data();
        if (courseData.containsKey('price') &&
            courseData.containsKey('enrollments')) {
          final double price = courseData['price'] ?? 0.0;
          final int enrollments = courseData['enrollments'] ?? 0;
          earnings += price * enrollments;
        }
      }

      totalCoursesUploaded.value = coursesCount;
      totalEarnings.value = earnings;
    } catch (e) {
      print('Error fetching teacher earnings and courses: $e');
    }
  }

  // Function to fetch user courses
  Future<void> fetchUserCourses() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final querySnapshot = await _firestore
          .collection('courses')
          .where('userId', isEqualTo: userId)
          .get();

      userCourses.value = querySnapshot.docs;
    } catch (e) {
      print('Error fetching user courses: $e');
    }
  }

  // Stream for courses (to be used in the UI with StreamBuilder if needed)
  Stream<QuerySnapshot> courseStream() {
    final userId = _auth.currentUser?.uid;
    return _firestore
        .collection('courses')
        .where('userId', isEqualTo: userId)
        .snapshots();
  }
}
