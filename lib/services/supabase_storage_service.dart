import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Private bucket holding course videos. Objects here are never public — the
/// `get-course-video` edge function issues a short-lived signed URL once it has
/// verified the caller owns the course or is enrolled in it.
const String kCourseMediaBucket = 'course-media';

/// Public bucket holding course cover images. Thumbnails are not paid content
/// and appear in every listing, so they are served directly.
const String kCourseThumbnailBucket = 'course-thumbnails';

/// Folder (object-key prefix) used for each kind of asset.
const String _videoFolder = 'videos';
const String _thumbnailFolder = 'thumbnails';

/// Size ceilings, mirroring the bucket limits set in
/// `supabase/migrations/20260801000001_harden_storage.sql`. Checking client-side
/// means an oversized file is rejected in milliseconds instead of after a long
/// upload that the server was always going to refuse.
const int kMaxVideoBytes = 50 * 1024 * 1024; // 52428800
const int kMaxThumbnailBytes = 10 * 1024 * 1024; // 10485760

/// Human-readable byte count, e.g. `48.2 MB`.
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = <String>['KB', 'MB', 'GB'];
  var value = bytes / 1024;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(value >= 100 ? 0 : 1)} ${units[unit]}';
}

/// Returns a user-facing message when a file exceeds its bucket's limit, or
/// null when everything provided is within range. Either side may be null when
/// only one file is being replaced.
String? validateCourseMedia({
  int? videoBytes,
  int? thumbnailBytes,
}) {
  if (videoBytes != null && videoBytes > kMaxVideoBytes) {
    return 'That video is ${formatBytes(videoBytes)}. The limit is '
        '${formatBytes(kMaxVideoBytes)} — please trim or compress it.';
  }
  if (thumbnailBytes != null && thumbnailBytes > kMaxThumbnailBytes) {
    return 'That thumbnail is ${formatBytes(thumbnailBytes)}. The limit is '
        '${formatBytes(kMaxThumbnailBytes)}.';
  }
  return null;
}

/// Where a course upload currently is.
enum UploadStage { preparing, video, thumbnail, saving, done }

extension UploadStageLabel on UploadStage {
  String get label {
    switch (this) {
      case UploadStage.preparing:
        return 'Preparing upload…';
      case UploadStage.video:
        return 'Uploading video…';
      case UploadStage.thumbnail:
        return 'Adding thumbnail…';
      case UploadStage.saving:
        return 'Saving course…';
      case UploadStage.done:
        return 'Done';
    }
  }
}

/// A progress snapshot for the whole course upload.
///
/// [fraction] is byte-accurate across both files, so the bar reflects real
/// transfer rather than a stage counter.
class UploadProgress {
  final UploadStage stage;
  final int bytesSent;
  final int totalBytes;
  final Duration elapsed;

  const UploadProgress({
    required this.stage,
    required this.bytesSent,
    required this.totalBytes,
    required this.elapsed,
  });

  double get fraction =>
      totalBytes <= 0 ? 0 : (bytesSent / totalBytes).clamp(0.0, 1.0);

  int get percent => (fraction * 100).round();

  /// `12.4 MB of 48.2 MB`
  String get sizeLabel =>
      '${formatBytes(bytesSent)} of ${formatBytes(totalBytes)}';

  /// Time left, extrapolated from throughput so far. Null until there is
  /// enough of a sample to be meaningful — a wrong estimate is worse than none.
  Duration? get estimatedRemaining {
    if (bytesSent < 256 * 1024 || elapsed.inMilliseconds < 1500) return null;
    if (bytesSent >= totalBytes) return null;
    final bytesPerMs = bytesSent / elapsed.inMilliseconds;
    if (bytesPerMs <= 0) return null;
    return Duration(
        milliseconds: ((totalBytes - bytesSent) / bytesPerMs).round());
  }

  /// `about 2 min left`
  String? get remainingLabel {
    final left = estimatedRemaining;
    if (left == null) return null;
    if (left.inSeconds < 10) return 'almost done';
    if (left.inSeconds < 60) return 'about ${left.inSeconds}s left';
    return 'about ${left.inMinutes} min left';
  }
}

/// Result of an [uploadVideoAndThumbnail] call.
///
/// Always inspect [success] first. On failure, [error] holds a human-readable
/// message and everything else is null.
class MediaUploadResult {
  final bool success;

