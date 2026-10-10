import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/painting.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:video_player/video_player.dart';
import 'package:web/web.dart' as web;

import 'picked_file.dart' show ObjectUploadInterrupted, ObjectUploadResponse;

/// Web: the file is a `blob:` URL. The browser is given the blob behind it and
/// reads the file from disk as it sends, so a 300 MB lesson never sits in the
/// page's memory.
///
/// `XMLHttpRequest` rather than `package:http`: on the web that package reads
/// the whole body into memory before sending and reports nothing while it
/// goes, and `XFile.openRead()` does the same. XHR is the one browser API that
/// reports upload progress.
Future<ObjectUploadResponse> putPickedFile({
  required Uri uri,
  required XFile file,
  required String filename,
  required String contentType,
  required void Function(int deltaBytes) onBytes,
}) async {
  final web.Blob blob;
  try {
    final fetched = await web.window.fetch(file.path.toJS).toDart;
    blob = await fetched.blob().toDart;
  } catch (_) {
    throw const ObjectUploadInterrupted(
        'the file could not be read. Please choose it again.');
  }

  // Storage checks the part's type against the bucket's allowed types, and
  // the type a browser guessed for the file can be empty, so it is set here.
  final part = blob.slice(0, blob.size, contentType);

  // The same body the mobile upload builds, and supabase-js too.
  final form = web.FormData()
    ..append('cacheControl', '3600'.toJS)
    ..append('', part, filename);

  final xhr = web.XMLHttpRequest()..open('PUT', uri.toString());
  xhr.setRequestHeader('x-upsert', 'false');

  final done = Completer<ObjectUploadResponse>();

  // `loaded` is a running total; the caller wants the size of each step.
  var reported = 0;
  web.EventStreamProviders.progressEvent.forTarget(xhr.upload).listen((event) {
    final loaded = event.loaded;
    if (loaded > reported) {
      onBytes(loaded - reported);
      reported = loaded;
    }
  });

  xhr.onLoad.listen((_) {
    if (!done.isCompleted) {
      done.complete(ObjectUploadResponse(xhr.status, xhr.responseText));
    }
  });
  // `loadend` follows a failure of any kind (error, abort, timeout), and a
  // browser gives no reason for one. It also follows `load`, by which time
  // the answer is already in.
  web.EventStreamProviders.loadEndEvent.forTarget(xhr).listen((_) {
    if (!done.isCompleted) {
      done.completeError(const ObjectUploadInterrupted());
    }
  });

  xhr.send(form);
  return done.future;
}

/// A `blob:` URL loads like any other URL.
ImageProvider pickedImageProvider(XFile file) => NetworkImage(file.path);

VideoPlayerController pickedVideoController(XFile file) =>
    VideoPlayerController.networkUrl(Uri.parse(file.path));
