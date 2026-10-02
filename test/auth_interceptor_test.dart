import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invigilator_app/core/network/interceptors/auth_interceptor.dart';
import 'package:invigilator_app/features/auth/data/auth_repository.dart';

class Adapter implements HttpClientAdapter {
  Adapter(this.respond);
  final Future<ResponseBody> Function(RequestOptions) respond;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => respond(options);
  @override
  void close({bool force = false}) {}
}

ResponseBody body(int status, Object data) => ResponseBody.fromString(
  jsonEncode(data),
  status,
  headers: {
    Headers.contentTypeHeader: ['application/json'],
  },
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const storage = FlutterSecureStorage();
  setUp(
    () => FlutterSecureStorage.setMockInitialValues({
      'offlineStaffId': '1',
      'accessToken': 'old',
      'refreshToken': 'refresh',
    }),
  );
  test(
    '401 refresh persists rotated pair before replaying the identical batch',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
      final repo = AuthRepository(dio: dio);
      dio.interceptors.add(AuthInterceptor(client: dio, repository: repo));
      final sent = <Object?>[];
      dio.httpClientAdapter = Adapter((o) async {
        if (o.path.endsWith('/refresh')) {
          return body(200, {
            'data': {'accessToken': 'new', 'refreshToken': 'rotated'},
          });
        }
        sent.add(o.data);
        if (sent.length == 1) return body(401, {});
        expect(await storage.read(key: 'refreshToken'), 'rotated');
        expect(o.headers['Authorization'], 'Bearer new');
        return body(200, {'data': []});
      });
      await dio.post(
        '/api/attendance/sync',
        data: {
          'scans': [
            {'scanId': 'fixed-id'},
          ],
        },
        options: Options(extra: {'staffId': '1'}),
      );
      expect(sent.length, 2);
      expect(sent[0], sent[1]);
    },
  );
  test('403 permission failure does not trigger blind token refresh', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    dio.interceptors.add(
      AuthInterceptor(
        client: dio,
        repository: AuthRepository(dio: dio),
      ),
    );
    var requests = 0;
    dio.httpClientAdapter = Adapter((o) async {
      requests++;
      expect(o.path, '/api/attendance/sync');
      return body(403, {});
    });
    await expectLater(
      dio.post(
        '/api/attendance/sync',
        options: Options(extra: {'staffId': '1'}),
      ),
      throwsA(isA<DioException>()),
    );
    expect(requests, 1);
  });
  test(
    'account mismatch prevents the queue from reaching the network',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
      dio.interceptors.add(
        AuthInterceptor(
          client: dio,
          repository: AuthRepository(dio: dio),
        ),
      );
      dio.httpClientAdapter = Adapter((_) async {
        fail('Cross-account network submission');
      });
      await expectLater(
        dio.post(
          '/api/attendance/sync',
          options: Options(extra: {'staffId': '2'}),
        ),
        throwsA(isA<DioException>()),
      );
    },
  );
}
