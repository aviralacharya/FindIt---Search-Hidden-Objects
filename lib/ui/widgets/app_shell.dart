import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_services.dart';
import '../../app/theme.dart';
import '../../core/art/brand_art.dart';
import 'common.dart';

const _destinations = <(String, String, IconData)>[
  ('/', 'Play', Icons.search_rounded),
  ('/daily', 'Daily', Icons.calendar_today_outlined),
  ('/progress', 'Progress', Icons.auto_awesome_outlined),
  ('/settings', 'Settings', Icons.tune_rounded),
];

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);
    final path = GoRouterState.of(context).uri.path;
    final selected = _destinations.indexWhere((d) => d.$1 == path);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1000;
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: Row(
              children: [
                if (wide) _Sidebar(selected: selected),
                Expanded(
                  child: Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          wide ? 36 : 20,
                          18,
                          wide ? 36 : 20,
                          10,
                        ),
                        child: Row(
                          children: [
                            if (!wide)
                              const Expanded(child: _Wordmark())
                            else ...[
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: FindItColors.forest,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Find little treasures. Leave the rush behind.',
                                style: TextStyle(
                                  color: FindItColors.muted,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                            if (wide)
                              const Spacer()
                            else
                              const SizedBox(width: 12),
                            CoinPill(state.progress.coins),
                          ],
                        ),
                      ),
                      Expanded(child: child),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: wide
              ? null
              : SafeArea(
                  top: false,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: FindItColors.paper,
                      border: Border(top: BorderSide(color: FindItColors.line)),
                    ),
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    child: Row(
                      children: [
                        for (var i = 0; i < _destinations.length; i++)
                          Expanded(
                            child: _NavigationItem(
                              index: i,
                              selected: i == selected,
                              compact: true,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();
  @override
  Widget build(BuildContext context) => const Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      FindItMark(size: 33),
      SizedBox(width: 9),
      Flexible(
        child: Text(
          'FindIt',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 26,
            fontWeight: FontWeight.w600,
            letterSpacing: -1,
            color: FindItColors.ink,
          ),
        ),
      ),
    ],
  );
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.selected});
  final int selected;
  @override
  Widget build(BuildContext context) => Container(
    width: 218,
    decoration: const BoxDecoration(
      color: FindItColors.paper,
      border: Border(right: BorderSide(color: FindItColors.line)),
    ),
    padding: const EdgeInsets.fromLTRB(24, 27, 18, 25),
    // Keep the footer low on roomy screens, but let enlarged text and short
    // windows scroll instead of overflowing a fixed-height sidebar.
    child: LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Wordmark(),
                const SizedBox(height: 7),
                const Padding(
                  padding: EdgeInsets.only(left: 2),
                  child: Text(
                    'Search Hidden Objects',
                    style: TextStyle(color: FindItColors.muted, fontSize: 11),
                  ),
                ),
                const SizedBox(height: 55),
                const Eyebrow('YOUR LITTLE CORNER'),
                const SizedBox(height: 14),
                for (var i = 0; i < _destinations.length; i++) ...[
                  _NavigationItem(index: i, selected: selected == i),
                  const SizedBox(height: 8),
                ],
                const Spacer(),
                SoftCard(
                  color: FindItColors.cream,
                  padding: const EdgeInsets.all(17),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.cloud_off_rounded,
                        color: FindItColors.forest,
                        size: 22,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Your offline escape',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'No accounts. No rush.\nJust you and a good puzzle.',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: FindItColors.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const Padding(
                  padding: EdgeInsets.only(left: 2),
                  child: Eyebrow('LOOK CLOSELY. STAY CURIOUS.'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.index,
    required this.selected,
    this.compact = false,
  });
  final int index;
  final bool selected;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final destination = _destinations[index];
    final color = selected ? FindItColors.forest : FindItColors.muted;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? FindItColors.sage : Colors.transparent,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          key: ValueKey('nav-${destination.$2.toLowerCase()}'),
          borderRadius: BorderRadius.circular(15),
          onTap: () => context.go(destination.$1),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 4 : 14,
              vertical: compact ? 10 : 15,
            ),
            child: compact
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(destination.$3, size: 21, color: color),
                      const SizedBox(height: 5),
                      Text(
                        destination.$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Icon(destination.$3, size: 21, color: color),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          destination.$2,
                          style: TextStyle(
                            color: color,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (selected)
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
