import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_services.dart';
import '../../app/theme.dart';
import '../../core/art/brand_art.dart';
import '../../core/domain/daily_challenge.dart';
import '../../core/domain/puzzle.dart';
import '../../ui/widgets/common.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);
    final services = ref.read(servicesProvider);
    final progress = state.progress;
    final daily = progress.daily[localDayKey(DateTime.now())];
    return PageContent(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 740;
          final compact = constraints.maxWidth < 500;
          final hero = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Eyebrow('HIDDEN OBJECTS. LITTLE ADVENTURES.'),
              const SizedBox(height: 14),
              Text(
                'Look closer.\nA little wonder awaits.',
                style: compact
                    ? Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(fontSize: 33)
                    : Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Text(
                  'Explore colorful places, spot the objects on your list, and enjoy the simple delight of finding. No ads. No sign-up. No rush.',
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(color: FindItColors.muted),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                key: const ValueKey('start-discovery'),
                onPressed: () {
                  final puzzle = services.content
                      .forMode(GameMode.hidden)
                      .firstWhere(
                        (p) =>
                            services.content.isUnlocked(p) &&
                            !progress.records.containsKey(p.id),
                        orElse: () =>
                            services.content.forMode(GameMode.hidden).first,
                      );
                  launchPuzzle(context, ref, puzzle);
                },
                icon: const Icon(Icons.search_rounded, size: 20),
                label: const Text('Start searching'),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 17,
                runSpacing: 8,
                children: [
                  _LittleFeature(
                    Icons.cloud_off_rounded,
                    '${state.puzzleCount} offline search levels',
                  ),
                  const _LittleFeature(
                    Icons.favorite_border_rounded,
                    'No sign-up. Just play.',
                  ),
                ],
              ),
            ],
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(flex: 6, child: hero),
                    const SizedBox(width: 36),
                    Expanded(
                      flex: 4,
                      child: _DailyInvitation(
                        completed: daily?.completed ?? false,
                        done: daily?.completedIds.length ?? 0,
                        streak: progress.currentStreak(DateTime.now()),
                      ),
                    ),
                  ],
                )
              else ...[
                hero,
                const SizedBox(height: 28),
                _DailyInvitation(
                  completed: daily?.completed ?? false,
                  done: daily?.completedIds.length ?? 0,
                  streak: progress.currentStreak(DateTime.now()),
                  compact: true,
                ),
              ],
              for (final notice in [
                state.settingsRecoveryNotice,
                progress.savedGameError,
              ].whereType<String>()) ...[
                const SizedBox(height: 20),
                SoftCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const IconBadge(Icons.warning_amber_rounded),
                      const SizedBox(width: 14),
                      Expanded(child: Text(notice)),
                    ],
                  ),
                ),
              ],
              if (progress.savedGame != null &&
                  (progress.savedGame!.engineJson['puzzle'] as Map)['mode'] ==
                      GameMode.hidden.slug) ...[
                const SizedBox(height: 28),
                _ContinueCard(
                  onTap: () {
                    final saved = progress.savedGame!;
                    final puzzle = services.content.find(saved.puzzleId);
                    if (puzzle != null) {
                      launchPuzzle(
                        context,
                        ref,
                        puzzle,
                        dailyKey: saved.dailyKey,
                        resume: true,
                      );
                    }
                  },
                  title:
                      (progress.savedGame!.engineJson['puzzle']
                              as Map<String, dynamic>)['title']
                          as String,
                ),
              ],
              const SizedBox(height: 38),
              SectionHeading(
                'Where will you search?',
                subtitle: compact
                    ? 'Three colorful places to begin your journey.'
                    : 'Your first three adventures. Familiar objects, wonderfully hidden.',
                trailing: compact
                    ? null
                    : Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: FindItColors.paper,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: FindItColors.line),
                        ),
                        child: const Eyebrow('FEATURED SCENES'),
                      ),
              ),
              Builder(
                builder: (context) {
                  final columns = constraints.maxWidth >= 760
                      ? 3
                      : constraints.maxWidth >= 500
                      ? 2
                      : 1;
                  final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
                  // Large text needs the full card width instead of a narrow
                  // text column beside the picture, especially on small phones.
                  final horizontal = columns == 1 && scale <= 1.3;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 3,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      mainAxisExtent: horizontal
                          ? 176 + (scale - 1) * 90
                          : 285 + (scale - 1) * 90,
                    ),
                    itemBuilder: (context, index) {
                      const mode = GameMode.hidden;
                      final puzzle = services.content.forMode(mode)[index];
                      final unlocked = services.content.isUnlocked(puzzle);
                      return _ModeCard(
                        mode: mode,
                        puzzle: puzzle,
                        unlocked: unlocked,
                        stars: progress.records[puzzle.id]?.stars ?? 0,
                        total: 1,
                        completed: progress.records.containsKey(puzzle.id)
                            ? 1
                            : 0,
                        horizontal: horizontal,
                        onTap: () {
                          if (!unlocked) {
                            showMessage(
                              context,
                              'Complete level ${puzzle.level - 1} to unlock this scene.',
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
              const SizedBox(height: 20),
              OutlinedButton.icon(
                key: const ValueKey('browse-hidden-levels'),
                onPressed: () => context.push('/mode/hidden'),
                icon: const Icon(Icons.travel_explore_rounded),
                label: Text(
                  'Explore all ${state.puzzleCount} hidden-object levels',
                ),
              ),
              const SizedBox(height: 26),
              Center(
                child: Text(
                  'A little challenge for your eyes. A little calm for your day.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: FindItColors.muted),
                ),
              ),
              const SizedBox(height: 14),
            ],
          );
        },
      ),
    );
  }
}

