import 'dart:io';
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Name of the Supabase Storage bucket that holds course media.
/// Create this bucket in the Supabase Dashboard (see setup steps).
const String kCourseMediaBucket = 'course-media';

/// Folder (object-key prefix) used for each kind of asset inside the bucket.
const String _videoFolder = 'videos';
const String _thumbnailFolder = 'thumbnails';

/// Result of an [uploadVideoAndThumbnail] call.
///
/// Always inspect [success] first. On success, [videoUrl]/[thumbnailUrl] are
/// non-null public URLs ready to render in the UI; on failure, [error] holds a
/// human-readable message and the URLs are null.
class MediaUploadResult {
  final bool success;
  final String? videoUrl;
  final String? thumbnailUrl;

  /// Object keys inside the bucket (useful for later deletion/management).
  final String? videoPath;
  final String? thumbnailPath;

  final String? error;

  const MediaUploadResult._({
    required this.success,
    this.videoUrl,
    this.thumbnailUrl,
    this.videoPath,
    this.thumbnailPath,
    this.error,
  });

  factory MediaUploadResult.success({
    required String videoUrl,
    required String thumbnailUrl,
    required String videoPath,
    required String thumbnailPath,
  }) =>
      MediaUploadResult._(
        success: true,
        videoUrl: videoUrl,
        thumbnailUrl: thumbnailUrl,
        videoPath: videoPath,
        thumbnailPath: thumbnailPath,
      );

  factory MediaUploadResult.failure(String error) =>
      MediaUploadResult._(success: false, error: error);
}

/// Uploads a [videoFile] and its [thumbnailFile] to Supabase Storage under a
/// per-user namespace, concurrently, and returns their public URLs.
///
/// - Files are stored at `<userId>/videos/...` and `<userId>/thumbnails/...`
///   with a timestamp + random token to guarantee uniqueness (no overwrites).
/// - `contentType` is set explicitly so videos stream and images render.
/// - If either upload fails, any partially-uploaded object is removed so the
///   bucket is never left with an orphan, and a clean failure is returned.
///
/// Pass a custom [client] in tests; defaults to [Supabase.instance.client].
Future<MediaUploadResult> uploadVideoAndThumbnail(
  File videoFile,
  File thumbnailFile,
  String userId, {
  SupabaseClient? client,
  String bucket = kCourseMediaBucket,
}) async {
  if (userId.trim().isEmpty) {
    return MediaUploadResult.failure(
        'A non-empty userId is required to namespace uploads.');
  }

  final SupabaseClient supabase = client ?? Supabase.instance.client;

  // Generate secure, collision-free object keys up front.
  final String videoPath = _buildObjectPath(
    userId: userId,
    folder: _videoFolder,
    sourceName: videoFile.path,
  );
  final String thumbnailPath = _buildObjectPath(
    userId: userId,
    folder: _thumbnailFolder,
    sourceName: thumbnailFile.path,
  );

  // Run both uploads concurrently. Each call captures its own error so that
  // Future.wait never short-circuits and we can clean up partial state.
  final List<_UploadOutcome> outcomes = await Future.wait(<Future<_UploadOutcome>>[
    _uploadObject(supabase, bucket, videoPath, videoFile),
    _uploadObject(supabase, bucket, thumbnailPath, thumbnailFile),
  ]);

  final _UploadOutcome videoOutcome = outcomes[0];
  final _UploadOutcome thumbnailOutcome = outcomes[1];

  if (videoOutcome.ok && thumbnailOutcome.ok) {
    final storage = supabase.storage.from(bucket);
    return MediaUploadResult.success(
      videoUrl: storage.getPublicUrl(videoPath),
      thumbnailUrl: storage.getPublicUrl(thumbnailPath),
      videoPath: videoPath,
      thumbnailPath: thumbnailPath,
    );
  }

  // Partial failure: best-effort removal of whichever object did upload.
  final List<String> orphans = <String>[
    if (videoOutcome.ok) videoPath,
    if (thumbnailOutcome.ok) thumbnailPath,
  ];
  if (orphans.isNotEmpty) {
    try {
      await supabase.storage.from(bucket).remove(orphans);
    } catch (_) {
      // Swallow cleanup errors — the original failure is what matters.
    }
  }

  final String message = <String?>[videoOutcome.error, thumbnailOutcome.error]
      .whereType<String>()
      .join(' | ');
  return MediaUploadResult.failure(
      message.isEmpty ? 'Upload failed for an unknown reason.' : message);
}

/// Internal outcome of a single object upload.
class _UploadOutcome {
  final bool ok;
  final String? error;
  const _UploadOutcome.success() : ok = true, error = null;
  const _UploadOutcome.failure(this.error) : ok = false;
}

/// Uploads one [file] to [path] in [bucket] with an explicit content type.
/// Translates the various failure modes into a clean [_UploadOutcome].
Future<_UploadOutcome> _uploadObject(
  SupabaseClient supabase,
  String bucket,
  String path,
  File file,
) async {
  final String name = _basename(file.path);
  try {
    await supabase.storage.from(bucket).upload(
          path,
          file,
          fileOptions: FileOptions(
            contentType: _resolveContentType(file.path),
            cacheControl: '3600',
            upsert: false, // Never overwrite — paths are unique by design.
          ),
        );
    return const _UploadOutcome.success();
  } on StorageException catch (e) {
    return _UploadOutcome.failure('Storage error on "$name": ${e.message}');
  } on SocketException catch (_) {
    return _UploadOutcome.failure('Network failure while uploading "$name".');
  } catch (e) {
    return _UploadOutcome.failure('Unexpected error uploading "$name": $e');
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
