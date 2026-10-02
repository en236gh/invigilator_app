import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../features/auth/data/auth_repository.dart';
import '../api_client.dart';

class AuthInterceptor extends Interceptor {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  AuthInterceptor({this.client, AuthRepository? repository})
    : _authRepository = repository ?? AuthRepository();
  final Dio? client;
  final AuthRepository _authRepository;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Skip auth endpoints to avoid infinite loops.
    if (options.path.endsWith('/api/auth/login') ||
        options.path.endsWith('/api/auth/refresh')) {
      return handler.next(options);
    }

    // Proactively refresh the token if it's about to expire.
    try {
      await _authRepository.ensureValidToken();
    } catch (_) {
      // If refresh fails, continue with the existing token.
      // The 401 handler will attempt one more refresh.
    }

    final identity = await _authRepository.requestIdentity();
    final access = identity.access;
    final owner = options.extra['staffId'];
    final session = options.extra['authSession'];
    if ((session != null && session != identity.sessionVersion) ||
        (owner != null && owner != identity.owner)) {
      return handler.reject(
        DioException(
          requestOptions: options,
          error: 'Account changed; queue preserved',
        ),
      );
    }
    options.headers.remove('Authorization');
    if (access != null && access.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $access';
    }
    return handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final resp = err.response;
    final RequestOptions options = err.requestOptions;

    if (options.path.endsWith('/api/auth/refresh') ||
        options.path.endsWith('/api/auth/login')) {
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
        final refreshed = await _authRepository.refreshToken();
        if (!refreshed) {
          return handler.next(err);
        }

        final newAccess = await _storage.read(key: 'accessToken');
        if (newAccess == null || newAccess.isEmpty) {
          return handler.next(err);
        }

        final retryOptions = options.copyWith(
          headers: {...options.headers, 'Authorization': 'Bearer $newAccess'},
          extra: {...options.extra, 'retried': true},
        );

        final retryResponse = await (client ?? ApiClient.instance).fetch(
          retryOptions,
        );
        return handler.resolve(retryResponse);
      } catch (_) {
        return handler.next(err);
      }
    }

    return handler.next(err);
  }
}
