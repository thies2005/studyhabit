import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/server_url_provider.dart';
import '../services/auth_service.dart';

class AuthInterceptor extends QueuedInterceptor {
  final Ref _ref;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  AuthInterceptor(this._ref);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final accessToken = await _storage.read(key: 'auth_access_token');
    if (accessToken != null) {
      options.headers['Authorization'] = 'Bearer $accessToken';
    }
    super.onRequest(options, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final response = err.response;
    
    // Check if error is 401 Unauthorized
    if (response != null && response.statusCode == 401) {
      final refreshToken = await _storage.read(key: 'auth_refresh_token');
      if (refreshToken != null) {
        try {
          // Perform refresh using a fresh, separate Dio client to avoid loops/interceptors
          final serverUrl = _ref.read(serverUrlProvider);
          final refreshDio = Dio(BaseOptions(
            baseUrl: '$serverUrl/api/v1',
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
          ));

          final refreshResponse = await refreshDio.post('/auth/refresh', data: {
            'refreshToken': refreshToken,
          });

          if (refreshResponse.statusCode == 200 || refreshResponse.statusCode == 201) {
            final responseData = refreshResponse.data['data'];
            final newAccessToken = responseData['accessToken'] as String;
            final newRefreshToken = responseData['refreshToken'] as String;

            // Save new tokens
            await _storage.write(key: 'auth_access_token', value: newAccessToken);
            await _storage.write(key: 'auth_refresh_token', value: newRefreshToken);

            // Retry original request with the new token
            final requestOptions = err.requestOptions;
            requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
            
            final retryDio = Dio(); // Basic client for retry
            final retryResponse = await retryDio.fetch(requestOptions);
            return handler.resolve(retryResponse);
          }
        } catch (refreshError) {
          // Token refresh failed, so we clear everything and require log in
          await _storage.delete(key: 'auth_access_token');
          await _storage.delete(key: 'auth_refresh_token');
          await _storage.delete(key: 'auth_user_id');
          await _storage.delete(key: 'auth_user_email');
          
          _ref.read(authProvider.notifier).logout();
        }
      }
    }
    
    super.onError(err, handler);
  }
}
