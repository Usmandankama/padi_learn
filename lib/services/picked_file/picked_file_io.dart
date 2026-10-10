import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:video_player/video_player.dart';

import 'picked_file.dart' show ObjectUploadInterrupted, ObjectUploadResponse;

/// Mobile: the file is a path on disk, so the multipart body is streamed from
/// it rather than buffered, and counted as it leaves.
Future<ObjectUploadResponse> putPickedFile({
  required Uri uri,
  required XFile file,
  required String filename,
  required String contentType,
  required void Function(int deltaBytes) onBytes,
}) async {
  http.Client? httpClient;
  try {
    final multipart = http.MultipartRequest('PUT', uri)
      ..fields['cacheControl'] = '3600'
      ..headers['x-upsert'] = 'false'
      ..files.add(await http.MultipartFile.fromPath(
        '',
        file.path,
        filename: filename,
        contentType: MediaType.parse(contentType),
      ));

    // finalize() returns the body stream and stamps the multipart boundary
    // onto the request headers.
    final body = multipart.finalize();
    final contentLength = multipart.contentLength;

    final counted = body.map((chunk) {
      onBytes(chunk.length);
      return chunk;
    });

    final request = _StreamedBodyRequest('PUT', uri, counted, contentLength)
      ..headers.addAll(multipart.headers);

    httpClient = http.Client();
    final response = await httpClient.send(request);
    return ObjectUploadResponse(
      response.statusCode,
      await response.stream.bytesToString(),
    );
  } on SocketException {
    throw const ObjectUploadInterrupted();
  } on http.ClientException catch (e) {
    throw ObjectUploadInterrupted(e.message);
  } finally {
    httpClient?.close();
  }
}

/// A request whose body is an already-prepared byte stream.
///
/// Lets the multipart body be piped through a counter without buffering it,
/// while `http` still applies backpressure from the socket — so the progress
/// figure tracks bytes actually sent rather than bytes queued in memory.
class _StreamedBodyRequest extends http.BaseRequest {
  final Stream<List<int>> _body;

  _StreamedBodyRequest(
    String method,
    Uri url,
    this._body,
    int length,
  ) : super(method, url) {
    contentLength = length;
  }

  @override
  http.ByteStream finalize() {
    super.finalize();
    return http.ByteStream(_body);
  }
}

ImageProvider pickedImageProvider(XFile file) => FileImage(File(file.path));

VideoPlayerController pickedVideoController(XFile file) =>
    VideoPlayerController.file(File(file.path));
