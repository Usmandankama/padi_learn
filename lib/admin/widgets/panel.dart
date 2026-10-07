import 'package:flutter/material.dart';

import 'package:padi_learn/utils/colors.dart';

import '../data/admin_api.dart';

/// A titled card: the unit every admin screen is built from.
class AdminCard extends StatelessWidget {
  const AdminCard({
    super.key,
    required this.title,
    required this.children,
    this.width = 380,
  });

  final String title;
  final List<Widget> children;
  final double width;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);

    return SizedBox(
      width: width,
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: palette.hairline),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: palette.ink,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// One labelled figure. Tappable when [onTap] is given, which the overview
/// uses to jump to the screen where the thing can be dealt with.
class StatRow extends StatelessWidget {
  const StatRow({
    super.key,
    required this.label,
    required this.value,
    this.onTap,
    this.highlight = false,
    this.indent = false,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  /// Draws attention: something is waiting.
  final bool highlight;

  /// A breakdown of the row above it.
  final bool indent;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final text = Theme.of(context).textTheme;

    final row = Padding(
      padding: EdgeInsets.fromLTRB(indent ? 16 : 0, 8, 0, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: text.bodyMedium?.copyWith(
                color: indent ? palette.inkSoft : palette.ink,
              ),
            ),
          ),
          Text(
            value,
            style: text.bodyMedium?.copyWith(
              color: highlight ? AppColors.primaryColor : palette.ink,
              fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 18, color: palette.inkSoft),
          ],
        ],
      ),
    );

    if (onTap == null) return row;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: row,
    );
  }
}

/// Loads [load] once, then shows [builder]'s result, a spinner, or the error
/// with a retry. Screens call [AdminLoaderState.reload] after an action
/// changes what they show.
class AdminLoader<T> extends StatefulWidget {
  const AdminLoader({super.key, required this.load, required this.builder});

  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data) builder;

  @override
  State<AdminLoader<T>> createState() => AdminLoaderState<T>();
}

class AdminLoaderState<T> extends State<AdminLoader<T>> {
  late Future<T> _future = widget.load();

  void reload() {
    // Started outside setState: an arrow closure there would return the
    // Future, which setState rejects. And marked handled: a fast failure
    // lands before the rebuild subscribes, and would otherwise be reported
    // as uncaught. The FutureBuilder below still receives it.
    final future = widget.load()..ignore();
    setState(() {
      _future = future;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    adminErrorMessage(snapshot.error!),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: reload,
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        return widget.builder(context, snapshot.data as T);
      },
    );
  }
}
