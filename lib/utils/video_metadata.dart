import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:video_player/video_player.dart';

import 'package:padi_learn/services/picked_file/picked_file.dart';

/// Reads a local clip's length so the curriculum can show runtimes.
///
/// Best-effort by design: a codec the platform can't open just means the lesson
/// has no duration, which the UI already handles. Never throws.
Future<int?> readVideoDurationSeconds(XFile file) async {
  VideoPlayerController? probe;
  try {
    probe = pickedVideoController(file);
    // The save button waits on this. A browser handed a file it cannot play
    // may report neither success nor failure, so the wait has to end.
    await probe.initialize().timeout(const Duration(seconds: 15));
    final seconds = probe.value.duration.inSeconds;
    return seconds > 0 ? seconds : null;
  } catch (e) {
    debugPrint('Could not read video duration: $e');
    return null;
  } finally {
    await probe?.dispose();
  }
}
