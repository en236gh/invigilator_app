import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../features/auth/data/auth_repository.dart';
import '../api_client.dart';

class AuthInterceptor extends Interceptor {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final access = await _storage.read(key: 'accessToken');
    if (access != null && access.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $access';
    }
    return handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final resp = err.response;
    final RequestOptions options = err.requestOptions;

    if (options.path.endsWith('/api/auth/refresh')) {
      return handler.next(err);
    }

    if (resp != null && resp.statusCode == 401) {
      if (options.extra['retried'] == true) {
        return handler.next(err);
      }

      final refreshToken = await _storage.read(key: 'refreshToken');
      if (refreshToken == null || refreshToken.isEmpty) {
        return handler.next(err);
      }

      try {
        final refreshed = await AuthRepository().refreshToken();
        if (!refreshed) {
          return handler.next(err);
        }

        final newAccess = await _storage.read(key: 'accessToken');
        if (newAccess == null || newAccess.isEmpty) {
          return handler.next(err);
        }

        final retryOptions = options.copyWith(
          headers: {
            ...options.headers,
            'Authorization': 'Bearer $newAccess',
          },
          extra: {
            ...options.extra,
            'retried': true,
          },
        );

        final retryResponse = await ApiClient.instance.fetch(retryOptions);
        return handler.resolve(retryResponse);
      } catch (_) {
        return handler.next(err);
      }
    }

    return handler.next(err);
  }
}