  /// Object key of the video inside [kCourseMediaBucket]. This — not a URL —
  /// is what belongs in `courses.video_url`: the bucket is private, so a
  /// playback URL has to be signed per request.
  final String? videoPath;

  /// Public URL of the cover image, ready to hand to `Image.network`.
  final String? thumbnailUrl;

  /// Object key of the thumbnail (useful for later deletion/management).
  final String? thumbnailPath;

  final String? error;

  const MediaUploadResult._({
    required this.success,
    this.videoPath,
    this.thumbnailUrl,
    this.thumbnailPath,
    this.error,
  });

  /// Fields are individually nullable because an edit may replace only the
  /// video, only the thumbnail, or both.
  factory MediaUploadResult.success({
    String? videoPath,
    String? thumbnailUrl,
    String? thumbnailPath,
  }) =>
      MediaUploadResult._(
        success: true,
        videoPath: videoPath,
        thumbnailUrl: thumbnailUrl,
        thumbnailPath: thumbnailPath,
      );

  factory MediaUploadResult.failure(String error) =>
      MediaUploadResult._(success: false, error: error);
}

/// A media reference stored in the database, resolved back to the bucket and
/// object key it points at.
class StoredObject {
  final String bucket;
  final String path;
  const StoredObject(this.bucket, this.path);

  /// Parses either a bare object key (what new rows store) or a full public
  /// URL of the form `.../storage/v1/object/public/<bucket>/<key>` (what rows
  /// created before the bucket split store).
  ///
  /// [fallbackBucket] is used when [stored] is a bare key and therefore carries
  /// no bucket of its own. Returns null for anything else — an absolute URL we
  /// did not issue is not ours to delete.
  static StoredObject? parse(String? stored, {required String fallbackBucket}) {
    if (stored == null || stored.trim().isEmpty) return null;

    const marker = '/storage/v1/object/public/';
    final at = stored.indexOf(marker);
    if (at != -1) {
      final rest = stored.substring(at + marker.length).split('?').first;
      final slash = rest.indexOf('/');
      if (slash <= 0 || slash == rest.length - 1) return null;
      return StoredObject(
        rest.substring(0, slash),
        Uri.decodeComponent(rest.substring(slash + 1)),
      );
    }

    if (RegExp(r'^https?://', caseSensitive: false).hasMatch(stored)) {
      return null;
    }
    return StoredObject(fallbackBucket, stored.replaceFirst(RegExp(r'^/+'), ''));
  }
}

/// Best-effort removal of a previously stored object, used after a successful
/// media replacement. Never throws: an orphaned file is a smaller problem than
/// a failed save the teacher can't explain.
Future<void> removeStoredObject(
  String? stored, {
  required String fallbackBucket,
  SupabaseClient? client,
}) async {
  final object = StoredObject.parse(stored, fallbackBucket: fallbackBucket);
  if (object == null) return;
  try {
    final supabase = client ?? Supabase.instance.client;
    await supabase.storage.from(object.bucket).remove(<String>[object.path]);
  } catch (_) {
    // Ignore — the row already points at the new file.
  }
}

