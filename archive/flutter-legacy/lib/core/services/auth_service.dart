import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../network/api_client.dart';

part 'auth_service.freezed.dart';
part 'auth_service.g.dart';

@freezed
class AuthState with _$AuthState {
  const factory AuthState.unauthenticated() = _Unauthenticated;
  const factory AuthState.loading() = _Loading;
  const factory AuthState.authenticated({
    required String userId,
    required String email,
  }) = _Authenticated;
  const factory AuthState.error(String message) = _Error;
}

@Riverpod(keepAlive: true)
class AuthNotifier extends _$AuthNotifier {
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    // Explicitly enable hardened storage options rather than relying on plugin
    // defaults. resetOnError recovers gracefully if the Keystore key is
    // invalidated (e.g. after a device PIN change) instead of crashing.
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: true,
    ),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  @override
  AuthState build() {
    // Initial state is unauthenticated. We will call restoreSession() on app startup.
    return const AuthState.unauthenticated();
  }

  Future<void> restoreSession() async {
    state = const AuthState.loading();
    final accessToken = await _storage.read(key: 'auth_access_token');
    final userId = await _storage.read(key: 'auth_user_id');
    final email = await _storage.read(key: 'auth_user_email');

    if (accessToken != null && userId != null && email != null) {
      state = AuthState.authenticated(userId: userId, email: email);
    } else {
      state = const AuthState.unauthenticated();
    }
  }

  Future<void> login(String email, String password) async {
    state = const AuthState.loading();
    try {
      final dio = ref.read(apiClientProvider);
      final deviceName = await _getDeviceName();

      final response = await dio.post('/auth/login', data: {
        'email': email.trim(),
        'password': password,
        'deviceName': deviceName,
      });

      final responseData = response.data['data'];
      final accessToken = responseData['accessToken'] as String;
      final refreshToken = responseData['refreshToken'] as String;
      final user = responseData['user'] as Map<String, dynamic>;
      final userId = user['id'] as String;
      final userEmail = user['email'] as String;

      // Save tokens and user info
      await _storage.write(key: 'auth_access_token', value: accessToken);
      await _storage.write(key: 'auth_refresh_token', value: refreshToken);
      await _storage.write(key: 'auth_user_id', value: userId);
      await _storage.write(key: 'auth_user_email', value: userEmail);

      state = AuthState.authenticated(userId: userId, email: userEmail);
    } on DioException catch (e) {
      final data = e.response?.data;
      final message = (data is Map<String, dynamic> ? data['error'] : null) ?? 'Login failed. Please check your credentials. (${e.response?.statusCode})';
      state = AuthState.error(message.toString());
    } catch (e) {
      state = AuthState.error(e.toString());
    }
  }

  Future<void> register(String email, String password) async {
    state = const AuthState.loading();
    try {
      final dio = ref.read(apiClientProvider);
      final deviceName = await _getDeviceName();

      final response = await dio.post('/auth/register', data: {
        'email': email.trim(),
        'password': password,
        'deviceName': deviceName,
      });

      final responseData = response.data['data'];
      final accessToken = responseData['accessToken'] as String;
      final refreshToken = responseData['refreshToken'] as String;
      final user = responseData['user'] as Map<String, dynamic>;
      final userId = user['id'] as String;
      final userEmail = user['email'] as String;

      // Save tokens and user info
      await _storage.write(key: 'auth_access_token', value: accessToken);
      await _storage.write(key: 'auth_refresh_token', value: refreshToken);
      await _storage.write(key: 'auth_user_id', value: userId);
      await _storage.write(key: 'auth_user_email', value: userEmail);

      state = AuthState.authenticated(userId: userId, email: userEmail);
    } on DioException catch (e) {
      final data = e.response?.data;
      final message = (data is Map<String, dynamic> ? data['error'] : null) ?? 'Registration failed. (${e.response?.statusCode})';
      state = AuthState.error(message.toString());
    } catch (e) {
      state = AuthState.error(e.toString());
    }
  }

  Future<void> logout() async {
    state = const AuthState.loading();
    try {
      final dio = ref.read(apiClientProvider);
      final refreshToken = await _storage.read(key: 'auth_refresh_token');
      
      if (refreshToken != null) {
        // Try calling logout on server in the background, but proceed locally anyway
        try {
          await dio.post('/auth/logout', data: {'refreshToken': refreshToken});
        } catch (_) {}
      }
    } catch (_) {
      // Ignore network errors on logout
    } finally {
      // Clear secure storage locally
      await _storage.delete(key: 'auth_access_token');
      await _storage.delete(key: 'auth_refresh_token');
      await _storage.delete(key: 'auth_user_id');
      await _storage.delete(key: 'auth_user_email');

      state = const AuthState.unauthenticated();
    }
  }

  Future<String> _getDeviceName() async {
    final deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return '${androidInfo.manufacturer} ${androidInfo.model}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return iosInfo.name;
      } else if (Platform.isMacOS) {
        final macInfo = await deviceInfo.macOsInfo;
        return macInfo.computerName;
      } else if (Platform.isWindows) {
        final winInfo = await deviceInfo.windowsInfo;
        return winInfo.computerName;
      } else if (Platform.isLinux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        return linuxInfo.name;
      }
    } catch (_) {
      // Fallback
    }
    // Platform-aware fallback rather than a misleading 'Mobile Device'.
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      return 'Desktop Device';
    }
    return 'Mobile Device';
  }
}
