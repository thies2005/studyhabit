import 'dart:io';

import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/models/enums.dart';
import '../../core/models/user_stats.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/providers/user_stats_provider.dart';
import '../../core/services/export_service.dart';
import '../../core/services/import_service.dart';
import '../../core/theme/app_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeSettings = ref.watch(themeSettingsProvider);
    final statsAsync = ref.watch(userStatsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: themeSettings.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Failed to load settings',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
          data: (settings) =>
              _SettingsContent(settings: settings, statsAsync: statsAsync),
        ),
      ),
    );
  }
}

class _SettingsContent extends ConsumerWidget {
  const _SettingsContent({
    required this.settings,
    required this.statsAsync,
  });

  final ThemeSettingsState settings;
  final AsyncValue<UserStats> statsAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text('Settings', style: theme.textTheme.headlineLarge),
        const SizedBox(height: 4),
        Text(
          'Personalize your focused environment',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        const _SectionHeader(icon: Icons.palette_outlined, label: 'Appearance'),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Theme', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  selected: {settings.themeMode},
                  onSelectionChanged: (selection) {
                    final selected = selection.first;
                    ref
                        .read(themeSettingsProvider.notifier)
                        .setThemeMode(selected);
                  },
                  segments: const [
                    ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                    ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('System'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: settings.useDynamicColor,
                  onChanged: (value) {
                    ref
                        .read(themeSettingsProvider.notifier)
                        .setUseDynamicColor(value);
                  },
                  title: Text(
                    'Adaptive Material You',
                    style: theme.textTheme.titleSmall,
                  ),
                  subtitle: Text(
                    'Use system-derived colors when available',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Seed color accents', style: theme.textTheme.titleSmall),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (var i = 0; i < AppTheme.presetSeeds.length; i++)
                      _SeedColorDot(
                        color: AppTheme.presetSeeds[i],
                        selected: settings.seedColorIndex == i,
                        onTap: () => ref
                            .read(themeSettingsProvider.notifier)
                            .setSeedColor(i),
                      ),
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _showCustomColorPicker(context, ref),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colorScheme.outlineVariant,
                              width: 1,
                            ),
                          ),
                          child: const Icon(Icons.add, size: 16),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Font Scale', style: theme.textTheme.titleSmall),
                const SizedBox(height: 10),
                SegmentedButton<double>(
                  showSelectedIcon: false,
                  selected: {settings.fontScale},
                  onSelectionChanged: (selection) {
                    final selected = selection.first;
                    ref
                        .read(themeSettingsProvider.notifier)
                        .setFontScale(selected);
                  },
                  segments: const [
                    ButtonSegment(value: 0.9, label: Text('Small')),
                    ButtonSegment(value: 1.0, label: Text('Normal')),
                    ButtonSegment(value: 1.15, label: Text('Large')),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const _SectionHeader(
          icon: Icons.timer_outlined,
          label: 'Pomodoro Engine',
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              _SliderSetting(
                label: 'Focus Duration',
                value: settings.workDuration.toDouble(),
                min: 5,
                max: 90,
                unit: 'min',
                onChanged: (value) {
                  ref
                      .read(themeSettingsProvider.notifier)
                      .setWorkDuration(value.round());
                },
              ),
              const Divider(height: 1),
              _SliderSetting(
                label: 'Short Break',
                value: settings.shortBreak.toDouble(),
                min: 1,
                max: 30,
                unit: 'min',
                onChanged: (value) {
                  ref
                      .read(themeSettingsProvider.notifier)
                      .setShortBreak(value.round());
                },
              ),
              const Divider(height: 1),
              _SliderSetting(
                label: 'Long Break',
                value: settings.longBreak.toDouble(),
                min: 5,
                max: 60,
                unit: 'min',
                onChanged: (value) {
                  ref
                      .read(themeSettingsProvider.notifier)
                      .setLongBreak(value.round());
                },
              ),
              const Divider(height: 1),
              _SliderSetting(
                label: 'Long Break Every',
                value: settings.longBreakEvery.toDouble(),
                min: 2,
                max: 8,
                unit: '',
                isInt: true,
                onChanged: (value) {
                  ref
                      .read(themeSettingsProvider.notifier)
                      .setLongBreakEvery(value.round());
                },
              ),
              const Divider(height: 1),
              SwitchListTile(
                value: settings.autoStartBreaks,
                onChanged: (value) {
                  ref
                      .read(themeSettingsProvider.notifier)
                      .setAutoStartBreaks(value);
                },
                title: Text(
                  'Auto-start Breaks',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              SwitchListTile(
                value: settings.vibration,
                onChanged: (value) {
                  ref.read(themeSettingsProvider.notifier).setVibration(value);
                },
                title: Text('Vibration', style: theme.textTheme.titleSmall),
                subtitle: Text(
                  'Haptic feedback on completion',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const _SectionHeader(
          icon: Icons.notifications_outlined,
          label: 'Alerts',
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                value: settings.notificationsEnabled,
                onChanged: (value) {
                  ref
                      .read(themeSettingsProvider.notifier)
                      .setNotificationsEnabled(value);
                },
                title: Text(
                  'Push Notifications',
                  style: theme.textTheme.titleSmall,
                ),
                subtitle: Text(
                  'Daily goals and reminders',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const Divider(height: 1),
              SwitchListTile(
                value: settings.studyReminderEnabled,
                onChanged: (value) {
                  ref
                      .read(themeSettingsProvider.notifier)
                      .setStudyReminderEnabled(value);
                },
                title: Text(
                  'Study Reminders',
                  style: theme.textTheme.titleSmall,
                ),
                subtitle: Text(
                  'Get reminded to study again after a break',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (settings.studyReminderEnabled)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Remind after', style: theme.textTheme.bodyMedium),
                          Text(
                            '${settings.studyReminderMinutes} min',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: settings.studyReminderMinutes.toDouble(),
                        min: 5,
                        max: 120,
                        divisions: 23,
                        onChanged: (value) {
                          ref
                              .read(themeSettingsProvider.notifier)
                              .setStudyReminderMinutes(value.round());
                        },
                      ),
                    ],
                  ),
                ),
              const Divider(height: 1),
              SwitchListTile(
                value: settings.notificationsEnabled,
                onChanged: (value) {
                  ref
                      .read(themeSettingsProvider.notifier)
                      .setNotificationsEnabled(value);
                },
                title: Text(
                  'Daily Reminder',
                  style: theme.textTheme.titleSmall,
                ),
                subtitle: Text(
                  'Remind yourself to study at a set time every day',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (settings.notificationsEnabled)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Reminder time', style: theme.textTheme.bodyMedium),
                          Text(
                            '${settings.dailyReminderHour.toString().padLeft(2, '0')}:${settings.dailyReminderMinute.toString().padLeft(2, '0')}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Slider(
                              value: settings.dailyReminderHour.toDouble(),
                              min: 0,
                              max: 23,
                              divisions: 23,
                              label: '${settings.dailyReminderHour}:00',
                              onChanged: (value) {
                                ref
                                    .read(themeSettingsProvider.notifier)
                                    .setDailyReminderTime(
                                      hour: value.round(),
                                      minute: settings.dailyReminderMinute,
                                    );
                              },
                            ),
                          ),
                          SizedBox(
                            width: 60,
                            child: Slider(
                              value: settings.dailyReminderMinute.toDouble(),
                              min: 0,
                              max: 55,
                              divisions: 11,
                              label: ':${settings.dailyReminderMinute.toString().padLeft(2, '0')}',
                              onChanged: (value) {
                                ref
                                    .read(themeSettingsProvider.notifier)
                                    .setDailyReminderTime(
                                      hour: settings.dailyReminderHour,
                                      minute: value.round(),
                                    );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const _SectionHeader(
          icon: Icons.local_fire_department_outlined,
          label: 'Streak Protection',
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                title: Text('Grace Period', style: theme.textTheme.titleSmall),
                subtitle: Text(
                  '${settings.gracePeriodHours} hours past midnight',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Slider(
                  value: settings.gracePeriodHours,
                  min: 0,
                  max: 4,
                  divisions: 8,
                  label: '${settings.gracePeriodHours}h',
                  onChanged: (value) {
                    ref
                        .read(themeSettingsProvider.notifier)
                        .setGracePeriodHours(value);
                  },
                ),
              ),
              ListTile(
                leading: const Icon(Icons.shield_outlined),
                title: Text(
                  'Streak Freeze Tokens',
                  style: theme.textTheme.titleSmall,
                ),
                trailing: statsAsync.when(
                  loading: () => const CircularProgressIndicator(),
                  error: (_, __) => const Text('Error'),
                  data: (stats) =>
                      Chip(label: Text('${stats.freezeTokens} available')),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const _SectionHeader(icon: Icons.storage_outlined, label: 'Data Vault'),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.upload_outlined),
                title: const Text('Export All Data'),
                subtitle: Text(
                  'Download as JSON',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
                trailing: FilledButton.tonal(
                  onPressed: () => _handleExport(context, ref),
                  child: const Text('Export'),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('Import Backup'),
                subtitle: Text(
                  'Restore from previous export',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
                trailing: FilledButton.tonal(
                  onPressed: () => _handleImport(context, ref),
                  child: const Text('Import'),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.bug_report_outlined),
                title: const Text('Diagnostic Logs'),
                subtitle: Text(
                  'View and copy debug information',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.pushNamed('diagnostic-logs'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.delete_forever, color: colorScheme.error),
                title: const Text('Reset All Progress'),
                subtitle: Text(
                  'This cannot be undone',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
                trailing: OutlinedButton(
                  onPressed: () => _handleClearAll(context, ref),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.error,
                  ),
                  child: const Text('Clear'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _ComingSoonCard(colorScheme: colorScheme),
        const SizedBox(height: 20),
      ],
    );
  }

  Future<void> _showCustomColorPicker(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final currentSettingsAsync = ref.read(themeSettingsProvider);
    final currentSeedColor =
        AppTheme.presetSeeds[(currentSettingsAsync
                    .asData
                    ?.value
                    .seedColorIndex ??
                0) %
            AppTheme.presetSeeds.length];

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pick Custom Color'),
        content: SizedBox(
          width: 300,
          height: 400,
          child: ColorPicker(
            color: currentSeedColor,
            onColorChanged: (color) {
              final index = AppTheme.presetSeeds.indexOf(color);
              if (index >= 0) {
                Navigator.of(context).pop(index);
              } else {
                // For non-preset colors, find the closest one
                final closestIndex = AppTheme.presetSeeds.indexOf(
                  AppTheme.presetSeeds.firstWhere((c) {
                    final diff =
                        ((c.r * 255).round().clamp(0, 255) -
                                (color.r * 255).round().clamp(0, 255))
                            .abs() +
                        ((c.g * 255).round().clamp(0, 255) -
                                (color.g * 255).round().clamp(0, 255))
                            .abs() +
                        ((c.b * 255).round().clamp(0, 255) -
                                (color.b * 255).round().clamp(0, 255))
                            .abs();
                    final defaultDiff =
                        ((AppTheme.presetSeeds[0].r * 255).round().clamp(
                                  0,
                                  255,
                                ) -
                                (color.r * 255).round().clamp(0, 255))
                            .abs() +
                        ((AppTheme.presetSeeds[0].g * 255).round().clamp(
                                  0,
                                  255,
                                ) -
                                (color.g * 255).round().clamp(0, 255))
                            .abs() +
                        ((AppTheme.presetSeeds[0].b * 255).round().clamp(
                                  0,
                                  255,
                                ) -
                                (color.b * 255).round().clamp(0, 255))
                            .abs();
                    return diff <= defaultDiff;
                  }, orElse: () => AppTheme.presetSeeds[0]),
                );
                Navigator.of(context).pop(closestIndex >= 0 ? closestIndex : 0);
              }
            },
            pickersEnabled: const <ColorPickerType, bool>{
              ColorPickerType.both: true,
              ColorPickerType.primary: true,
              ColorPickerType.accent: true,
            },
          ),
        ),
      ),
    );
  }

  Future<void> _handleExport(BuildContext context, WidgetRef ref) async {
    // Show warning about PDFs not being bundled
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Data'),
        content: const Text(
          'PDF files are not included in the export. Only file paths are saved. Make sure your PDFs remain in their original locations.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Export'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final db = ref.read(appDatabaseProvider);
      final exportService = ExportService(db);
      final file = await exportService.exportToJson();

      if (!context.mounted) return;

      final result = await Share.shareXFiles([
        XFile(file.path),
      ], text: 'StudyTracker Export');

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.status == ShareResultStatus.success
                ? 'Export ready!'
                : 'Export failed',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _handleImport(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = File(result.files.single.path!);

    // Show import mode dialog
    if (!context.mounted) return;

    final mode = await showDialog<ImportMode>(
      context: context,
      builder: (context) => const _ImportModeDialog(),
    );

    if (mode == null || !context.mounted) return;

    try {
      final db = ref.read(appDatabaseProvider);
      final importService = ImportService(db);

      final importResult = await importService.importFromJson(file, mode);

      if (!context.mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Import Complete'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              const Text('Imported:'),
              const SizedBox(height: 8),
              Text('• ${importResult.projectCount} projects'),
              Text('• ${importResult.subjectCount} subjects'),
              Text('• ${importResult.sessionCount} sessions'),
              Text('• ${importResult.sourceCount} sources'),
              if (importResult.errors.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Errors:',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                ...importResult.errors.map(
                  (e) => Text('• $e', style: const TextStyle(fontSize: 12)),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Import failed: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _handleClearAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Are you sure?'),
        content: const Text(
          'This will permanently delete all your data. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // Second confirmation - type DELETE
    final typedDelete = await showDialog<String>(
      context: context,
      builder: (context) => const _DeleteConfirmationDialog(),
    );

    if (typedDelete != 'DELETE' || !context.mounted) return;

    try {
      final db = ref.read(appDatabaseProvider);

      // Delete all data in FK order
      await db.delete(db.skillLabels).go();
      await db.delete(db.sources).go();
      await db.delete(db.studySessions).go();
      await db.delete(db.chapters).go();
      await db.delete(db.topics).go();
      await db.delete(db.subjects).go();
      await db.delete(db.projects).go();
      await db.delete(db.achievements).go();
      await db.delete(db.userStatsTable).go();

      if (!context.mounted) return;

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All data cleared'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to clear data: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Icon(icon, size: 16, color: colorScheme.primary),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: colorScheme.primary,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _SliderSetting extends StatelessWidget {
  const _SliderSetting({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.onChanged,
    this.isInt = false,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final String unit;
  final ValueChanged<double> onChanged;
  final bool isInt;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayValue = isInt ? value.round() : value.round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyLarge),
            Text(
              '$displayValue $unit',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: colorScheme.primary),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: (max - min).toInt(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _ImportModeDialog extends StatefulWidget {
  const _ImportModeDialog();

  @override
  State<_ImportModeDialog> createState() => _ImportModeDialogState();
}

class _ImportModeDialogState extends State<_ImportModeDialog> {
  ImportMode _selectedMode = ImportMode.merge;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Import Mode'),
      content: RadioGroup<ImportMode>(
        groupValue: _selectedMode,
        onChanged: (value) {
          if (value != null) setState(() => _selectedMode = value);
        },
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<ImportMode>(
              title: Text('Merge'),
              subtitle: Text('Keep existing data, add new items'),
              value: ImportMode.merge,
            ),
            RadioListTile<ImportMode>(
              title: Text('Replace'),
              subtitle: Text('Delete all data before importing'),
              value: ImportMode.replace,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_selectedMode),
          child: const Text('Import'),
        ),
      ],
    );
  }
}

class _DeleteConfirmationDialog extends StatefulWidget {
  const _DeleteConfirmationDialog();

  @override
  State<_DeleteConfirmationDialog> createState() =>
      _DeleteConfirmationDialogState();
}

class _DeleteConfirmationDialogState extends State<_DeleteConfirmationDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('Type DELETE to confirm'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'DELETE',
          errorText:
              _controller.text.isNotEmpty &&
                  _controller.text.toUpperCase() != 'DELETE'
              ? 'Type DELETE exactly'
              : null,
        ),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _controller.text.toUpperCase() == 'DELETE'
              ? () => Navigator.of(context).pop(_controller.text)
              : null,
          style: FilledButton.styleFrom(backgroundColor: colorScheme.error),
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}

class _ComingSoonCard extends StatelessWidget {
  const _ComingSoonCard({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
      child: ListTile(
        enabled: false,
        leading: const Icon(Icons.cloud_sync_outlined),
        title: const Text('Connect to Server'),
        subtitle: const Text('Sync across devices — Phase 7'),
        trailing: Chip(
          label: const Text('Coming Soon'),
          backgroundColor: colorScheme.secondaryContainer,
        ),
      ),
    );
  }
}

class _SeedColorDot extends StatelessWidget {
  const _SeedColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? colorScheme.primary : colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: CircleAvatar(radius: 14, backgroundColor: color),
      ),
    );
  }
}
