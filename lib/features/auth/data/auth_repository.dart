import 'package:synchronized/synchronized.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/network/api_client.dart';
import '../domain/user.dart';

class AuthRepository {
  AuthRepository({Dio? dio}) : _client = dio;
  final Dio? _client;
  Dio get _dio => _client ?? ApiClient.instance;
  static int _sessionVersion = 0;
  static int get sessionVersion => _sessionVersion;
  static final _credentialsLock = Lock();

  Future<({String? access, String? owner, int sessionVersion})>
  requestIdentity() => _credentialsLock.synchronized(
    () async => (
      access: await _storage.read(key: _accessTokenKey),
      owner: await _storage.read(key: 'offlineStaffId'),
      sessionVersion: _sessionVersion,
    ),
  );
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

    if (access == null ||
        access.isEmpty ||
        refresh == null ||
        refresh.isEmpty) {
      throw const FormatException('Incomplete login credentials');
    }
    final user = body != null && body['user'] is Map
        ? User.fromMap(body['user'])
        : User(email: email);
    await _credentialsLock.synchronized(() async {
      _sessionVersion++;
      await _storage.delete(key: 'staffId');
      await _storage.delete(key: 'offlineStaffId');
      await _storeTokens(access, refresh);
    });
    return user;
  }

  /// Bind server-returned ownership only to the session that requested it.
  Future<void> bindOfflineOwner(String owner, int version) =>
      _credentialsLock.synchronized(() async {
        if (version != _sessionVersion ||
            (await _storage.read(key: _accessTokenKey))?.isNotEmpty != true) {
          throw StateError('Account changed during download. Sign in again.');
        }
        final existing = await _storage.read(key: 'offlineStaffId');
        if (existing != null && existing != owner) {
          throw StateError('Snapshot ownership changed. Sign in again.');
        }
        await _storage.write(key: 'offlineStaffId', value: owner);
      });

  static Future<bool>? _refreshing;

  Future<bool> refreshToken() =>
      _refreshing ??= _refreshOnce().whenComplete(() => _refreshing = null);

  Future<bool> _refreshOnce() async {
    final version = _sessionVersion;
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

      if (access != null &&
          access.isNotEmpty &&
          newRefresh != null &&
          newRefresh.isNotEmpty) {
        return _credentialsLock.synchronized(() async {
          if (version != _sessionVersion) return false;
          await _storeTokens(access, newRefresh);
          return true;
        });
      }
    } catch (e) {
      // Network failure must not destroy the rotating refresh credential.
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

  Future<void> logout() => _credentialsLock.synchronized(() async {
    _sessionVersion++;
    await _storage.delete(key: 'staffId');
    await _storage.delete(key: 'offlineStaffId');
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _tokenTimestampKey);
  });

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
