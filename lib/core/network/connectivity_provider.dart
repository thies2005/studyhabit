import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'connectivity_provider.g.dart';

@Riverpod(keepAlive: true)
Stream<bool> isOnline(Ref ref) async* {
  final connectivity = Connectivity();

  // Get initial connectivity state
  final initialResults = await connectivity.checkConnectivity();
  yield initialResults.any((result) => result != ConnectivityResult.none);

  // Monitor connectivity changes
  await for (final results in connectivity.onConnectivityChanged) {
    yield results.any((result) => result != ConnectivityResult.none);
  }
}
