import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/config/app_config.dart';
import '../../ui/widgets/common.dart';

class DeveloperDetails extends StatelessWidget {
  const DeveloperDetails({super.key});

  Future<void> _copyEmail(BuildContext context) async {
    try {
      await Clipboard.setData(
        const ClipboardData(text: AppConfig.developerEmail),
      );
      if (context.mounted) showMessage(context, 'Developer email copied.');
    } catch (_) {
      if (context.mounted) {
        showMessage(
          context,
          'The email could not be copied. Please try again.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Developed by: ${AppConfig.developerName}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                'Contact developer',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            IconButton(
              tooltip: 'Copy developer email',
              onPressed: () => _copyEmail(context),
              icon: const Icon(Icons.copy_outlined),
            ),
          ],
        ),
        SelectableText(
          AppConfig.developerEmail,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    ),
  );
}
