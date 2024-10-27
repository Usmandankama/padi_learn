import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

class UserController extends GetxController {
  var userId = ''.obs; // Added observable for userId
  var userName = 'Loading...'.obs;
  var profileImageUrl = "https://via.placeholder.com/150".obs;
  
  // Firebase Instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void onInit() {
    super.onInit();
    fetchUserInfo();
  }

  // Get current user from Firebase Auth
  Future<void> fetchUserInfo() async {
    try {
      // Set userId from the current authenticated user
      userId.value = _auth.currentUser?.uid ?? '';

      if (userId.value.isEmpty) {
        userName.value = 'User not logged in';
        return;
      }

      final userDoc = await _firestore.collection('users').doc(userId.value).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        if (data != null && data.containsKey('name')) {
          userName.value = data['name'] ?? 'Unknown Name';
          profileImageUrl.value =
              data['profileImageUrl'] ?? profileImageUrl.value;
        } else {
          userName.value = 'Name field missing';
        }
      } else {
        userName.value = 'User document not found';
      }
    } catch (e) {
      userName.value = 'Error loading name';
      print('Error fetching user info: $e');
    }
  }
}
