import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/privacy_policy.dart';
import '../../ui/widgets/common.dart';

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  AssetBundle? _bundle;
  late Future<PrivacyPolicyDocument> _document;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bundle = DefaultAssetBundle.of(context);
    if (!identical(bundle, _bundle)) {
      _bundle = bundle;
      _document = PrivacyPolicyDocument.load(bundle: bundle);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back to settings',
          onPressed: () => context.go('/settings'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Privacy Policy'),
      ),
      body: PageContent(
        maxWidth: 850,
        child: FutureBuilder<PrivacyPolicyDocument>(
          future: _document,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return SoftCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'The bundled privacy policy could not be loaded.',
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => setState(() {
                        _document = PrivacyPolicyDocument.load(bundle: _bundle);
                      }),
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              );
            }
            final document = snapshot.data;
            if (document == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return SelectionArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const IconBadge(Icons.shield_outlined, size: 58),
                  const SizedBox(height: 20),
                  Eyebrow(document.eyebrow),
                  const SizedBox(height: 10),
                  Semantics(
                    header: true,
                    child: Text(
                      document.title,
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    document.appName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    document.revisionLabel,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 24),
                  SoftCard(child: Text(document.intro)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: document.summaryBadges
                        .map((text) => Chip(label: Text(text)))
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 24),
                  for (final section in document.sections) ...[
                    _PrivacySection(section),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    document.footer,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 24),
                  // Local navigation is outside the shared legal text.
                  OutlinedButton(
                    onPressed: () => context.go('/settings'),
                    child: const Text('Open my settings'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PrivacySection extends StatelessWidget {
  const _PrivacySection(this.section);
  final PrivacyPolicySection section;
  @override
  Widget build(BuildContext context) => SoftCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            section.title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 14),
        for (final paragraph in section.paragraphs) ...[
          Text(paragraph),
          const SizedBox(height: 12),
        ],
        for (final bullet in section.bullets) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('•  '),
              Expanded(child: Text(bullet)),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ],
    ),
  );
}
