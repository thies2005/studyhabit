import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'sync_service.dart';

part 'sync_timer.g.dart';

@Riverpod(keepAlive: true)
class SyncTimer extends _$SyncTimer {
  Timer? _timer;

  @override
  void build() {
    ref.onDispose(() {
      _timer?.cancel();
    });
  }

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 10), (_) {
      ref.read(syncEngineProvider.notifier).fullSync();
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
