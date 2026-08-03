import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

/// Reads a local clip's length so the curriculum can show runtimes.
///
/// Best-effort by design: a codec the platform can't open just means the lesson
/// has no duration, which the UI already handles. Never throws.
Future<int?> readVideoDurationSeconds(File file) async {
  VideoPlayerController? probe;
  try {
    probe = VideoPlayerController.file(file);
    await probe.initialize();
    final seconds = probe.value.duration.inSeconds;
    return seconds > 0 ? seconds : null;
  } catch (e) {
    debugPrint('Could not read video duration: $e');
    return null;
  } finally {
    await probe?.dispose();
  }
}
