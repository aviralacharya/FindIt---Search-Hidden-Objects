import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_services.dart';
import '../../app/theme.dart';
import '../../core/art/brand_art.dart';
import '../../core/art/scene_art.dart';
import '../../core/domain/puzzle.dart';
import '../../ui/widgets/common.dart';

class LevelsScreen extends ConsumerStatefulWidget {
  const LevelsScreen({super.key, required this.mode});
  final GameMode mode;
  @override
  ConsumerState<LevelsScreen> createState() => _LevelsScreenState();
}

class _LevelsScreenState extends ConsumerState<LevelsScreen> {
  String? _category;
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final services = ref.read(servicesProvider);
    final levels = services.content.forMode(widget.mode);
    final categories = levels.map((p) => p.category).toSet().toList();
    final visible = _category == null
        ? levels
        : levels.where((p) => p.category == _category).toList();
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back to play',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/'),
        ),
        title: Text(
          widget.mode.title,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        actions: [
          CoinPill(state.progress.coins, compact: true),
          const SizedBox(width: 16),
        ],
      ),
      body: PageContent(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SoftCard(
              color: FindItColors.modeBackground(widget.mode),
              border: false,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Eyebrow(
                          widget.mode.eyebrow,
                          color: FindItColors.modeInk(widget.mode),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          widget.mode.subtitle,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.mode.instructions,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: FindItColors.muted),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '${state.progress.completedFor(widget.mode)} of ${levels.length} levels discovered',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: FindItColors.modeInk(widget.mode),
                              ),
                        ),
                      ],
                    ),
                  ),
                  if (MediaQuery.sizeOf(context).width > 550) ...[
                    const SizedBox(width: 24),
                    ModeArtwork(widget.mode, width: 158, height: 121),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 26),
            const SectionHeading(
              'Your little journey',
              subtitle:
                  'Complete a level to unlock the next. Revisit any discovery.',
            ),
            if (categories.length > 1) ...[
              SizedBox(
                height: MediaQuery.textScalerOf(context).scale(24) + 25,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: const Text('All'),
                        selected: _category == null,
                        onSelected: (_) => setState(() => _category = null),
                      ),
                    ),
                    for (final category in categories)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(category),
                          selected: _category == category,
                          onSelected: (_) =>
                              setState(() => _category = category),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 880
                    ? 4
                    : constraints.maxWidth >= 650
                    ? 3
                    : constraints.maxWidth >= 320
                    ? 2
                    : 1;
                final cellWidth =
                    (constraints.maxWidth - 14 * (columns - 1)) / columns;
                final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: visible.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    mainAxisExtent:
                        (widget.mode.isScene ? cellWidth * .67 + 112 : 179) +
                        (scale - 1) * 78,
                  ),
                  itemBuilder: (context, index) {
                    final puzzle = visible[index];
                    final record = state.progress.records[puzzle.id];
                    final unlocked = services.content.isUnlocked(puzzle);
                    return _LevelCard(
                      puzzle: puzzle,
                      unlocked: unlocked,
                      stars: record?.stars ?? 0,
                      onTap: () {
                        if (!unlocked) {
                          final previous = levels[levels.indexOf(puzzle) - 1];
                          showMessage(
                            context,
                            'Complete level ${previous.level} to unlock this discovery.',
                          );
                          return;
                        }
                        launchPuzzle(context, ref, puzzle);
                      },
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 25),
            const Center(child: OfflineNote()),
          ],
        ),
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.puzzle,
    required this.unlocked,
    required this.stars,
    required this.onTap,
  });
  final Puzzle puzzle;
  final bool unlocked;
  final int stars;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    label:
        'Level ${puzzle.level}, ${puzzle.title}, ${unlocked ? puzzle.difficultyLabel : 'locked'}',
    button: true,
    child: SoftCard(
      key: ValueKey('level-${puzzle.id}'),
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (puzzle.scene != null)
                  Opacity(
                    opacity: unlocked ? 1 : .55,
                    child: Image.asset(
                      puzzle.imageA ?? '',
                      fit: BoxFit.cover,
                      cacheWidth: 420,
                      errorBuilder: (_, _, _) =>
                          CustomPaint(painter: ScenePainter(puzzle.scene!)),
                    ),
                  )
                else
                  Container(
                    color: FindItColors.modeBackground(puzzle.mode),
                    child: Center(
                      child: ModeArtwork(puzzle.mode, width: 103, height: 77),
                    ),
                  ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: FindItColors.paper.withValues(alpha: .94),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      puzzle.level.toString().padLeft(2, '0'),
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                if (!unlocked)
                  const Center(
                    child: IconBadge(
                      Icons.lock_outline_rounded,
                      background: FindItColors.paper,
                      color: FindItColors.muted,
                      size: 43,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  puzzle.title.split(' · ').first,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  '${puzzle.category} · ${puzzle.difficultyLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: FindItColors.muted),
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    Stars(stars),
                    const Spacer(),
                    if (unlocked)
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: FindItColors.forest,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
