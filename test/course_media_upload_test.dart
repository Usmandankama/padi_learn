// Course media is uploaded from the picker's own `XFile`, because a browser
// has no file path to open (see lib/services/picked_file). These run the phone
// half of that against a real local server standing in for Supabase Storage:
// the part of the upload that cannot be tried without a device. The browser
// half cannot run here at all; it was checked in Chrome, as the 10 October
// 2026 entry in docs/DEVLOG.md describes.
//
// No Flutter binding is started on purpose: the test binding replaces the
// HTTP client with one that answers 400 to everything.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:padi_learn/services/supabase_storage_service.dart';

/// One upload as the server saw it.
class Received {
  final String path;
  final String? upsert;
  final String contentType;
  final List<int> body;
  Received(this.path, this.upsert, this.contentType, this.body);

  /// The multipart envelope is text; the file inside it is not.
  String get text => latin1.decode(body);
}

bool containsBytes(List<int> haystack, List<int> needle) {
  outer:
  for (var i = 0; i <= haystack.length - needle.length; i++) {
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) continue outer;
    }
    return true;
  }
  return false;
}

void main() {
  late HttpServer server;
  late SupabaseClient client;
  late Directory tmp;
  late List<Received> uploads;
  late List<String> removed;

  /// Status the next uploads are answered with, by object path.
  int Function(String path) answer = (_) => 200;

  setUp(() async {
    uploads = [];
    removed = [];
    answer = (_) => 200;
    tmp = await Directory.systemTemp.createTemp('padilearn_upload_test');

    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    const sign = '/storage/v1/object/upload/sign/';
    server.listen((request) async {
      final path = request.uri.path;
      final body =
          (await request.fold(BytesBuilder(), (b, c) => b..add(c))).takeBytes();
      request.response.headers.contentType = ContentType.json;

      if (request.method == 'POST' && path.startsWith(sign)) {
        request.response.write(jsonEncode({
          'url': '/object/upload/sign/${path.substring(sign.length)}?token=t',
        }));
      } else if (request.method == 'PUT' && path.startsWith(sign)) {
        uploads.add(Received(
          path.substring(sign.length),
          request.headers.value('x-upsert'),
          request.headers.contentType?.mimeType ?? '',
          body,
        ));
        request.response.statusCode = answer(path);
        request.response.write(jsonEncode({'message': 'answered'}));
      } else if (request.method == 'DELETE') {
        removed.addAll(
            (jsonDecode(utf8.decode(body))['prefixes'] as List).cast<String>());
        request.response.write('[]');
      } else {
        request.response.statusCode = 404;
      }
      await request.response.close();
    });

    client = SupabaseClient('http://127.0.0.1:${server.port}', 'test-key');
  });

  tearDown(() async {
    await client.dispose();
    await server.close(force: true);
    await tmp.delete(recursive: true);
  });

  Future<XFile> picked(String name, List<int> bytes) async {
    final file = File('${tmp.path}${Platform.pathSeparator}$name');
    await file.writeAsBytes(bytes);
    return XFile(file.path);
  }

  test('a video and a cover both arrive whole, with progress', () async {
    final videoBytes = List<int>.generate(700 * 1024, (i) => (i * 31) % 251);
    final coverBytes = List<int>.generate(9000, (i) => (i * 7) % 253);
    final progress = <UploadProgress>[];

    final result = await uploadCourseMedia(
      userId: 'teacher-1',
      videoFile: await picked('Lesson one.MP4', videoBytes),
      thumbnailFile: await picked('cover.png', coverBytes),
      client: client,
      onProgress: progress.add,
    );

    expect(result.error, isNull);
    expect(result.success, isTrue);
    expect(result.videoPath, matches(r'^teacher-1/videos/\d+_[0-9a-f]{16}\.mp4$'));
    expect(result.thumbnailUrl, contains('/course-thumbnails/teacher-1/'));

    expect(uploads, hasLength(2));
    final video = uploads[0];
    expect(video.path, 'course-media/${result.videoPath}');
    expect(video.contentType, 'multipart/form-data');
    expect(video.upsert, 'false');
    expect(video.text, contains('name="cacheControl"'));
    expect(video.text, contains('filename="Lesson one.MP4"'));
    expect(video.text, contains('content-type: video/mp4'));
    expect(containsBytes(video.body, videoBytes), isTrue);

    final cover = uploads[1];
    expect(cover.path, startsWith('course-thumbnails/teacher-1/thumbnails/'));
    expect(cover.text, contains('content-type: image/png'));
    expect(containsBytes(cover.body, coverBytes), isTrue);

    // The bar moves during the video, never backwards, and ends full. Only
    // the video stage is compared: the count includes the multipart envelope
    // until each file finishes and is snapped to its exact size.
    expect(progress.first.stage, UploadStage.preparing);
    final duringVideo =
        progress.where((p) => p.stage == UploadStage.video).toList();
    expect(duringVideo.length, greaterThan(1));
    for (var i = 1; i < duringVideo.length; i++) {
      expect(duringVideo[i].bytesSent,
          greaterThan(duringVideo[i - 1].bytesSent));
    }
    expect(progress.last.stage, UploadStage.saving);
    expect(progress.last.bytesSent, videoBytes.length + coverBytes.length);
    expect(progress.last.fraction, 1.0);
  });

  test('a refusal from the server is explained, not thrown', () async {
    answer = (_) => 413;
    final result = await uploadCourseMedia(
      userId: 'teacher-1',
      videoFile: await picked('big.mp4', [1, 2, 3]),
      client: client,
    );

    expect(result.success, isFalse);
    expect(result.error, contains('"big.mp4" is larger than the server allows'));
  });

  test('a cover that fails takes the uploaded video back out', () async {
    answer = (path) => path.contains('/thumbnails/') ? 500 : 200;
    final result = await uploadCourseMedia(
      userId: 'teacher-1',
      videoFile: await picked('v.mp4', [1, 2, 3]),
      thumbnailFile: await picked('c.png', [4, 5, 6]),
      client: client,
    );

    expect(result.success, isFalse);
    expect(removed, [uploads.first.path.substring('course-media/'.length)]);
  });

  test('a file that has gone is reported before anything is sent', () async {
    final result = await uploadCourseMedia(
      userId: 'teacher-1',
      videoFile: XFile('${tmp.path}${Platform.pathSeparator}missing.mp4'),
      client: client,
    );

    expect(result.success, isFalse);
    expect(result.error, contains('Could not read the selected files'));
    expect(uploads, isEmpty);
  });

  test('a file over the limit is refused before anything is sent', () async {
    final result = await uploadCourseMedia(
      userId: 'teacher-1',
      videoFile: XFile.fromData(
        Uint8List(0),
        path: 'huge.mp4',
        length: kMaxVideoBytes + 1,
      ),
      client: client,
    );

    expect(result.success, isFalse);
    expect(result.error, contains('The limit is 300 MB'));
    expect(uploads, isEmpty);
  });
}
