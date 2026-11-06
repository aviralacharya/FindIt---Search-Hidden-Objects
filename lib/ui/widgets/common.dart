import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_services.dart';
import '../../app/theme.dart';
import '../../core/art/brand_art.dart';
import '../../core/domain/puzzle.dart';

class CoinPill extends StatelessWidget {
  const CoinPill(this.coins, {super.key, this.compact = false});
  final int coins;
  final bool compact;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '$coins coins',
    excludeSemantics: true,
    child: Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14, vertical: 9),
      decoration: BoxDecoration(
        color: FindItColors.paper,
        border: Border.all(color: FindItColors.line),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 23,
            height: 23,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF6E5B9),
              shape: BoxShape.circle,
              border: Border.all(color: FindItColors.gold),
            ),
            child: const Icon(
              Icons.star_rounded,
              size: 14,
              color: Color(0xFF9A7635),
            ),
          ),
          const SizedBox(width: 7),
          Text('$coins', style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    ),
  );
}

class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color = FindItColors.muted});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.labelMedium?.copyWith(
      color: color,
      letterSpacing: 1.5,
      fontSize: 10,
      fontWeight: FontWeight.w800,
    ),
  );
}

class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.color = FindItColors.paper,
    this.padding = const EdgeInsets.all(22),
    this.onTap,
    this.border = true,
  });
  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool border;
  @override
  Widget build(BuildContext context) => Material(
    color: color,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
      side: border
          ? const BorderSide(color: FindItColors.line)
          : BorderSide.none,
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(padding: padding, child: child),
    ),
  );
}

class PageContent extends StatelessWidget {
  const PageContent({
    super.key,
    required this.child,
    this.maxWidth = 1120,
    this.padding,
    this.scrollController,
  });
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  final ScrollController? scrollController;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final inset = constraints.maxWidth < 600 ? 20.0 : 36.0;
      return SingleChildScrollView(
        controller: scrollController,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: padding ?? EdgeInsets.fromLTRB(inset, 18, inset, 32),
              child: child,
            ),
          ),
        ),
      );
    },
  );
}

class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {super.key, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: FindItColors.muted),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 10), trailing!],
      ],
    ),
  );
}

class Stars extends StatelessWidget {
  const Stars(this.count, {super.key, this.size = 18});
  final int count;
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '$count of 3 stars',
    excludeSemantics: true,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Icon(
            Icons.star_rounded,
            size: size,
            color: i < count ? FindItColors.gold : const Color(0xFFDBDED3),
          ),
      ],
    ),
  );
}

class IconBadge extends StatelessWidget {
  const IconBadge(
    this.icon, {
    super.key,
    this.color = FindItColors.forest,
    this.background = FindItColors.sage,
    this.size = 44,
  });
  final IconData icon;
  final Color color;
  final Color background;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(size * .32),
    ),
    child: Icon(icon, color: color, size: size * .5),
  );
}

class OfflineNote extends StatelessWidget {
  const OfflineNote({super.key});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.cloud_off_rounded, size: 15, color: FindItColors.muted),
      const SizedBox(width: 7),
      Flexible(
        child: Text(
          'Play offline. Your progress stays here.',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: FindItColors.muted),
        ),
      ),
    ],
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.mode = GameMode.hidden,
    this.action,
  });
  final String title;
  final String message;
  final GameMode mode;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ModeArtwork(mode, width: 158, height: 118),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 10),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(color: FindItColors.muted),
        ),
        if (action != null) ...[const SizedBox(height: 24), action!],
      ],
    ),
  );
}

void showMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

String formatTime(int milliseconds) {
  final seconds = (milliseconds / 1000).ceil();
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

IconData modeIcon(GameMode mode) => switch (mode) {
  GameMode.differences => Icons.compare_rounded,
  GameMode.hidden => Icons.search_rounded,
  GameMode.odd => Icons.grid_view_rounded,
  GameMode.memory => Icons.style_rounded,
  GameMode.quick => Icons.bolt_rounded,
  GameMode.daily => Icons.calendar_today_rounded,
};

/// A single interrupted puzzle is kept. Starting another requires an explicit
/// decision, never a silent overwrite from a home or daily card.
Future<void> launchPuzzle(
  BuildContext context,
  WidgetRef ref,
  Puzzle puzzle, {
  String? dailyKey,
  bool resume = false,
}) async {
  final services = ref.read(servicesProvider);
  final saved = services.progress.current.savedGame;
  var shouldResume = resume;
  if (!resume && saved != null) {
    final same = saved.puzzleId == puzzle.id;
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          same ? 'Pick up where you left off?' : 'A discovery is in progress',
        ),
        content: Text(
          same ? 'Your finds, timer, and hints are saved on this device.' : 'Starting this level replaces your unfinished puzzle. Completed levels and coins are kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Not now'),
          ),
          if (same)
            TextButton(
              onPressed: () => Navigator.pop(context, 'resume'),
              child: const Text('Continue'),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'new'),
            child: Text(same ? 'Start again' : 'Start new puzzle'),
          ),
        ],
      ),
    );
    if (!context.mounted || choice == null) return;
    shouldResume = choice == 'resume';
  }
  if (!context.mounted) return;
  final query = <String, String>{
    'daily': ?dailyKey,
    if (shouldResume) 'resume': '1',
  };
  await context.push(
    Uri(
      path: '/play/${puzzle.id}',
      queryParameters: query.isEmpty ? null : query,
    ).toString(),
  );
}
