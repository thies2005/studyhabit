import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../providers/server_url_provider.dart';
import 'auth_interceptor.dart';

part 'api_client.g.dart';

@Riverpod(keepAlive: true)
Dio apiClient(Ref ref) {
  final serverUrl = ref.watch(serverUrlProvider);
  final dio = Dio(BaseOptions(
    baseUrl: '$serverUrl/api/v1',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  ));

  dio.interceptors.add(AuthInterceptor(ref));

  // Only attach the body logger in debug builds. In release, request/response
  // bodies can contain auth tokens and credentials (login/register payloads),
  // and the AppLogger keeps an in-memory buffer that could expose them.
  if (kDebugMode) {
    dio.interceptors.add(LogInterceptor(
      requestHeader: false,
      responseHeader: false,
      requestBody: true,
      responseBody: true,
    ));
  }

  return dio;
}
