import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_services.dart';
import '../../app/theme.dart';
import '../../core/domain/progress.dart';
import '../../core/domain/puzzle.dart';
import '../../ui/widgets/common.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);
    final services = ref.read(servicesProvider);
    final progress = state.progress;
    final bests = progress.records.values.toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    return PageContent(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('LITTLE FINDS. BIG LITTLE FEELINGS.'),
          const SizedBox(height: 12),
          Text(
            'Look how far you’ve come.',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 10),
          Text(
            'Your very own collection of discoveries. No leaderboards, no comparisons. Just your personal best.',
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: FindItColors.muted),
          ),
          const SizedBox(height: 26),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 600 ? 4 : 2;
              final stats = [
                _ProgressStat(
                  '${progress.completedLevels}',
                  'Levels discovered',
                  Icons.search_rounded,
                ),
                _ProgressStat(
                  '${progress.totalStars}',
                  'Little stars earned',
                  Icons.star_outline_rounded,
                ),
                _ProgressStat(
                  '${progress.earnedCoins}',
                  'Coins earned',
                  Icons.stars_outlined,
                ),
                _ProgressStat(
                  '${progress.currentStreak(DateTime.now())}',
                  'Daily streak',
                  Icons.local_fire_department_outlined,
                ),
              ];
              // Four small cards can size to their text instead of guessing a
              // fixed grid height. Rows stay aligned at large accessibility sizes.
              return Column(
                children: [
                  for (var row = 0; row < stats.length; row += columns) ...[
                    if (row > 0) const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 155),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var i = row; i < row + columns; i++) ...[
                              if (i > row) const SizedBox(width: 12),
                              Expanded(child: stats[i]),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 32),
          const SectionHeading(
            'Your discovery journal',
            subtitle: 'A little more curious, one level at a time.',
          ),
          SoftCard(
            child: Column(
              children: [
                for (final mode in [GameMode.hidden]) ...[
                  _ModeProgress(
                    mode: mode,
                    completed: progress.completedFor(mode),
                    total: services.content.forMode(mode).length,
                    stars: progress.starsFor(mode),
                    onTap: () => context.push('/mode/${mode.slug}'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 32),
          const SectionHeading(
            'Little milestones',
            subtitle: 'Eight lovely reasons to feel a little proud.',
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 750
                  ? 3
                  : constraints.maxWidth >= 410
                  ? 2
                  : 1;
              final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: progress.achievements.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent: 192 + (scale - 1) * 102,
                ),
                itemBuilder: (context, index) => _AchievementCard(
                  progress.achievements[index],
                  index: index,
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          const SectionHeading(
            'Your personal bests',
            subtitle: 'Best score, fastest finish, and most accurate finds for each puzzle.',
          ),
          if (bests.isEmpty)
            SoftCard(
              child: EmptyState(
                title: 'A blank page, full of possibilities.',
                message: 'Your first discovery will start your story here.',
                action: FilledButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Find my first puzzle'),
                ),
              ),
            )
          else
            SoftCard(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  for (final record in bests.take(20))
                    _PersonalBest(
                      record,
                      title:
                          services.content.find(record.id)?.title ?? record.id,
                      onTap: () {
                        final puzzle = services.content.find(record.id);
                        if (puzzle != null) {
                          String? day;
                          if (record.daily) {
                            day = progress.daily.values
                                .where(
                                  (d) =>
                                      d.puzzles.any((p) => p.id == record.id),
                                )
                                .firstOrNull
                                ?.dayKey;
                          }
                          launchPuzzle(context, ref, puzzle, dailyKey: day);
                        }
                      },
                    ),
                  if (bests.length > 20)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Showing 20 of ${bests.length} saved personal bests. Each level card also shows its best stars.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: FindItColors.muted),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          const Center(child: OfflineNote()),
        ],
      ),
    );
  }
}

class _ProgressStat extends StatelessWidget {
  const _ProgressStat(this.value, this.label, this.icon);
  final String value;
  final String label;
  final IconData icon;
  @override
  Widget build(BuildContext context) => SoftCard(
    padding: const EdgeInsets.all(18),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: FindItColors.forest, size: 23),
        const SizedBox(height: 13),
        Text(value, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 5),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: FindItColors.muted),
        ),
      ],
    ),
  );
}

class _ModeProgress extends StatelessWidget {
  const _ModeProgress({
    required this.mode,
    required this.completed,
    required this.total,
    required this.stars,
    required this.onTap,
  });
  final GameMode mode;
  final int completed;
  final int total;
  final int stars;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Row(
      children: [
        IconBadge(
          modeIcon(mode),
          color: FindItColors.modeInk(mode),
          background: FindItColors.modeBackground(mode),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      mode.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$completed/$total',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 9),
              LinearProgressIndicator(
                value: completed / total,
                minHeight: 4,
                color: FindItColors.modeInk(mode),
              ),
              const SizedBox(height: 6),
              Text(
                '$stars little stars collected',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: FindItColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        const Icon(Icons.chevron_right_rounded, color: FindItColors.muted),
      ],
    ),
  );
}

const _achievementIcons = [
  Icons.search_rounded,
  Icons.lightbulb_outline_rounded,
  Icons.visibility_outlined,
  Icons.explore_outlined,
  Icons.style_outlined,
  Icons.bolt_rounded,
  Icons.calendar_today_outlined,
  Icons.stars_outlined,
];

class _AchievementCard extends StatelessWidget {
  const _AchievementCard(this.achievement, {required this.index});
  final Achievement achievement;
  final int index;
  @override
  Widget build(BuildContext context) => SoftCard(
    color: achievement.unlocked ? const Color(0xFFEEF2E7) : FindItColors.paper,
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconBadge(
              _achievementIcons[index],
              size: 38,
              background: achievement.unlocked
                  ? const Color(0xFFDDE8D3)
                  : FindItColors.cream,
              color: achievement.unlocked
                  ? FindItColors.forest
                  : FindItColors.muted,
            ),
            const Spacer(),
            if (achievement.unlocked)
              const Icon(
                Icons.check_circle_rounded,
                color: FindItColors.forest,
                size: 19,
              )
            else
              Text(
                '${achievement.current.clamp(0, achievement.goal)}/${achievement.goal}',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: FindItColors.muted),
              ),
          ],
        ),
        const SizedBox(height: 13),
        Text(achievement.title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 5),
        Expanded(
          child: Text(
            achievement.description,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: FindItColors.muted),
          ),
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: achievement.progress,
          minHeight: 3,
          color: achievement.unlocked
              ? FindItColors.forest
              : const Color(0xFFB6C8AA),
        ),
      ],
    ),
  );
}

class _PersonalBest extends StatelessWidget {
  const _PersonalBest(this.record, {required this.title, required this.onTap});
  final LevelRecord record;
  final String title;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    leading: IconBadge(
      modeIcon(record.mode),
      size: 38,
      background: FindItColors.modeBackground(record.mode),
      color: FindItColors.modeInk(record.mode),
    ),
    title: Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.titleSmall,
    ),
    subtitle: Text(
      '${record.bestScore} pts · ${formatTime(record.bestElapsedMs)} · ${(record.accuracy * 100).round()}% accuracy',
      style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: FindItColors.muted),
    ),
    trailing: Stars(record.stars, size: 15),
  );
}
