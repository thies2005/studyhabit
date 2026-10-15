import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/sync_service.dart';

class SyncStatusIcon extends ConsumerWidget {
  const SyncStatusIcon({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final syncStatus = ref.watch(syncEngineProvider);

    final isLoggedIn = authState.maybeWhen(
      authenticated: (_, __) => true,
      orElse: () => false,
    );

    if (!isLoggedIn) return const SizedBox.shrink();

    return IconButton(
      tooltip: _getTooltip(syncStatus),
      icon: _getIcon(syncStatus),
      onPressed: () => context.push('/settings/sync'),
    );
  }

  String _getTooltip(SyncStatus status) {
    return switch (status) {
      SyncStatus.idle => 'Cloud Synced',
      SyncStatus.syncing => 'Synchronizing data...',
      SyncStatus.synced => 'All changes synced!',
      SyncStatus.error => 'Sync error. Tap for details.',
    };
  }

  Widget _getIcon(SyncStatus status) {
    return switch (status) {
      SyncStatus.idle => const Icon(Icons.cloud_done_outlined, color: Colors.green),
      SyncStatus.syncing => const _SyncingIcon(),
      SyncStatus.synced => const Icon(Icons.cloud_done, color: Colors.green),
      SyncStatus.error => const Icon(Icons.cloud_off, color: Colors.orange),
    };
  }
}

class _SyncingIcon extends StatefulWidget {
  const _SyncingIcon();

  @override
  State<_SyncingIcon> createState() => _SyncingIconState();
}

class _SyncingIconState extends State<_SyncingIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: const Icon(Icons.sync, color: Colors.blue),
    );
  }
}
