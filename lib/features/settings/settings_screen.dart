import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_services.dart';
import '../../app/theme.dart';
import '../../core/config/app_config.dart';
import '../../core/storage/settings_repository.dart';
import '../../ui/widgets/common.dart';
import 'developer_details.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _saving = false;
  double? _musicVolume;
  double? _soundVolume;

  Future<void> _apply(GameSettings value) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(servicesProvider).updateSettings(value);
    } catch (_) {
      if (mounted) {
        showMessage(
          context,
          'Your settings could not be saved. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _musicVolume = null;
          _soundVolume = null;
        });
      }
    }
  }

  Future<void> _reset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('A brand-new little journey?'),
        content: const Text(
          'This deletes saved levels, stars, personal bests, daily history, coins, and your unfinished puzzle from this device. You’ll restart with 100 coins. Sound settings and downloaded packs are kept. This can’t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep my discoveries'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: FindItColors.coral),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset my progress'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(servicesProvider).resetProgress();
      if (mounted) {
        showMessage(context, 'A fresh start. Your new journey is ready.');
      }
    } catch (_) {
      if (mounted) {
        showMessage(context, 'Progress could not be reset. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final settings = state.settings;
    return PageContent(
      maxWidth: 880,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('MAKE THIS LITTLE CORNER YOURS'),
          const SizedBox(height: 12),
          Text(
            'Just the way you like it.',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 10),
          Text(
            'A few thoughtful touches, for a little more comfort.',
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: FindItColors.muted),
          ),
          const SizedBox(height: 28),
          if (state.settingsRecoveryNotice != null) ...[
            SoftCard(child: Text(state.settingsRecoveryNotice!)),
            const SizedBox(height: 20),
          ],
          _SettingsGroup(
            'A little atmosphere',
            children: [
              _SettingSwitch(
                title: 'Sound effects',
                subtitle: 'Gentle sounds for finds, hints, and little wins.',
                icon: Icons.volume_up_outlined,
                value: settings.sound,
                onChanged: _saving
                    ? null
                    : (value) => _apply(settings.copyWith(sound: value)),
              ),
              if (settings.sound)
                _VolumeSlider(
                  label: 'Sound volume',
                  value: _soundVolume ?? settings.soundVolume,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _soundVolume = value),
                  onChangeEnd: (value) =>
                      _apply(settings.copyWith(soundVolume: value)),
                ),
              const Divider(height: 1),
              _SettingSwitch(
                title: 'Background music',
                subtitle: 'An original, quiet little melody.',
                icon: Icons.music_note_outlined,
                value: settings.music,
                onChanged: _saving
                    ? null
                    : (value) => _apply(settings.copyWith(music: value)),
              ),
              if (settings.music)
                _VolumeSlider(
                  label: 'Music volume',
                  value: _musicVolume ?? settings.musicVolume,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _musicVolume = value),
                  onChangeEnd: (value) =>
                      _apply(settings.copyWith(musicVolume: value)),
                ),
              const Divider(height: 1),
              _SettingSwitch(
                title: 'A little vibration',
                subtitle: 'A gentle haptic tap when you find something.',
                icon: Icons.vibration_rounded,
                value: settings.vibration,
                onChanged: _saving
                    ? null
                    : (value) => _apply(settings.copyWith(vibration: value)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SettingsGroup(
            'Your pace, your puzzle',
            children: [
              _SettingSwitch(
                title: 'Take your time',
                subtitle: 'Relaxed search is on by default. Turn it off for a timed challenge. Applies to new sessions; saved games keep their original pace.',
                icon: Icons.spa_outlined,
                value: settings.relaxed,
                onChanged: _saving
                    ? null
                    : (value) => _apply(settings.copyWith(relaxed: value)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SettingsGroup(
            'Your collection & local data',
            key: const ValueKey('settings-local-data'),
            children: [
              ListTile(
                leading: const IconBadge(Icons.inventory_2_outlined, size: 38),
                title: const Text('Puzzle collection'),
                subtitle: Text(
                  AppConfig.packIndexUrl.isEmpty
                      ? '${state.puzzleCount} levels included · play offline'
                      : '${state.puzzleCount} levels · additional puzzle packs',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/packs'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const IconBadge(Icons.shield_outlined, size: 38),
                title: const Text('Privacy & data on this device'),
                subtitle: const Text(
                  'Local saves, permissions, and privacy information.',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/privacy'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const IconBadge(
                  Icons.restart_alt_rounded,
                  size: 38,
                  background: Color(0xFFF4E2D9),
                  color: FindItColors.coral,
                ),
                title: const Text('Reset progress'),
                subtitle: const Text(
                  'Start fresh on this device. A confirmation comes first.',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _reset,
              ),
            ],
          ),
          const SizedBox(height: 24),
          SoftCard(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                ListTile(
                  leading: const IconBadge(
                    Icons.info_outline_rounded,
                    size: 38,
                  ),
                  title: const Text('About FindIt'),
                  subtitle: const Text(
                    'Game information, support, and licenses.',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/about'),
                ),
                const Divider(height: 1),
                const DeveloperDetails(),
              ],
            ),
          ),
          const SizedBox(height: 26),
          Center(
            child: Text(
              'FindIt ${AppConfig.version}${AppConfig.production ? '' : ' · development build'}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: FindItColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup(this.title, {super.key, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 12),
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      SoftCard(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(children: children),
      ),
    ],
  );
}

class _SettingSwitch extends StatelessWidget {
  const _SettingSwitch({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool>? onChanged;
  @override
  Widget build(BuildContext context) => SwitchListTile.adaptive(
    contentPadding: const EdgeInsets.symmetric(horizontal: 19, vertical: 9),
    secondary: IconBadge(icon, size: 38),
    title: Text(title, style: Theme.of(context).textTheme.titleMedium),
    subtitle: Text(
      subtitle,
      style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: FindItColors.muted),
    ),
    value: value,
    onChanged: onChanged,
  );
}

class _VolumeSlider extends StatelessWidget {
  const _VolumeSlider({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.onChangeEnd,
  });
  final String label;
  final double value;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double> onChangeEnd;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodySmall),
            ),
            Text(
              '${(value * 100).round()}%',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: FindItColors.muted),
            ),
          ],
        ),
        Slider(
          value: value,
          onChanged: onChanged,
          onChangeEnd: onChanged == null ? null : onChangeEnd,
          divisions: 20,
          label: '${(value * 100).round()}%',
          semanticFormatterCallback: (value) =>
              '${(value * 100).round()} percent',
        ),
      ],
    ),
  );
}
