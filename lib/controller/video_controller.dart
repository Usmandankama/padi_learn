// import 'package:get/get.dart';
// import 'package:video_player/video_player.dart';

// class VideoPlayerController extends GetxController {
//   late VideoPlayerController videoController;
//   RxBool isLoading = true.obs;
//   RxBool isPlaying = false.obs;
//   RxList<Map<String, String>> recommendedVideos = <Map<String, String>>[].obs;

//   void initializePlayer(String videoUrl) {
//     videoController = VideoPlayerController.network(videoUrl)
//       ..initialize().then((_) {
//         isLoading.value = false;
//         videoController.play();
//         isPlaying.value = true;
//       });
//   }

//   void togglePlayPause() {
//     if (videoController.value.isPlaying) {
//       videoController.pause();
//       isPlaying.value = false;
//     } else {
//       videoController.play();
//       isPlaying.value = true;
//     }
//   }

//   @override
//   void onClose() {
//     videoController.dispose();
//     super.onClose();
//   }
// }
