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
      title: const Text('About FindIt'),
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
              'FindIt turns a few quiet moments into a colorful hidden-object adventure. Explore cozy rooms, peaceful gardens, and charming cafés across 60 offline levels.\n\nPlay at your own pace, try a Daily Challenge, and collect stars and rewards. No ads, sign-up, or in-app purchases. Your progress stays on your device.',
            ),
          ),
          const SizedBox(height: 20),
          const SoftCard(padding: EdgeInsets.all(8), child: DeveloperDetails()),
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
            child: const Text('Privacy policy'),
          ),
          const SizedBox(height: 28),
          Center(
            child: Text(
              'Version ${AppConfig.version}',
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
