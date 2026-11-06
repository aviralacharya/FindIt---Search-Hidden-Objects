import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/art/brand_art.dart';
import '../core/config/app_config.dart';
import 'app_services.dart';
import 'router.dart';
import 'theme.dart';

class FindItApp extends ConsumerStatefulWidget {
  const FindItApp({super.key});
  @override
  ConsumerState<FindItApp> createState() => _FindItAppState();
}

class _FindItAppState extends ConsumerState<FindItApp>
    with WidgetsBindingObserver {
  static bool _licensesRegistered = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!_licensesRegistered) {
      _licensesRegistered = true;
      LicenseRegistry.addLicense(() async* {
        for (final family in ['Outfit', 'Nunito']) {
          yield LicenseEntryWithLineBreaks([
            family,
          ], await rootBundle.loadString('assets/legal/$family-OFL.txt'));
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(
      ref
          .read(servicesProvider)
          .setForeground(state == AppLifecycleState.resumed),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: AppConfig.name,
    debugShowCheckedModeBanner: false,
    theme: buildFindItTheme(),
    routerConfig: ref.watch(routerProvider),
  );
}

/// Startup performs only local work, with no mandatory onboarding, consent
/// dialog, or artificial splash delay. Failed storage is reported, not replaced
/// with a silently ephemeral in-memory game.
class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});
  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  late Future<AppServices> _future;
  AppServices? _services;
  @override
  void initState() {
    super.initState();
    _future = _create();
  }

  Future<AppServices> _create() async {
    final services = await AppServices.create();
    if (!mounted) {
      await services.close();
    } else {
      _services = services;
    }
    return services;
  }

  @override
  void dispose() {
    if (_services != null) unawaited(_services!.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<AppServices>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        return ProviderScope(
          overrides: [servicesProvider.overrideWithValue(snapshot.data!)],
          child: const FindItApp(),
        );
      }
      return MaterialApp(
        title: AppConfig.name,
        debugShowCheckedModeBanner: false,
        theme: buildFindItTheme(),
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const FindItMark(size: 76),
                      const SizedBox(height: 24),
                      Text(
                        'FindIt',
                        style: buildFindItTheme().textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 14),
                      if (!snapshot.hasError) ...[
                        const Text('A little world of discoveries.'),
                        const SizedBox(height: 28),
                        const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ] else ...[
                        const Text(
                          'Reliable local storage couldn’t be opened.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Try again after freeing device storage. For the web preview, use a normal browser window with local storage allowed. FindIt won’t silently discard your saved progress.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: FindItColors.muted,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: () => setState(() => _future = _create()),
                          child: const Text('Try again'),
                        ),
                        if (kDebugMode) ...[
                          const SizedBox(height: 20),
                          Text(
                            snapshot.error.toString(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11,
                              color: FindItColors.muted,
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
