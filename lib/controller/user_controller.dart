import 'package:get/get.dart';
import 'package:padi_learn/services/supabase.dart';

class UserController extends GetxController {
  var userId = ''.obs;
  var userName = 'Loading...'.obs;
  var profileImageUrl = ''.obs;

  @override
  void onInit() {
    super.onInit();
    fetchUserInfo();
  }

  /// Loads the current user's profile (name + avatar) from Supabase.
  Future<void> fetchUserInfo() async {
    try {
      final user = supabase.auth.currentUser;
      userId.value = user?.id ?? '';

      if (userId.value.isEmpty) {
        userName.value = 'User not logged in';
        return;
      }

      final data = await supabase
          .from('profiles')
          .select('name, profile_image_url')
          .eq('id', userId.value)
          .maybeSingle();

      if (data != null) {
        userName.value = (data['name'] as String?) ?? 'Unknown Name';
        profileImageUrl.value = (data['profile_image_url'] as String?) ?? '';
      } else {
        userName.value = 'Profile not found';
      }
    } catch (e) {
      userName.value = 'Error loading name';
    }
  }
}
