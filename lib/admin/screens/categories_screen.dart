import 'package:flutter/material.dart';

import 'package:padi_learn/utils/colors.dart';

import '../data/admin_api.dart';
import '../widgets/format.dart';
import '../widgets/panel.dart';

/// Categories (docs/ADMIN_PANEL.md, item 12g): approve teachers' suggestions,
/// rename, reorder, switch off, merge or delete.
///
/// Approving and switching off are one click each, because either undoes the
/// other and nothing is lost. Deleting asks where the category's courses go
/// whenever any use it, which the database insists on too.
class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key, this.api = const AdminApi()});

  final AdminApi api;

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  int _version = 0;
  bool _busy = false;

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _act(Future<String> Function() action) async {
    setState(() => _busy = true);
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
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setActive(Map<String, dynamic> c, bool active) => _act(() async {
        await widget.api.setCategoryActive(c['id'] as String, active);
        return active
            ? '"${c['name']}" is now in the app.'
            : '"${c['name']}" is switched off. Its courses keep it.';
      });

  Future<void> _edit(Map<String, dynamic> c) async {
    final edit = await showDialog<(String?, int?)>(
      context: context,
      builder: (_) => _EditDialog(category: c),
    );
    if (edit == null) return;
    final (name, position) = edit;
    await _act(() async {
      await widget.api.updateCategory(c['id'] as String,
          name: name, position: position);
      return name != null
          ? 'Renamed to "$name". Its courses follow.'
          : 'Moved to position $position.';
    });
  }

  Future<void> _delete(
      Map<String, dynamic> c, List<Map<String, dynamic>> all) async {
    final targets = [
      for (final t in all)
        if (t['is_active'] == true && t['id'] != c['id']) t,
    ];
    final moveTo = await showDialog<(String?,)>(
      context: context,
      builder: (_) => _DeleteDialog(category: c, targets: targets),
    );
    if (moveTo == null) return;
    await _act(() async {
      final result = await widget.api
          .deleteCategory(c['id'] as String, moveTo: moveTo.$1);
      final moved = asCount(result['courses_moved']);
      return moved == 0
          ? '"${c['name']}" deleted.'
          : '"${c['name']}" deleted; $moved '
              '${moved == 1 ? 'course' : 'courses'} moved.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final text = Theme.of(context).textTheme;

    return AdminLoader<List<Map<String, dynamic>>>(
      key: ValueKey(_version),
      load: widget.api.categories,
      builder: (context, categories) {
        final hidden = [
          for (final c in categories)
            if (c['is_active'] != true) c,
        ];
        final live = [
          for (final c in categories)
            if (c['is_active'] == true) c,
        ];

        Widget row(Map<String, dynamic> c) {
          final active = c['is_active'] == true;
          final suggester = c['suggested_by_name'] as String?;
          return ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('${c['name']}',
                style: TextStyle(
                    color: palette.ink, fontWeight: FontWeight.w600)),
            subtitle: Text(
              [
                'position ${asCount(c['position'])}',
                '${asCount(c['course_count'])} courses',
                if (suggester != null) 'suggested by $suggester',
              ].join(' · '),
              style: TextStyle(color: palette.inkSoft),
            ),
            trailing: Wrap(
              spacing: 4,
              children: [
                if (active)
                  TextButton(
                    onPressed: _busy ? null : () => _setActive(c, false),
                    child: const Text('Switch off'),
                  )
                else
                  FilledButton(
                    onPressed: _busy ? null : () => _setActive(c, true),
                    child: const Text('Approve'),
                  ),
                IconButton(
                  tooltip: 'Rename or reorder',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: _busy ? null : () => _edit(c),
                ),
                IconButton(
                  tooltip: 'Delete or merge',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _busy ? null : () => _delete(c, categories),
                ),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh),
                onPressed: () => setState(() {
                  _version++;
                }),
              ),
            ),
            Text('Not in the app (${hidden.length})',
                style: text.titleMedium),
            Text(
              'Suggestions from teachers wait here, along with anything '
              'switched off. A suggestion shows on its own course meanwhile.',
              style: TextStyle(color: palette.inkSoft),
            ),
            if (hidden.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('Nothing waiting.',
                    style: TextStyle(color: palette.inkSoft)),
              ),
            for (final c in hidden) row(c),
            const SizedBox(height: 24),
            Text('In the app (${live.length})', style: text.titleMedium),
            Text('In the order the app shows them.',
                style: TextStyle(color: palette.inkSoft)),
            for (final c in live) row(c),
          ],
        );
      },
    );
  }
}

/// Name and position, sending only what changed. Returns `(name, position)`.
class _EditDialog extends StatefulWidget {
  const _EditDialog({required this.category});

  final Map<String, dynamic> category;

  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  late final _name =
      TextEditingController(text: widget.category['name'] as String);
  late final _position = TextEditingController(
      text: '${asCount(widget.category['position'])}');

  @override
  void dispose() {
    _name.dispose();
    _position.dispose();
    super.dispose();
  }

  String? get _newName {
    final name = _name.text.trim();
    return name.isEmpty || name == widget.category['name'] ? null : name;
  }

  int? get _newPosition {
    final position = int.tryParse(_position.text.trim());
    return position == null ||
            position < 0 ||
            position == asCount(widget.category['position'])
        ? null
        : position;
  }

  @override
  Widget build(BuildContext context) {
    final changed = _newName != null || _newPosition != null;

    return AlertDialog(
      title: Text('Edit "${widget.category['name']}"'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _name,
              maxLength: 40,
              decoration: const InputDecoration(
                labelText: 'Name',
                helperText: 'Courses in this category follow a rename.',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _position,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Position',
                helperText: 'Lower comes first.',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: changed
              ? () => Navigator.of(context).pop((_newName, _newPosition))
              : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Where the courses go, required whenever there are any. Returns a record
/// holding the target id, or null target for a category nobody uses.
class _DeleteDialog extends StatefulWidget {
  const _DeleteDialog({required this.category, required this.targets});

  final Map<String, dynamic> category;
  final List<Map<String, dynamic>> targets;

  @override
  State<_DeleteDialog> createState() => _DeleteDialogState();
}

class _DeleteDialogState extends State<_DeleteDialog> {
  String? _moveTo;

  @override
  Widget build(BuildContext context) {
    final courses = asCount(widget.category['course_count']);
    final needsTarget = courses > 0;
    final error = Theme.of(context).colorScheme.error;

    return AlertDialog(
      title: Text('Delete "${widget.category['name']}"?'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(needsTarget
                ? '$courses ${courses == 1 ? 'course uses' : 'courses use'} '
                    'it. Choose where they go; merging a duplicate into the '
                    'real category is the usual reason.'
                : 'No course uses it.'),
            if (needsTarget) ...[
              const SizedBox(height: 12),
              DropdownButton<String>(
                isExpanded: true,
                hint: const Text('Move its courses to…'),
                value: _moveTo,
                items: [
                  for (final t in widget.targets)
                    DropdownMenuItem(
                      value: t['id'] as String,
                      child: Text('${t['name']}'),
                    ),
                ],
                onChanged: (v) => setState(() => _moveTo = v),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: error),
          onPressed: needsTarget && _moveTo == null
              ? null
              : () => Navigator.of(context).pop((_moveTo,)),
          child: Text(needsTarget ? 'Merge and delete' : 'Delete'),
        ),
      ],
    );
  }
}
