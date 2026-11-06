import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_services.dart';
import '../../app/theme.dart';
import '../../core/art/brand_art.dart';
import '../../core/domain/daily_challenge.dart';
import '../../core/domain/puzzle.dart';
import '../../ui/widgets/common.dart';

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

class DailyScreen extends ConsumerStatefulWidget {
  const DailyScreen({super.key});
  @override
  ConsumerState<DailyScreen> createState() => _DailyScreenState();
}

class _DailyScreenState extends ConsumerState<DailyScreen> {
  Timer? _timer;
  String _day = localDayKey(DateTime.now());
  String? _error;
  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      final key = localDayKey(DateTime.now());
      if (key != _day) {
        _day = key;
        _refresh();
      }
      setState(() {});
    });
  }

  Future<void> _refresh() async {
    try {
      await ref.read(servicesProvider).ensureDaily(DateTime.now());
      if (mounted) setState(() => _error = null);
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = 'Today’s puzzles could not be saved. Please try again.',
        );
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final now = DateTime.now();
    final day = state.progress.daily[localDayKey(now)];
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final remaining = tomorrow.difference(now);
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    final next = day?.puzzles
        .where((p) => !day.completedIds.contains(p.id))
        .firstOrNull;
    return PageContent(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('A NEW DAY. A FRESH PERSPECTIVE.'),
          const SizedBox(height: 12),
          Text(
            'Your daily adventure',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 8),
          Text(
            '${_weekdays[now.weekday - 1]}, ${_months[now.month - 1]} ${now.day} · three little discoveries, just for today.',
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: FindItColors.muted),
          ),
          const SizedBox(height: 26),
          SoftCard(
            color: const Color(0xFFE9EEDF),
            border: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 500;
                final text = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Eyebrow(
                      day?.completed == true
                          ? 'BEAUTIFULLY DONE'
                          : 'YOUR CURIOSITY, REWARDED',
                      color: FindItColors.forest,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      day?.completed == true
                          ? 'A lovely little accomplishment.'
                          : 'Three puzzles. One delightful bonus.',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      day?.completed == true
                          ? 'Your 60-coin bonus is safely saved. Come back for a new set tomorrow.'
                          : 'Search today’s home, garden, and café scenes. Find every listed object in all three to collect 60 bonus coins.',
                      style: Theme.of(context).textTheme.bodyLarge
                          ?.copyWith(color: FindItColors.muted),
                    ),
                    const SizedBox(height: 22),
                    if (next != null)
                      FilledButton.icon(
                        key: const ValueKey('daily-start'),
                        onPressed: () => launchPuzzle(
                          context,
                          ref,
                          next,
                          dailyKey: day.dayKey,
                        ),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text(
                          day!.completedIds.isEmpty
                              ? 'Let’s begin'
                              : 'Continue today’s journey',
                        ),
                      )
                    else
                      Row(
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            color: FindItColors.forest,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'All three discoveries complete',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(color: FindItColors.forest),
                            ),
                          ),
                        ],
                      ),
                  ],
                );
                return Row(
                  children: [
                    Expanded(child: text),
                    if (!narrow) ...[
                      const SizedBox(width: 28),
                      const ModeArtwork(
                        GameMode.daily,
                        width: 165,
                        height: 150,
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _DailyStat(
                Icons.local_fire_department_outlined,
                '${state.progress.currentStreak(now)}-day streak',
                'A little habit, growing',
              ),
              _DailyStat(
                Icons.auto_awesome_outlined,
                '${state.progress.bestStreak}-day best',
                'Your longest little journey',
              ),
              _DailyStat(
                Icons.schedule_rounded,
                '${hours}h ${minutes}m',
                'Until the next fresh set',
              ),
            ],
          ),
          const SizedBox(height: 30),
          const SectionHeading(
            'Today’s three discoveries',
            subtitle: 'Play in any order. Your place is saved automatically.',
          ),
          if (_error != null)
            SoftCard(
              child: Column(
                children: [
                  Text(_error!),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _refresh,
                    child: const Text('Try again'),
                  ),
                ],
              ),
            )
          else if (day == null)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: CircularProgressIndicator(),
              ),
            )
          else ...[
            for (var i = 0; i < day.puzzles.length; i++) ...[
              _DailyPuzzleCard(
                puzzle: day.puzzles[i],
                number: i + 1,
                completed: day.completedIds.contains(day.puzzles[i].id),
                stars: state.progress.records[day.puzzles[i].id]?.stars ?? 0,
                onTap: () => launchPuzzle(
                  context,
                  ref,
                  day.puzzles[i],
                  dailyKey: day.dayKey,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
          const SizedBox(height: 20),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Small moments add up',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  'Your last seven days of curiosity.',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: FindItColors.muted),
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var i = 6; i >= 0; i--)
                      Builder(
                        builder: (context) {
                          final date = DateTime(
                            now.year,
                            now.month,
                            now.day - i,
                          );
                          final done =
                              state
                                  .progress
                                  .daily[localDayKey(date)]
                                  ?.bonusClaimed ??
                              false;
                          return Flexible(
                            child: Column(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: done
                                        ? FindItColors.forest
                                        : FindItColors.sage,
                                    shape: BoxShape.circle,
                                    border: i == 0
                                        ? Border.all(
                                            color: FindItColors.forest,
                                            width: 1.5,
                                          )
                                        : null,
                                  ),
                                  child: Icon(
                                    done
                                        ? Icons.check_rounded
                                        : Icons.circle_outlined,
                                    size: done ? 18 : 9,
                                    color: done
                                        ? Colors.white
                                        : FindItColors.muted,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  i == 0
                                      ? 'Today'
                                      : _weekdays[date.weekday - 1],
                                  maxLines: 1,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        fontSize: 10,
                                        color: i == 0
                                            ? FindItColors.forest
                                            : FindItColors.muted,
                                      ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Daily puzzles use the date on your device and work offline. Bonuses are awarded once per date; replaying is always welcome.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: FindItColors.muted),
          ),
        ],
      ),
    );
  }
}

class _DailyStat extends StatelessWidget {
  const _DailyStat(this.icon, this.value, this.label);
  final IconData icon;
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => SoftCard(
    padding: const EdgeInsets.all(18),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: FindItColors.forest, size: 22),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: FindItColors.muted),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _DailyPuzzleCard extends StatelessWidget {
  const _DailyPuzzleCard({
    required this.puzzle,
    required this.number,
    required this.completed,
    required this.stars,
    required this.onTap,
  });
  final Puzzle puzzle;
  final int number;
  final bool completed;
  final int stars;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SoftCard(
    onTap: onTap,
    padding: const EdgeInsets.all(19),
    child: Row(
      children: [
        Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            color: FindItColors.modeBackground(puzzle.mode),
            borderRadius: BorderRadius.circular(17),
          ),
          child: ModeArtwork(puzzle.mode, width: 62, height: 56),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Eyebrow(
                'DISCOVERY 0$number · ${puzzle.difficultyLabel.toUpperCase()}',
              ),
              const SizedBox(height: 6),
              Text(
                puzzle.mode.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 5),
              if (completed)
                Stars(stars)
              else
                Text(
                  puzzle.title,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: FindItColors.muted),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Icon(
          completed ? Icons.check_circle_rounded : Icons.arrow_forward_rounded,
          color: FindItColors.forest,
          size: completed ? 25 : 20,
        ),
      ],
    ),
  );
}
