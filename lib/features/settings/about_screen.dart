import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/art/brand_art.dart';
import '../../core/config/app_config.dart';
import '../../ui/widgets/common.dart';
import 'developer_details.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        tooltip: 'Back to settings',
        onPressed: () => context.go('/settings'),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      title: const Text('A little about FindIt'),
    ),
    body: PageContent(
      maxWidth: 740,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const Center(child: FindItMark(size: 86)),
          const SizedBox(height: 20),
          Center(
            child: Text(
              AppConfig.name,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displaySmall,
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              AppConfig.tagline,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: FindItColors.muted),
            ),
          ),
          const SizedBox(height: 28),
          const SoftCard(
            child: Text(
              'A dedicated hidden-object game with 60 offline levels. Start in a sunlit home, a secret garden, and a corner café, then explore the wider collection. The search engine and 57 classic scenes are reused from FindIt; the three featured scenes and scene-first layout are enhanced for this independent app. Daily adventures contain only hidden-object searches. No ads, accounts, or subscriptions. Your progress stays on your device.',
            ),
          ),
          const SizedBox(height: 20),
          const SoftCard(padding: EdgeInsets.all(8), child: DeveloperDetails()),
          const SizedBox(height: 20),
          Text(
            'Original little details',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          const Text(
            'The original FindIt vector glyphs, brand mark, fonts, and synthesized audio are reused with their provenance and license records. Three new layered, colorful featured compositions were created for this hidden-object project. The artwork is illustrated, not photographic. Editable artwork sources and reuse records are included.',
          ),
          const SizedBox(height: 22),
          Text(
            'Built with a little help',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          const Text(
            'Built in Flutter, with local SQLite saves through Drift. Outfit and Nunito are bundled under the SIL Open Font License. Licenses for FindIt’s open-source packages are available below. No advertising or consent SDK is included.',
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => showLicensePage(
              context: context,
              applicationName: AppConfig.name,
              applicationVersion: AppConfig.version,
              applicationIcon: const Padding(
                padding: EdgeInsets.all(18),
                child: FindItMark(size: 52),
              ),
            ),
            icon: const Icon(Icons.code_rounded, size: 19),
            label: const Text('Open-source licenses'),
          ),
          const SizedBox(height: 14),
          TextButton(
            onPressed: () => context.push('/privacy'),
            child: const Text('Privacy & local data'),
          ),
          const SizedBox(height: 28),
          Center(
            child: Text(
              'Version ${AppConfig.version}${AppConfig.production ? '' : ' · development build'}',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: FindItColors.muted),
            ),
          ),
          const SizedBox(height: 12),
          const Center(child: OfflineNote()),
        ],
      ),
    ),
  );
}