class _LittleFeature extends StatelessWidget {
  const _LittleFeature(this.icon, this.label);
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 15, color: FindItColors.forest),
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: FindItColors.muted),
        ),
      ),
    ],
  );
}

class _DailyInvitation extends StatelessWidget {
  const _DailyInvitation({
    required this.completed,
    required this.done,
    required this.streak,
    this.compact = false,
  });
  final bool completed;
  final int done;
  final int streak;
  final bool compact;
  @override
  Widget build(BuildContext context) => SoftCard(
    key: const ValueKey('daily-invitation'),
    color: const Color(0xFFE9EEDF),
    border: false,
    padding: const EdgeInsets.all(24),
    onTap: () => context.go('/daily'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Eyebrow(
                    'A LITTLE SOMETHING FOR TODAY',
                    color: FindItColors.forest,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    completed
                        ? 'Today, beautifully done.'
                        : 'Your daily adventure',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  if (compact) ...[
                    const SizedBox(height: 6),
                    Text(
                      completed
                          ? 'Come back tomorrow for three fresh puzzles.'
                          : '3 fresh puzzles. One lovely reward.',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: FindItColors.muted),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            ModeArtwork(
              GameMode.daily,
              width: compact ? 66 : 91,
              height: compact ? 57 : 78,
            ),
          ],
        ),
        if (!compact) ...[
          const SizedBox(height: 12),
          Text(
            completed
                ? 'You earned your daily bonus. A fresh set arrives tomorrow.'
                : 'Three fresh puzzles, a moment of focus, and 60 bonus coins when you finish.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: FindItColors.muted),
          ),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            for (var i = 0; i < 3; i++) ...[
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: i < done
                      ? FindItColors.forest
                      : Colors.white.withValues(alpha: .65),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  i < done ? Icons.check_rounded : Icons.circle_outlined,
                  size: i < done ? 16 : 10,
                  color: i < done ? Colors.white : FindItColors.forest,
                ),
              ),
              const SizedBox(width: 6),
            ],
            const Spacer(),
            Flexible(
              child: Text(
                completed ? 'View today' : 'Let’s play',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: FindItColors.forest,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.arrow_forward_rounded,
              size: 17,
              color: FindItColors.forest,
            ),
          ],
        ),
        if (streak > 0 && !compact) ...[
          const SizedBox(height: 14),
          Text(
            '$streak-day streak · keep your curiosity growing',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: FindItColors.forest),
          ),
        ],
      ],
    ),
  );
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.mode,
    required this.total,
    required this.completed,
    required this.onTap,
    this.horizontal = false,
    this.puzzle,
    this.unlocked = true,
    this.stars = 0,
  });
  final GameMode mode;
  final int total;
  final int completed;
  final VoidCallback onTap;
  final bool horizontal;
  final Puzzle? puzzle;
  final bool unlocked;
  final int stars;
  @override
  Widget build(BuildContext context) {
    if (puzzle != null) {
      final scene = puzzle!;
      final picture = Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(scene.imageA!, fit: BoxFit.cover),
          if (!unlocked)
            const Positioned(
              top: 10,
              right: 10,
              child: IconBadge(
                Icons.lock_outline_rounded,
                size: 34,
                background: FindItColors.paper,
              ),
            ),
        ],
      );
      final details = Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Eyebrow('LEVEL ${scene.level} · ${scene.category.toUpperCase()}'),
            const SizedBox(height: 7),
            Text(
              scene.title.split(' · ').first,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              '${scene.totalAnswers} objects · ${scene.difficultyLabel}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Stars(stars),
          ],
        ),
      );
      return SoftCard(
        key: ValueKey('featured-${scene.id}'),
        padding: EdgeInsets.zero,
        onTap: onTap,
        child: horizontal
            ? Row(
                children: [
                  Expanded(flex: 4, child: picture),
                  Expanded(flex: 6, child: details),
                ],
              )
            : Column(
                children: [
                  Expanded(child: picture),
                  details,
                ],
              ),
      );
    }
    final color = FindItColors.modeInk(mode);
    final showSideArtwork = MediaQuery.textScalerOf(context).scale(14) <= 20;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Eyebrow(mode.eyebrow, color: color)),
            const SizedBox(width: 6),
            Icon(Icons.north_east_rounded, size: 16, color: color),
          ],
        ),
        const SizedBox(height: 10),
        if (!horizontal)
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: ModeArtwork(mode, width: 105, height: 76),
            ),
          ),
        Text(
          mode.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontSize: horizontal ? 21 : 18),
        ),
        const SizedBox(height: 7),
        Text(
          mode == GameMode.daily
              ? '$completed of 3 discoveries today'
              : '$total levels · ${completed == 0 ? 'Ready when you are' : '$completed complete'}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
        ),
        const SizedBox(height: 13),
        ExcludeSemantics(
          child: LinearProgressIndicator(
            value: completed / total,
            minHeight: 3,
            color: color,
            backgroundColor: Colors.white.withValues(alpha: .65),
          ),
        ),
      ],
    );
    return SoftCard(
      key: ValueKey('mode-${mode.slug}'),
      color: FindItColors.modeBackground(mode),
      border: false,
      padding: const EdgeInsets.all(18),
      onTap: onTap,
      child: horizontal
          ? Row(
              children: [
                Expanded(child: content),
                if (showSideArtwork) ...[
                  const SizedBox(width: 14),
                  ModeArtwork(mode, width: 110, height: 90),
                ],
              ],
            )
          : content,
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.title, required this.onTap});
  final String title;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SoftCard(
    onTap: onTap,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    child: Row(
      children: [
        const IconBadge(Icons.bookmark_outline_rounded),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pick up your last discovery',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: FindItColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        const Icon(Icons.arrow_forward_rounded, color: FindItColors.forest),
      ],
    ),
  );
}
