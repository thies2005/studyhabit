import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/timer_persistence_service.dart';

part 'server_url_provider.g.dart';

@Riverpod(keepAlive: true)
class ServerUrl extends _$ServerUrl {
  static const String defaultUrl = 'https://studyhabit.schuelken.uk';
  static const String _prefKey = 'sync.serverUrl';

  late SharedPreferences _prefs;

  @override
  String build() {
    try {
      _prefs = ref.read(sharedPreferencesInstanceProvider);
      return _prefs.getString(_prefKey) ?? defaultUrl;
    } catch (_) {
      return defaultUrl;
    }
  }

  Future<void> setUrl(String url) async {
    final cleanUrl = url.trim().replaceAll(RegExp(r'/$'), '');
    _prefs = ref.read(sharedPreferencesInstanceProvider);
    await _prefs.setString(_prefKey, cleanUrl);
    state = cleanUrl;
  }

  Future<void> resetToDefault() async {
    _prefs = ref.read(sharedPreferencesInstanceProvider);
    await _prefs.remove(_prefKey);
    state = defaultUrl;
  }
}

// Simple provider to access SharedPreferences instance registered on startup
@Riverpod(keepAlive: true)
SharedPreferences sharedPreferencesInstance(Ref ref) {
  return TimerPersistenceService.prefs;
}
