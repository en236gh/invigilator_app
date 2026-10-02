import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invigilator_app/features/auth/data/auth_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const storage = FlutterSecureStorage();
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'accessToken': 'old-access',
      'refreshToken': 'old-refresh',
      'offlineStaffId': '1',
    });
  });
  test('concurrent refresh rotates both tokens before completing', () async {
    final dio = Dio();
    var requests = 0;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) {
          requests++;
          expect(o.data, {'refreshToken': 'old-refresh'});
          h.resolve(
            Response(
              requestOptions: o,
              data: {
                'data': {
                  'accessToken': 'new-access',
                  'refreshToken': 'new-refresh',
                },
              },
            ),
          );
        },
      ),
    );
    final repo = AuthRepository(dio: dio);
    expect(await Future.wait([repo.refreshToken(), repo.refreshToken()]), [
      true,
      true,
    ]);
    expect(requests, 1);
    expect(await storage.read(key: 'accessToken'), 'new-access');
    expect(await storage.read(key: 'refreshToken'), 'new-refresh');
  });
  test('refresh outage preserves credentials and staff ownership', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) => h.reject(
          DioException(
            requestOptions: o,
            type: DioExceptionType.connectionError,
          ),
        ),
      ),
    );
    expect(await AuthRepository(dio: dio).refreshToken(), false);
    expect(await storage.read(key: 'refreshToken'), 'old-refresh');
    expect(await storage.read(key: 'offlineStaffId'), '1');
  });
  test('login user ID is not assumed to be the offline staff ID', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) => h.resolve(
          Response(
            requestOptions: o,
            data: {
              'data': {
                'accessToken': 'new-access',
                'refreshToken': 'new-refresh',
                'user': {'id': 123},
              },
            },
          ),
        ),
      ),
    );
    final auth = AuthRepository(dio: dio);
    final user = await auth.login(email: 'test@example.test', password: 'test');
    expect(user!.id, '123');
    expect((await auth.requestIdentity()).owner, isNull);
    await auth.bindOfflineOwner('987', AuthRepository.sessionVersion);
    expect((await auth.requestIdentity()).owner, '987');
  });
  test('logout removes offline access but not the SQLite queue', () async {
    await AuthRepository().logout();
    expect(await storage.read(key: 'offlineStaffId'), isNull);
    expect(await storage.read(key: 'refreshToken'), isNull);
  });
}