/// Uploads course media to Supabase Storage under a per-user namespace,
/// reporting progress as it goes.
///
/// Both files are optional so this serves creation (video + thumbnail) and
/// editing (replace one, keep the other) from one path.
///
/// - Sizes are validated up front against the bucket limits.
/// - The video goes to the private [videoBucket] and only its object key is
///   returned; the thumbnail goes to the public [thumbnailBucket] and comes
///   back as a ready-to-render URL.
/// - Files are stored at `<userId>/videos/...` and `<userId>/thumbnails/...`
///   with a timestamp + random token to guarantee uniqueness (no overwrites).
///   The `<userId>` prefix is what the storage policies check, so it must stay
///   the first path segment.
/// - Uploads run sequentially (video, then thumbnail) so [onProgress] describes
///   one thing at a time. The thumbnail is small, so the wall-clock cost of not
///   parallelising is negligible.
/// - If the second upload fails, the first is removed so the buckets are never
///   left with an orphan, and a clean failure is returned.
///
/// Pass a custom [client] in tests; defaults to [Supabase.instance.client].
Future<MediaUploadResult> uploadCourseMedia({
  required String userId,
  File? videoFile,
  File? thumbnailFile,
  SupabaseClient? client,
  String videoBucket = kCourseMediaBucket,
  String thumbnailBucket = kCourseThumbnailBucket,
  void Function(UploadProgress)? onProgress,
}) async {
  if (userId.trim().isEmpty) {
    return MediaUploadResult.failure(
        'A non-empty userId is required to namespace uploads.');
  }
  if (videoFile == null && thumbnailFile == null) {
    return MediaUploadResult.success();
  }

  final SupabaseClient supabase = client ?? Supabase.instance.client;
  final stopwatch = Stopwatch()..start();

  final int videoBytes;
  final int thumbnailBytes;
  try {
    videoBytes = videoFile == null ? 0 : await videoFile.length();
    thumbnailBytes = thumbnailFile == null ? 0 : await thumbnailFile.length();
  } on FileSystemException catch (e) {
    return MediaUploadResult.failure('Could not read the selected files: ${e.message}');
  }

  final sizeError = validateCourseMedia(
    videoBytes: videoFile == null ? null : videoBytes,
    thumbnailBytes: thumbnailFile == null ? null : thumbnailBytes,
  );
  if (sizeError != null) return MediaUploadResult.failure(sizeError);

  final total = videoBytes + thumbnailBytes;
  var sent = 0;

  void report(UploadStage stage) {
    onProgress?.call(UploadProgress(
      stage: stage,
      bytesSent: sent,
      totalBytes: total,
      elapsed: stopwatch.elapsed,
    ));
  }

  report(UploadStage.preparing);

  String? videoPath;
  String? thumbnailPath;

  // --- Video ---------------------------------------------------------------
  if (videoFile != null) {
    videoPath = _buildObjectPath(
      userId: userId,
      folder: _videoFolder,
      sourceName: videoFile.path,
    );

    final outcome = await _uploadObject(
      supabase,
      videoBucket,
      videoPath,
      videoFile,
      onBytes: (delta) {
        sent += delta;
        report(UploadStage.video);
      },
    );
    if (!outcome.ok) return MediaUploadResult.failure(outcome.error!);

    // Snap to the exact byte count: the multipart envelope adds a little to
    // the wire total, so the counter can drift a few hundred bytes either way.
    sent = videoBytes;
    report(UploadStage.thumbnail);
  }

  // --- Thumbnail -----------------------------------------------------------
  if (thumbnailFile != null) {
    thumbnailPath = _buildObjectPath(
      userId: userId,
      folder: _thumbnailFolder,
      sourceName: thumbnailFile.path,
    );

    final outcome = await _uploadObject(
      supabase,
      thumbnailBucket,
      thumbnailPath,
      thumbnailFile,
      onBytes: (delta) {
        sent += delta;
        report(UploadStage.thumbnail);
      },
    );
    if (!outcome.ok) {
      // Best-effort removal so a failed save doesn't orphan a 50 MB video.
      if (videoPath != null) {
        try {
          await supabase.storage.from(videoBucket).remove(<String>[videoPath]);
        } catch (_) {
          // Swallow cleanup errors — the original failure is what matters.
        }
      }
      return MediaUploadResult.failure(outcome.error!);
    }
  }

  sent = total;
  report(UploadStage.saving);

  return MediaUploadResult.success(
    videoPath: videoPath,
    thumbnailUrl: thumbnailPath == null
        ? null
        : supabase.storage.from(thumbnailBucket).getPublicUrl(thumbnailPath),
    thumbnailPath: thumbnailPath,
  );
}

/// Internal outcome of a single object upload.
class _UploadOutcome {
  final bool ok;
  final String? error;
  const _UploadOutcome.success() : ok = true, error = null;
  const _UploadOutcome.failure(this.error) : ok = false;
}

