import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/network/api_client.dart';
import '../domain/user.dart';

class AuthRepository {
  final Dio _dio = ApiClient.instance;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _accessTokenKey = 'accessToken';
  static const String _refreshTokenKey = 'refreshToken';
  static const String _tokenTimestampKey = 'tokenTimestamp';

  /// Access token expiry in seconds (5 minutes).
  static const int _accessTokenExpirySeconds = 300;
  /// Refresh proactively when this many seconds remain (60 seconds).
  static const int _refreshBeforeExpirySeconds = 60;

  static Map<String, dynamic>? extractAuthPayload(dynamic data) {
    if (data is! Map) return null;

    final Map<String, dynamic> root = Map<String, dynamic>.from(data);
    final nested = root['data'];
    if (nested is Map) {
      return Map<String, dynamic>.from(nested);
    }
    return root;
  }

  Future<User?> login({required String email, required String password}) async {
    final resp = await _dio.post(
      '/api/auth/login',
      data: {'email': email, 'password': password},
    );
    final body = extractAuthPayload(resp.data);
    final access = body != null ? body['accessToken'] as String? : null;
    final refresh = body != null ? body['refreshToken'] as String? : null;

    await _storeTokens(access, refresh);

    final user = body != null && body['user'] != null
        ? User.fromMap(body['user'])
        : User(email: email);
    return user;
  }

  Future<bool> refreshToken() async {
    final refresh = await _storage.read(key: _refreshTokenKey);
    if (refresh == null || refresh.isEmpty) return false;

    try {
      final r = await _dio.post(
        '/api/auth/refresh',
        data: {'refreshToken': refresh},
      );
      final body = extractAuthPayload(r.data);
      final access = body != null ? body['accessToken'] as String? : null;
      final newRefresh = body != null ? body['refreshToken'] as String? : null;

      if (access != null && access.isNotEmpty) {
        await _storeTokens(access, newRefresh);
        return true;
      }
    } catch (e) {
      await logout();
      return false;
    }
    return false;
  }

  /// Returns true if the access token exists and is still valid
  /// (not expired and not within the proactive refresh window).
  Future<bool> hasValidAccessToken() async {
    final access = await _storage.read(key: _accessTokenKey);
    if (access == null || access.isEmpty) return false;
    return !(await _needsRefresh());
  }

  /// Returns true if the access token is missing, expired, or about to expire.
  Future<bool> needsRefresh() async => _needsRefresh();

  /// Proactively refreshes the token if it's about to expire.
  /// Returns true if a valid token is available after this call
  /// (either it was still valid, or it was successfully refreshed).
  Future<bool> ensureValidToken() async {
    if (await _needsRefresh()) {
      return refreshToken();
    }
    return true;
  }

  Future<void> logout() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _tokenTimestampKey);
  }

  Future<String?> getAccessToken() async {
    return _storage.read(key: _accessTokenKey);
  }

  Future<void> _storeTokens(String? access, String? refresh) async {
    if (access != null && access.isNotEmpty) {
      await _storage.write(key: _accessTokenKey, value: access);
      await _storage.write(
        key: _tokenTimestampKey,
        value: DateTime.now().millisecondsSinceEpoch.toString(),
      );
    }
    if (refresh != null && refresh.isNotEmpty) {
      await _storage.write(key: _refreshTokenKey, value: refresh);
    }
  }

  Future<bool> _needsRefresh() async {
    final access = await _storage.read(key: _accessTokenKey);
    if (access == null || access.isEmpty) return true;

    final timestampStr = await _storage.read(key: _tokenTimestampKey);
    if (timestampStr == null) {
      // No timestamp means we don't know when it expires; assume valid.
      return false;
    }

    final timestamp = int.tryParse(timestampStr);
    if (timestamp == null) return false;

    final now = DateTime.now().millisecondsSinceEpoch;
    final ageSeconds = (now - timestamp) ~/ 1000;
    final secondsRemaining = _accessTokenExpirySeconds - ageSeconds;

    // Refresh if expired or within the proactive refresh window.
    return secondsRemaining <= _refreshBeforeExpirySeconds;
  }
}