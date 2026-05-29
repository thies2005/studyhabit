import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/providers/server_url_provider.dart';

class SyncSettingsPage extends ConsumerStatefulWidget {
  const SyncSettingsPage({super.key});

  @override
  ConsumerState<SyncSettingsPage> createState() => _SyncSettingsPageState();
}

class _SyncSettingsPageState extends ConsumerState<SyncSettingsPage> {
  final _serverUrlController = TextEditingController();
  bool _isEditingServer = false;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _serverUrlController.text = ref.read(serverUrlProvider);
    });
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    super.dispose();
  }

  Future<void> _handleSyncNow() async {
    setState(() {
      _isSyncing = true;
    });

    // Mock sync delay - we will wire this to real SyncEngine in S3
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() {
        _isSyncing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Sync complete! All changes backed up. ☁️'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect Sync?'),
        content: const Text(
          'Your local study data remains on this device, but it will no longer sync to the cloud until you log in again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authProvider.notifier).logout();
      if (mounted) {
        context.pop(); // Go back to settings screen
      }
    }
  }

  Future<void> _saveServerUrl() async {
    final cleanUrl = _serverUrlController.text.trim();
    if (cleanUrl.isNotEmpty) {
      await ref.read(serverUrlProvider.notifier).setUrl(cleanUrl);
      setState(() {
        _isEditingServer = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Server URL updated to $cleanUrl'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cloud Sync'),
      ),
      body: authState.maybeWhen(
        authenticated: (userId, email) => ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          children: [
            // User Header
            Card(
              elevation: 0,
              color: colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: colorScheme.primaryContainer,
                      child: Icon(Icons.person_outline, size: 28, color: colorScheme.primary),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            email,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'User ID: ${userId.substring(0, 8)}...',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.logout_rounded, color: colorScheme.error),
                      tooltip: 'Log Out / Disconnect',
                      onPressed: _handleLogout,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Sync Status Block
            Text('Sync Engine Status', style: theme.textTheme.titleSmall?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    _buildStatusRow(
                      context,
                      theme,
                      icon: Icons.sync_outlined,
                      label: 'Status',
                      valueWidget: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text('Connected & Active', style: TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const Divider(height: 32),
                    _buildStatusRow(
                      context,
                      theme,
                      icon: Icons.access_time_outlined,
                      label: 'Last Synced',
                      valueWidget: Text(
                        DateFormat('h:mm a').format(DateTime.now().subtract(const Duration(minutes: 2))),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    const Divider(height: 32),
                    _buildStatusRow(
                      context,
                      theme,
                      icon: Icons.pending_actions_outlined,
                      label: 'Pending Changes',
                      valueWidget: const Chip(
                        label: Text('0', style: TextStyle(fontWeight: FontWeight.bold)),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        minimumSize: const Size.fromHeight(50),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: _isSyncing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                            )
                          : const Icon(Icons.sync_rounded, size: 18),
                      label: Text(_isSyncing ? 'Syncing...' : 'Sync Now', style: const TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: _isSyncing ? null : _handleSyncNow,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Server Configurations
            Text('Server Configurations', style: theme.textTheme.titleSmall?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!_isEditingServer) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Backend Endpoint', style: theme.textTheme.titleSmall),
                              const SizedBox(height: 4),
                              Text(
                                ref.watch(serverUrlProvider),
                                style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () {
                              setState(() {
                                _isEditingServer = true;
                              });
                            },
                          ),
                        ],
                      ),
                    ] else ...[
                      TextFormField(
                        controller: _serverUrlController,
                        decoration: InputDecoration(
                          labelText: 'Server URL',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _isEditingServer = false;
                                _serverUrlController.text = ref.read(serverUrlProvider);
                              });
                            },
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _saveServerUrl,
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Danger Zone
            Text('Danger Zone', style: theme.textTheme.titleSmall?.copyWith(color: colorScheme.error, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: colorScheme.error.withValues(alpha: 0.3)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.cloud_off_rounded, color: colorScheme.error),
                      title: const Text('Erase Cloud Data', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Clears all synchronized history on the server. Local data remains intact.'),
                      trailing: OutlinedButton(
                        style: OutlinedButton.styleFrom(foregroundColor: colorScheme.error),
                        onPressed: () {
                          // Placeholder
                        },
                        child: const Text('Erase'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        orElse: () => const Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }

  Widget _buildStatusRow(BuildContext context, ThemeData theme,
      {required IconData icon, required String label, required Widget valueWidget}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Text(label, style: theme.textTheme.bodyMedium),
        const Spacer(),
        valueWidget,
      ],
    );
  }
}
