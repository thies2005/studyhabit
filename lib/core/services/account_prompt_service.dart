import 'package:riverpod_annotation/riverpod_annotation.dart';


import '../providers/server_url_provider.dart';
import '../providers/user_stats_provider.dart';
import 'auth_service.dart';

part 'account_prompt_service.g.dart';

enum PromptType { soft, strong }

@Riverpod(keepAlive: true)
class AccountPromptService extends _$AccountPromptService {
  static const String _softShownKey = 'prompt.5h_shown';
  static const String _strongShownKey = 'prompt.20h_shown';

  @override
  void build() {}

  Future<PromptType?> shouldShowPrompt() async {
    final authState = ref.read(authProvider);
    final isAuth = authState.maybeWhen(
      authenticated: (_, __) => true,
      orElse: () => false,
    );
    if (isAuth) return null;

    final statsState = ref.read(userStatsProvider);
    final stats = statsState.asData?.value;
    if (stats == null) return null;

    final totalHours = stats.totalStudyMinutes / 60.0;
    final prefs = ref.read(sharedPreferencesInstanceProvider);

    if (totalHours >= 20.0) {
      final strongShown = prefs.getBool(_strongShownKey) ?? false;
      if (!strongShown) {
        return PromptType.strong;
      }
    } else if (totalHours >= 5.0) {
      final softShown = prefs.getBool(_softShownKey) ?? false;
      final strongShown = prefs.getBool(_strongShownKey) ?? false;
      if (!softShown && !strongShown) {
        return PromptType.soft;
      }
    }

    return null;
  }

  Future<void> markPromptShown(PromptType type) async {
    final prefs = ref.read(sharedPreferencesInstanceProvider);
    if (type == PromptType.soft) {
      await prefs.setBool(_softShownKey, true);
    } else if (type == PromptType.strong) {
      await prefs.setBool(_strongShownKey, true);
    }
  }
}
