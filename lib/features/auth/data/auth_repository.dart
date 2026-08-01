import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/network/api_client.dart';
import '../domain/user.dart';

class AuthRepository {
	final Dio _dio = ApiClient.instance;
	final FlutterSecureStorage _storage = const FlutterSecureStorage();

	static Map<String, dynamic>? extractAuthPayload(dynamic data) {
		if (data is! Map) return null;

		final Map<String, dynamic> root = Map<String, dynamic>.from(data);
		final nested = root['data'];
		if (nested is Map) {
			return Map<String, dynamic>.from(nested as Map);
		}
		return root;
	}

	Future<User?> login({required String email, required String password}) async {
		final resp = await _dio.post('/api/auth/login', data: {'email': email, 'password': password});
		final body = extractAuthPayload(resp.data);
		final access = body != null ? body['accessToken'] as String? : null;
		final refresh = body != null ? body['refreshToken'] as String? : null;

		if (access != null) {
			await _storage.write(key: 'accessToken', value: access);
		}
		if (refresh != null) {
			await _storage.write(key: 'refreshToken', value: refresh);
		}

		final user = body != null && body['user'] != null ? User.fromMap(body['user']) : User(email: email);
		return user;
	}

	Future<bool> refreshToken() async {
		final refresh = await _storage.read(key: 'refreshToken');
		if (refresh == null || refresh.isEmpty) return false;

		try {
			final r = await _dio.post('/api/auth/refresh', data: {'refreshToken': refresh});
			final body = extractAuthPayload(r.data);
			final access = body != null ? body['accessToken'] as String? : null;
			final newRefresh = body != null ? body['refreshToken'] as String? : null;

			if (access != null && access.isNotEmpty) {
				await _storage.write(key: 'accessToken', value: access);
				if (newRefresh != null && newRefresh.isNotEmpty) {
					await _storage.write(key: 'refreshToken', value: newRefresh);
				}
				return true;
			}
		} catch (e) {
			await logout();
			return false;
		}
		return false;
	}

	Future<void> logout() async {
		await _storage.delete(key: 'accessToken');
		await _storage.delete(key: 'refreshToken');
	}
}
