import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'sync_service.g.dart';

enum SyncStatus { idle, syncing, synced, error }

/// Abstract interface for sync service
abstract class SyncService {
  Future<void> syncPending();
  Stream<SyncStatus> get syncStatus;
}

/// Phase 1: No-op sync service (when backend is disabled)
class NoOpSyncService implements SyncService {
  @override
  Future<void> syncPending() async {}

  @override
  Stream<SyncStatus> get syncStatus => Stream.value(SyncStatus.idle);
}

/// Phase 2: HTTP sync service (when backend is enabled)
/// This stub will be activated when backend is configured
class HttpSyncService implements SyncService {
  @override
  Future<void> syncPending() async {
    // Implementation will read from pending_sync_ops table
    // and POST/PATCH each operation to the backend API
    // TODO: Implement in Phase 2 activation
  }

  @override
  Stream<SyncStatus> get syncStatus async* {
    // TODO: Implement sync status tracking
    yield SyncStatus.idle;
  }
}

@Riverpod(keepAlive: true)
SyncService syncService(Ref ref) {
  final isEnabled = ref.watch(backendEnabledProvider);
  if (isEnabled) {
    return HttpSyncService();
  }
  return NoOpSyncService();
}

@Riverpod(keepAlive: true)
class BackendEnabled extends _$BackendEnabled {
  static const _backendEnabledKey = 'sync.backendEnabled';

  @override
  bool build() {
    _loadFromPrefs();
    return false;
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getBool(_backendEnabledKey) ?? false;
    if (val != state) state = val;
  }

  Future<void> setEnabled(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_backendEnabledKey, value);
  }
}
