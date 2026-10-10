import 'package:flutter/painting.dart' show ImageProvider;
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:video_player/video_player.dart';

import 'picked_file_io.dart'
    if (dart.library.js_interop) 'picked_file_web.dart' as impl;

// What a picked file *is* differs by platform. On a phone it is a path on
// disk, which `dart:io` can open. In a browser it is a `blob:` URL the page
// was handed by the file dialog, and `dart:io` throws on every call — that is
// what broke uploading on the web until 10 October 2026. Screens and services
// therefore hold the picker's own `XFile` and come here for anything that
// needs the bytes, rather than building a `File` from its path.

/// What the storage server answered to an upload.
class ObjectUploadResponse {
  final int statusCode;
  final String body;
  const ObjectUploadResponse(this.statusCode, this.body);
}

/// The connection failed before the server answered.
class ObjectUploadInterrupted implements Exception {
  /// What the platform said went wrong, or null when all it reported was that
  /// the network dropped. A browser never says more than that.
  final String? detail;
  const ObjectUploadInterrupted([this.detail]);

  @override
  String toString() => 'ObjectUploadInterrupted(${detail ?? 'network dropped'})';
}

/// Sends [file] to a Supabase Storage signed-upload [uri] as the multipart
/// body that endpoint expects, calling [onBytes] with the size of each chunk
/// as it goes onto the wire.
///
/// Neither platform loads the file into memory: mobile streams it from disk,
/// the browser is handed the file itself and reads it as it sends.
///
/// Throws [ObjectUploadInterrupted] when the connection fails. An answer from
/// the server, good or bad, is returned rather than thrown.
Future<ObjectUploadResponse> putPickedFile({
  required Uri uri,
  required XFile file,
  required String filename,
  required String contentType,
  required void Function(int deltaBytes) onBytes,
}) =>
    impl.putPickedFile(
      uri: uri,
      file: file,
      filename: filename,
      contentType: contentType,
      onBytes: onBytes,
    );

/// Draws a picked image before it has been uploaded anywhere.
ImageProvider pickedImageProvider(XFile file) =>
    impl.pickedImageProvider(file);

/// Opens a picked video where it sits, without uploading it.
VideoPlayerController pickedVideoController(XFile file) =>
    impl.pickedVideoController(file);
