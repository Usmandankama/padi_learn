import 'package:flutter/material.dart';

import 'package:padi_learn/utils/colors.dart';
import 'package:padi_learn/utils/money.dart';

import '../data/admin_api.dart';
import '../widgets/course_actions.dart';
import '../widgets/format.dart';
import '../widgets/panel.dart';

/// Courses (docs/ADMIN_PANEL.md, item 12d): every course, including the ones
/// the marketplace hides, with take down and restore.
///
/// "Archived" is the teacher's own switch and "taken down" is PadiLearn's;
/// the screen keeps them apart because only the second is an admin's to undo.
class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key, this.api = const AdminApi()});

  final AdminApi api;

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

enum _Filter { all, live, archived, takenDown }

String _state(Map<String, dynamic> c) => c['removed_at'] != null
    ? 'takenDown'
    : c['archived_at'] != null
        ? 'archived'
        : 'live';

class _CoursesScreenState extends State<CoursesScreen> {
  _Filter _filter = _Filter.all;
  String _query = '';
  int _version = 0;
  final Set<String> _busy = {};

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _act(String courseId, Future<String> Function() action) async {
    setState(() => _busy.add(courseId));
    try {
      final message = await action();
      if (!mounted) return;
      _snack(message);
      setState(() {
        _version++;
      });
    } catch (e) {
      if (mounted) _snack(adminErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy.remove(courseId));
    }
  }

  Future<void> _takeDown(Map<String, dynamic> course) async {
    final reason = await askToTakeCourseDown(context);
    if (reason == null) return;
    await _act(course['id'] as String, () async {
      return describeTakedown(
          await widget.api.removeCourse(course['id'] as String, reason));
    });
  }

  Future<void> _restore(Map<String, dynamic> course) async {
    final reason = await askToRestoreCourse(context);
    if (reason == null) return;
    await _act(course['id'] as String, () async {
      await widget.api.restoreCourse(course['id'] as String, reason);
      return 'Course restored.';
    });
  }

  bool _matches(Map<String, dynamic> c) {
    final state = _state(c);
    final byFilter = switch (_filter) {
      _Filter.all => true,
      _Filter.live => state == 'live',
      _Filter.archived => state == 'archived',
      _Filter.takenDown => state == 'takenDown',
    };
    if (!byFilter) return false;
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return '${c['title']} ${c['owner_name'] ?? ''} ${c['category'] ?? ''}'
        .toLowerCase()
        .contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);

    return AdminLoader<List<Map<String, dynamic>>>(
      key: ValueKey(_version),
      load: widget.api.courses,
      builder: (context, courses) {
        int count(String state) =>
            courses.where((c) => _state(c) == state).length;
        final shown = courses.where(_matches).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Wrap(
                spacing: 16,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SegmentedButton<_Filter>(
                    segments: [
                      ButtonSegment(
                          value: _Filter.all,
                          label: Text('All ${courses.length}')),
                      ButtonSegment(
                          value: _Filter.live,
                          label: Text('Live ${count('live')}')),
                      ButtonSegment(
                          value: _Filter.archived,
                          label: Text('Archived ${count('archived')}')),
                      ButtonSegment(
                          value: _Filter.takenDown,
                          label: Text('Taken down ${count('takenDown')}')),
                    ],
                    selected: {_filter},
                    onSelectionChanged: (s) =>
                        setState(() => _filter = s.first),
                  ),
                  SizedBox(
                    width: 280,
                    child: TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Title, teacher or category',
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _query = v.trim()),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh',
                    icon: const Icon(Icons.refresh),
                    onPressed: () => setState(() {
                      _version++;
                    }),
                  ),
                ],
              ),
            ),
            Expanded(
              child: shown.isEmpty
                  ? Center(
                      child: Text('No courses match.',
                          style: TextStyle(color: palette.inkSoft)),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      itemCount: shown.length,
                      separatorBuilder: (_, __) =>
                          Divider(color: palette.hairline),
                      itemBuilder: (context, i) {
                        final course = shown[i];
                        final removed = course['removed_at'] != null;
                        return _CourseRow(
                          course: course,
                          busy: _busy.contains(course['id']),
                          onTakeDown: removed ? null : () => _takeDown(course),
                          onRestore: removed ? () => _restore(course) : null,
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _CourseRow extends StatelessWidget {
  const _CourseRow({
    required this.course,
    required this.busy,
    this.onTakeDown,
    this.onRestore,
  });

  final Map<String, dynamic> course;
  final bool busy;
  final VoidCallback? onTakeDown;
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final error = Theme.of(context).colorScheme.error;

    final state = _state(course);
    final (stateLabel, stateColor) = switch (state) {
      'takenDown' => ('Taken down', error),
      'archived' => ('Archived by teacher', palette.inkSoft),
      _ => ('Live', AppColors.primaryColor),
    };

    final facts = [
      'by ${course['owner_name'] ?? 'a deleted account'}',
      if (course['category'] != null) '${course['category']}',
      formatPriceLabel(course['price'] as num? ?? 0),
      '${asCount(course['enrollments'])} enrolled',
      'added ${formatWhen(course['created_at']).split(',').first}',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${course['title']}',
                        style: text.titleSmall?.copyWith(
                            color: palette.ink, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(stateLabel,
                        style: text.labelSmall?.copyWith(color: stateColor)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(facts,
                    style: text.bodySmall?.copyWith(color: palette.inkSoft)),
                if (state == 'takenDown') ...[
                  const SizedBox(height: 4),
                  Text(
                    'Taken down ${formatWhen(course['removed_at'])}: '
                    '${course['removed_reason'] ?? ''}',
                    style: text.bodySmall?.copyWith(color: palette.ink),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          if (onTakeDown != null)
            OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: error),
              onPressed: busy ? null : onTakeDown,
              child: const Text('Take down'),
            ),
          if (onRestore != null)
            FilledButton(
              onPressed: busy ? null : onRestore,
              child: const Text('Restore'),
            ),
        ],
      ),
    );
  }
}