/// Uploads one [file] to [path] in [bucket], invoking [onBytes] with the size
/// of each chunk as it goes onto the wire.
///
/// The Supabase SDK's own `upload()` is deliberately not used here: it builds
/// the body with `MultipartFile.fromBytes(file.readAsBytesSync())`, which loads
/// the whole video into memory on the UI isolate (janking the app on large
/// files) and exposes no progress. This streams from disk instead.
Future<_UploadOutcome> _uploadObject(
  SupabaseClient supabase,
  String bucket,
  String path,
  File file, {
  required void Function(int deltaBytes) onBytes,
}) async {
  final String name = _basename(file.path);
  http.Client? httpClient;
  try {
    // Signing runs as the current user, so storage RLS still decides whether
    // this path may be written — the upload itself just redeems the token.
    final signed =
        await supabase.storage.from(bucket).createSignedUploadUrl(path);
    final uri = Uri.parse(signed.signedUrl);

    // Build a multipart body (what the storage endpoint expects) but stream it
    // from disk rather than buffering it.
    final multipart = http.MultipartRequest('PUT', uri)
      ..fields['cacheControl'] = '3600'
      ..headers['x-upsert'] = 'false'
      ..files.add(await http.MultipartFile.fromPath(
        '',
        file.path,
        filename: name,
        contentType: MediaType.parse(_resolveContentType(file.path)),
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
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode >= 300) {
      return _UploadOutcome.failure(
        _describeHttpFailure(name, response.statusCode, responseBody),
      );
    }
    return const _UploadOutcome.success();
  } on StorageException catch (e) {
    return _UploadOutcome.failure('Storage error on "$name": ${e.message}');
  } on SocketException catch (_) {
    return _UploadOutcome.failure(
        'Network dropped while uploading "$name". Check your connection and try again.');
  } on http.ClientException catch (e) {
    return _UploadOutcome.failure(
        'Upload of "$name" was interrupted: ${e.message}');
  } catch (e) {
    return _UploadOutcome.failure('Unexpected error uploading "$name": $e');
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

/// Turns a storage HTTP failure into something a teacher can act on.
String _describeHttpFailure(String name, int status, String body) {
  switch (status) {
    case 413:
      return '"$name" is larger than the server allows '
          '(${formatBytes(kMaxVideoBytes)} max).';
    case 401:
    case 403:
      return 'You are not allowed to upload "$name". Try signing in again.';
    case 409:
      return 'A file named "$name" already exists. Please try again.';
    default:
      final detail = body.trim().isEmpty ? 'HTTP $status' : body.trim();
      return 'Upload of "$name" failed ($detail).';
  }
}

/// Builds a secure, unique object key: `<userId>/<folder>/<ts>_<token>.<ext>`.
///
/// [userId] is sanitised so a malicious value can't escape its namespace, and a
/// timestamp + cryptographically-random token prevents overwrites/guessing.
String _buildObjectPath({
  required String userId,
  required String folder,
  required String sourceName,
}) {
  final String safeUser = _sanitizeSegment(userId);
  final String ext = _extensionOf(sourceName);
  final int timestamp = DateTime.now().millisecondsSinceEpoch;
  final String token = _randomToken();
  final String suffix = ext.isEmpty ? '' : '.$ext';
  return '$safeUser/$folder/${timestamp}_$token$suffix';
}

/// Maps a file's extension to an explicit MIME type for correct streaming/render.
String _resolveContentType(String fileName) {
  const Map<String, String> contentTypes = <String, String>{
    'mp4': 'video/mp4',
    'mov': 'video/quicktime',
    'webm': 'video/webm',
    'mkv': 'video/x-matroska',
    'avi': 'video/x-msvideo',
    'm4v': 'video/x-m4v',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
    'gif': 'image/gif',
    'heic': 'image/heic',
  };
  return contentTypes[_extensionOf(fileName)] ?? 'application/octet-stream';
}

/// Lower-cased file extension without the dot, or '' if none.
String _extensionOf(String path) {
  final String name = _basename(path);
  final int dot = name.lastIndexOf('.');
  if (dot <= 0 || dot == name.length - 1) return '';
  return name.substring(dot + 1).toLowerCase();
}

/// Final path segment, handling both `/` and `\` separators.
String _basename(String path) {
  final int slash = path.lastIndexOf(RegExp(r'[\\/]'));
  return slash == -1 ? path : path.substring(slash + 1);
}

/// Restricts a path segment to a safe character set to prevent traversal.
String _sanitizeSegment(String value) =>
    value.trim().replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

/// 16-char hex token from a cryptographically-secure RNG.
String _randomToken() {
  final Random rng = Random.secure();
  final List<int> bytes = List<int>.generate(8, (_) => rng.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
