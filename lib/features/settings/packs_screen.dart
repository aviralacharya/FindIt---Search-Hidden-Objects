import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_services.dart';
import '../../app/theme.dart';
import '../../core/config/app_config.dart';
import '../../ui/widgets/common.dart';

class PacksScreen extends ConsumerStatefulWidget {
  const PacksScreen({super.key});
  @override
  ConsumerState<PacksScreen> createState() => _PacksScreenState();
}

class _PacksScreenState extends ConsumerState<PacksScreen> {
  final _url = TextEditingController();
  final _checksum = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _downloading = false;
  String? _status;

  @override
  void dispose() {
    _url.dispose();
    _checksum.dispose();
    super.dispose();
  }

  Future<void> _download() async {
    if (_downloading || !_form.currentState!.validate()) return;
    final uri = Uri.parse(_url.text.trim());
    final publisher = Uri.tryParse(AppConfig.packIndexUrl);
    if (publisher == null ||
        publisher.scheme != 'https' ||
        publisher.host.isEmpty ||
        uri.host != publisher.host) {
      setState(
        () => _status =
            'This build only accepts packs from its configured publisher host.',
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add a little more to discover?'),
        content: Text(
          'This contacts ${uri.host} and downloads up to 8 MB of puzzle data. Only import original or properly licensed content from a publisher you trust. Nothing will be installed if validation fails.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Download & validate'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() {
      _downloading = true;
      _status = 'Downloading and checking every puzzle…';
    });
    try {
      final services = ref.read(servicesProvider);
      final pack = await services.content.downloadPack(
        uri,
        expectedSha256: _checksum.text.trim().isEmpty
            ? null
            : _checksum.text.trim(),
      );
      services.changed();
      if (mounted) {
        setState(
          () => _status =
              '${pack.title}: ${pack.count} new puzzles are installed and ready offline.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _status = 'The pack could not be installed. Check your connection, URL, checksum, and pack format. Your current collection is unchanged.',
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final services = ref.read(servicesProvider);
    // No age question or interpretation of legacy preferences. Candidate and
    // final release guards keep the server empty for children and families.
    final publisherConfigured = AppConfig.packIndexUrl.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back to settings',
          onPressed: () => context.go('/settings'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Your puzzle collection'),
      ),
      body: PageContent(
        maxWidth: 840,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const IconBadge(Icons.inventory_2_outlined, size: 58),
            const SizedBox(height: 20),
            const Eyebrow('MORE LITTLE WORLDS TO DISCOVER'),
            const SizedBox(height: 10),
            Text(
              'A collection, made for curiosity.',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 12),
            Text(
              '${state.puzzleCount} unique levels are installed on this device. Daily discoveries are additional. Your installed collection always works offline.',
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: FindItColors.muted),
            ),
            const SizedBox(height: 28),
            const SectionHeading(
              'Ready to explore',
              subtitle: 'Every installed pack is saved locally.',
            ),
            for (final pack in services.content.packs) ...[
              SoftCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconBadge(
                      pack.bundled
                          ? Icons.favorite_border_rounded
                          : Icons.download_done_rounded,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pack.title,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${pack.count} unique levels · ${pack.bundled ? 'Included with FindIt' : 'Downloaded & validated'}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: FindItColors.forest),
                          ),
                          if (!pack.bundled) ...[
                            const SizedBox(height: 10),
                            Text(
                              pack.license,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: FindItColors.muted),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 20),
            const SectionHeading(
              'Optional little additions',
              subtitle:
                  'No download is needed to enjoy the included collection.',
            ),
            SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!publisherConfigured) ...[
                    Text(
                      'All ${state.puzzleCount} levels are included and ready to play offline. Additional puzzle packs are not available right now.',
                    ),
                  ] else
                    Form(
                      key: _form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Import a validated puzzle pack from a trusted HTTPS publisher URL. Packs contain declarative vector puzzle data only; no executable code or remote image trackers.',
                          ),
                          const SizedBox(height: 22),
                          TextFormField(
                            controller: _url,
                            enabled: !_downloading,
                            keyboardType: TextInputType.url,
                            decoration: const InputDecoration(
                              labelText: 'Puzzle pack HTTPS URL',
                              hintText:
                                  'https://your-publisher.example/pack.json',
                            ),
                            validator: (value) {
                              final uri = Uri.tryParse(value?.trim() ?? '');
                              return uri == null ||
                                      uri.scheme != 'https' ||
                                      uri.host.isEmpty ||
                                      uri.userInfo.isNotEmpty ||
                                      uri.fragment.isNotEmpty
                                  ? 'Enter a public HTTPS pack URL, without credentials or a fragment.'
                                  : null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _checksum,
                            enabled: !_downloading,
                            decoration: const InputDecoration(
                              labelText: 'SHA-256 checksum (optional)',
                              helperText: 'Use the checksum provided by your publisher.',
                            ),
                            validator: (value) =>
                                value != null &&
                                    value.trim().isNotEmpty &&
                                    !RegExp(r'^[a-fA-F0-9]{64}$')
                                        .hasMatch(value.trim())
                                ? 'A SHA-256 checksum has 64 hexadecimal characters.'
                                : null,
                          ),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            onPressed: _downloading ? null : _download,
                            icon: _downloading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.download_rounded, size: 19),
                            label: Text(
                              _downloading
                                  ? 'Checking your new discoveries…'
                                  : 'Download a puzzle pack',
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_status != null) ...[
                    const SizedBox(height: 18),
                    Text(
                      _status!,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: FindItColors.muted),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
