import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/domain/puzzle.dart';
import '../features/daily/daily_screen.dart';
import '../features/game/game_screen.dart';
import '../features/home/home_screen.dart';
import '../features/levels/levels_screen.dart';
import '../features/progress/progress_screen.dart';
import '../features/settings/about_screen.dart';
import '../features/settings/packs_screen.dart';
import '../features/settings/privacy_screen.dart';
import '../features/settings/settings_screen.dart';
import '../ui/widgets/app_shell.dart';
import '../ui/widgets/common.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
          GoRoute(path: '/daily', builder: (_, _) => const DailyScreen()),
          GoRoute(path: '/progress', builder: (_, _) => const ProgressScreen()),
          GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
        ],
      ),
      GoRoute(
        path: '/mode/:mode',
        builder: (context, state) {
          final mode = GameMode.values
              .where((m) => m.slug == state.pathParameters['mode'])
              .firstOrNull;
          return mode != GameMode.hidden
              ? const _NotFound()
              : const LevelsScreen(mode: GameMode.hidden);
        },
      ),
      GoRoute(
        path: '/play/:id',
        builder: (_, state) => GameScreen(
          key: ValueKey(state.uri.toString()),
          puzzleId: state.pathParameters['id']!,
          dailyKey: state.uri.queryParameters['daily'],
          resume: state.uri.queryParameters['resume'] == '1',
        ),
      ),
      GoRoute(path: '/privacy', builder: (_, _) => const PrivacyScreen()),
      GoRoute(path: '/packs', builder: (_, _) => const PacksScreen()),
      GoRoute(path: '/about', builder: (_, _) => const AboutScreen()),
    ],
    errorBuilder: (_, _) => const _NotFound(),
  );
  ref.onDispose(router.dispose);
  return router;
});

class _NotFound extends StatelessWidget {
  const _NotFound();
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: EmptyState(
        title: 'A little off the beaten path.',
        message: 'That page isn’t part of your installed collection.',
        action: FilledButton(
          onPressed: () => context.go('/'),
          child: const Text('Back to play'),
        ),
      ),
    ),
  );
}
