// What the app actually sends when a course is saved as a draft, uploaded
// outright, or uploaded later, checked against a real local server standing
// in for the Supabase REST API.
//
// The one thing this exists to pin: a draft sends `published_at: null`, and a
// live course does not send the column at all. The column's default is now(),
// so that the APKs installed before drafts (which have never heard of it) keep
// producing live courses. A new app that left the key out for a draft would
// publish it; one that sent a value for a live course would be relying on
// something the old apps cannot do.
//
// No Flutter binding is started on purpose: the test binding replaces the
// HTTP client with one that answers 400 to everything.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:padi_learn/services/course_service.dart';
import 'package:padi_learn/services/lesson_service.dart';

/// One request as the server saw it.
class Seen {
  final String method;
  final Uri uri;
  final String body;
  Seen(this.method, this.uri, this.body);

  Map<String, dynamic> get json => jsonDecode(body) as Map<String, dynamic>;
}

void main() {
  late HttpServer server;
  late SupabaseClient client;
  late List<Seen> seen;

  /// When set, the next write is refused the way the database refuses it.
  Map<String, dynamic>? refusal;

  setUp(() async {
    seen = [];
    refusal = null;

    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final body = await utf8.decoder.bind(request).join();
      final path = request.uri.path;
      seen.add(Seen(request.method, request.uri, body));
      request.response.headers.contentType = ContentType.json;

      if (request.method != 'GET' && refusal != null) {
        request.response.statusCode = 400;
        request.response.write(jsonEncode(refusal));
      } else if (request.method == 'POST' && path == '/rest/v1/courses') {
        request.response.statusCode = 201;
        request.response.write(jsonEncode({'id': 'course-1'}));
      } else if (request.method == 'GET' && path == '/rest/v1/courses') {
        request.response.write(jsonEncode([
          {'id': 'draft-1'},
          {'id': 'draft-2'},
        ]));
      } else if (request.method == 'GET' && path == '/rest/v1/lessons') {
        request.response.write('[]');
      } else if (request.method == 'POST' && path == '/rest/v1/lessons') {
        request.response.statusCode = 201;
        request.response.write(jsonEncode({
          'id': 'lesson-1',
          ...jsonDecode(body) as Map<String, dynamic>,
        }));
      } else if (request.method == 'POST' &&
          path == '/rest/v1/rpc/publish_course') {
        request.response.write(jsonEncode('2026-10-10T09:00:00+00:00'));
      } else {
        request.response.statusCode = 404;
        request.response.write('{}');
      }
      await request.response.close();
    });

    client = SupabaseClient('http://127.0.0.1:${server.port}', 'test-key');
  });

  tearDown(() async {
    await client.dispose();
    await server.close(force: true);
  });

  Seen theInsert() => seen.singleWhere(
      (r) => r.method == 'POST' && r.uri.path == '/rest/v1/courses');

  test('"Save to drafts" with only a title sends an explicit null', () async {
    final id = await CourseService.create(
      userId: 'teacher-1',
      title: '  Excel for Small Businesses ',
      description: '   ',
      author: '',
      asDraft: true,
      client: client,
    );

    expect(id, 'course-1');
    final sent = theInsert().json;
    expect(sent.containsKey('published_at'), isTrue,
        reason: 'leaving the key out takes the default, which is live');
    expect(sent['published_at'], isNull);
    expect(sent['title'], 'Excel for Small Businesses');
    expect(sent['user_id'], 'teacher-1');
    // Nothing typed is nothing saved: not an empty string the checklist
    // would have to second-guess, and not a 0 that would mean "free".
    expect(sent['description'], isNull);
    expect(sent['author'], isNull);
    expect(sent['price'], isNull);
    expect(sent['category'], isNull);
    expect(sent['thumbnail_url'], isNull);
  });

  test('a draft keeps whatever else was filled in', () async {
    await CourseService.create(
      userId: 'teacher-1',
      title: 'Excel for Small Businesses',
      description: 'Formulas, tables and a monthly cash book.',
      price: 5000,
      category: 'Business',
      author: 'Ada Teacher',
      thumbnailUrl: 'https://example.test/cover.png',
      asDraft: true,
      client: client,
    );

    final sent = theInsert().json;
    expect(sent['published_at'], isNull);
    expect(sent['description'], 'Formulas, tables and a monthly cash book.');
    expect(sent['price'], 5000);
    expect(sent['category'], 'Business');
    expect(sent['author'], 'Ada Teacher');
    expect(sent['thumbnail_url'], 'https://example.test/cover.png');
  });

  test('"Upload" sends what the apps before drafts sent: no published_at',
      () async {
    await CourseService.create(
      userId: 'teacher-1',
      title: 'Excel for Small Businesses',
      description: 'Formulas, tables and a monthly cash book.',
      price: 0,
      category: 'Business',
      author: 'Ada Teacher',
      thumbnailUrl: 'https://example.test/cover.png',
      asDraft: false,
      client: client,
    );

    final sent = theInsert().json;
    expect(sent.containsKey('published_at'), isFalse);
    expect(
        sent.keys.toSet(),
        {
          'title',
          'description',
          'price',
          'category',
          'author',
          'thumbnail_url',
          'user_id',
        },
        reason: 'INSERT on courses is granted column by column');
  });

  test('a fourth draft: the database\'s sentence reaches the teacher as it is',
      () async {
    refusal = {
      'code': '22023',
      'message':
          'You already have 3 drafts. Upload or delete one before saving another.',
      'details': null,
      'hint': null,
    };

    Object? caught;
    try {
      await CourseService.create(
        userId: 'teacher-1',
        title: 'One too many',
        asDraft: true,
        client: client,
      );
    } catch (e) {
      caught = e;
    }

    expect(caught, isA<PostgrestException>());
    expect(
      courseErrorMessage(caught!, fallback: 'Could not save the draft'),
      'You already have 3 drafts. Upload or delete one before saving another.',
    );
  });

  test('the draft count asks only for this teacher\'s unpublished courses',
      () async {
    expect(await CourseService.draftCount('teacher-1', client: client), 2);

    final query = seen.single.uri.queryParameters;
    expect(query['user_id'], 'eq.teacher-1');
    expect(query['published_at'], 'is.null');
  });

  test('a draft\'s first lesson is written against the draft', () async {
    final lesson = await LessonService.add(
      courseId: 'course-1',
      title: 'Lesson 1',
      videoPath: 'teacher-1/videos/1_a.mp4',
      durationSeconds: 95,
      isPreview: true,
      client: client,
    );

    expect(lesson.hasVideo, isTrue);
    final sent = seen
        .singleWhere(
            (r) => r.method == 'POST' && r.uri.path == '/rest/v1/lessons')
        .json;
    expect(sent['course_id'], 'course-1');
    expect(sent['position'], 1);
    expect(sent['video_url'], 'teacher-1/videos/1_a.mp4');
    expect(sent['is_preview'], isTrue);
  });

  test('uploading a draft calls publish_course with its id', () async {
    await CourseService.publish('course-1', client: client);

    final call = seen.single;
    expect(call.uri.path, '/rest/v1/rpc/publish_course');
    expect(call.json, {'p_course_id': 'course-1'});
  });

  test('an incomplete draft: the reason is thrown word for word', () async {
    const sentence = 'This course cannot be uploaded yet. It still needs a '
        'description and a lesson with a video.';
    refusal = {
      'code': '22023',
      'message': sentence,
      'details': null,
      'hint': null,
    };

    await expectLater(
      CourseService.publish('course-1', client: client),
      throwsA(isA<Exception>().having(
        (e) => e.toString().replaceFirst('Exception: ', ''),
        'what the screen shows',
        sentence,
      )),
    );
  });
}
