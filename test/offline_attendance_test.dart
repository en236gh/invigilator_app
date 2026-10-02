import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:invigilator_app/features/auth/data/auth_repository.dart';
import 'package:invigilator_app/core/network/interceptors/auth_interceptor.dart';
import 'package:invigilator_app/features/offline/application/offline_controller.dart';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:invigilator_app/features/offline/data/offline_repository.dart';
import 'package:invigilator_app/features/offline/domain/offline_snapshot.dart';

OfflineSnapshot snapshot([String owner = '1']) => OfflineSnapshot({
  'snapshotId': '9f9bd594-dfd4-4c6f-865d-c7f0054d4c53',
  'staffId': owner,
  'generatedAt': '2026-01-01T00:00:00Z',
  'assignments': [
    {
      'examSessionId': 5,
      'venueId': 16,
      'courseCode': 'CSC',
      'venueName': 'Lab',
      'status': 'SCHEDULED',
    },
  ],
  'students': [
    {
      'examSessionId': 5,
      'venueId': 16,
      'computerNumber': '2022004264',
      'fullName': 'Student One',
      'program': 'CS',
      'photoPath': '/photo',
      'attendanceStatus': null,
    },
  ],
});
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Database db;
  late Directory dir;
  late OfflineRepository repo;
  late Dio dio;
  Future<void> queue() => repo.queue(
    owner: '1',
    snapshot: snapshot(),
    assignment: snapshot().assignments.first,
    number: '2022004264',
    method: 'COMPUTER',
  );
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('offline-attendance');
    db = await databaseFactoryFfi.openDatabase(
      '${dir.path}/test.db',
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) => OfflineRepository.createTables(db),
      ),
    );
    dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    repo = OfflineRepository(dio: dio, database: () async => db);
  });
  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });
  test(
    'token-only login downloads and binds server staff ID with progress',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'offlineStaffId': 'previous-account',
      });
      final auth = AuthRepository(dio: dio);
      dio.interceptors.add(AuthInterceptor(client: dio, repository: auth));
      var downloads = 0;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path == '/api/auth/login') {
              handler.resolve(
                Response(
                  requestOptions: options,
                  data: {
                    'data': {
                      'accessToken': 'login-access',
                      'refreshToken': 'login-refresh',
                    },
                  },
                ),
              );
              return;
            }
            expect(options.headers['Authorization'], 'Bearer login-access');
            expect(options.path, '/api/attendance/offline-exam-data');
            expect(options.extra.containsKey('staffId'), false);
            downloads++;
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'success': true,
                  'data': {...snapshot('77').data, 'students': <Object>[]},
                },
              ),
            );
          },
        ),
      );
      final user = await auth.login(
        email: 'test@example.test',
        password: 'test',
      );
      expect(user!.id, isNull);
      expect((await auth.requestIdentity()).owner, isNull);
      final controller = OfflineController(
        null,
        repo,
        () => true,
        authRepository: auth,
      );
      try {
        await controller.download();
        expect(downloads, 1);
        expect(controller.owner, '77');
        expect(controller.snapshot!.owner, '77');
        expect(controller.downloadProgress, 1);
        expect(controller.downloadError, isNull);
        expect((await auth.requestIdentity()).owner, '77');
        expect(await repo.cached('previous-account'), isNull);
      } finally {
        controller.dispose();
      }
    },
  );
  test(
    'late roster response cannot bind or save into a new login session',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'accessToken': 'old',
        'refreshToken': 'old-refresh',
      });
      final auth = AuthRepository(dio: dio);
      dio.interceptors.add(AuthInterceptor(client: dio, repository: auth));
      final received = Completer<void>();
      final release = Completer<void>();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            if (options.path == '/api/auth/login') {
              handler.resolve(
                Response(
                  requestOptions: options,
                  data: {
                    'data': {
                      'accessToken': 'new',
                      'refreshToken': 'new-refresh',
                    },
                  },
                ),
              );
              return;
            }
            received.complete();
            await release.future;
            handler.resolve(
              Response(
                requestOptions: options,
                data: {'success': true, 'data': snapshot('old-owner').data},
              ),
            );
          },
        ),
      );
      final version = AuthRepository.sessionVersion;
      final download = repo.download(
        null,
        authSession: version,
        isCurrentSession: () => AuthRepository.sessionVersion == version,
        onOwnerResolved: (owner) => auth.bindOfflineOwner(owner, version),
      );
      final rejected = expectLater(download, throwsStateError);
      await received.future;
      await auth.login(email: 'new@example.test', password: 'test');
      release.complete();
      await rejected;
      expect((await auth.requestIdentity()).owner, isNull);
      expect(await repo.cached('old-owner'), isNull);
    },
  );
  test(
    'download progress completes only after saving, including failed photos',
    () async {
      final progress = <double>[];
      final stages = <String>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path == '/api/attendance/offline-exam-data') {
              options.onReceiveProgress?.call(50, 100);
              options.onReceiveProgress?.call(100, 100);
              handler.resolve(
                Response(
                  requestOptions: options,
                  data: {'success': true, 'data': snapshot().data},
                ),
              );
            } else {
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.connectionError,
                ),
              );
            }
          },
        ),
      );
      await repo.download(
        '1',
        onProgress: (value, stage) {
          progress.add(value);
          stages.add(stage);
        },
      );
      expect(progress.first, 0);
      expect(progress, orderedEquals([...progress]..sort()));
      expect(progress.last, 1);
      expect(progress.where((value) => value == 1).length, 1);
      expect(stages.last, contains('1 photos unavailable'));
      expect((await repo.cached('1'))!['photoFailures'], 1);
    },
  );
  test('failed SQLite save never reports 100 percent', () async {
    final progress = <double>[];
    final data = {...snapshot().data, 'students': <Object>[]};
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response(
              requestOptions: options,
              data: {'success': true, 'data': data},
            ),
          );
        },
      ),
    );
    final failingRepo = OfflineRepository(
      dio: dio,
      database: () async => throw StateError('Disk unavailable'),
    );
    await expectLater(
      failingRepo.download('1', onProgress: (value, _) => progress.add(value)),
      throwsStateError,
    );
    expect(progress, isNot(contains(1)));
    expect(await repo.cached('1'), isNull);
  });
  test(
    'snapshot parsing, photos and lookup are scoped to owner/exam/venue',
    () async {
      final s = snapshot();
      await repo.saveSnapshot(s, {
        '/photo': [1, 2, 3],
      }, 0);
      expect((await repo.cached('1'))!['payload'], s.encode());
      expect(await repo.cached('2'), isNull);
      expect(await repo.photo('2', '/photo'), isNull);
      expect(await repo.photo('1', '/photo'), [1, 2, 3]);
      expect(s.lookup(5, 16, '2022004264')?['fullName'], 'Student One');
      expect(s.lookup(5, 17, '2022004264'), isNull);
      expect(
        () => OfflineSnapshot({...s.data, 'generatedAt': 'bad'}),
        throwsFormatException,
      );
    },
  );
  test(
    'queue survives SQLite restart and rejects duplicates and cross-owner capture',
    () async {
      await queue();
      final original = (await repo.history('1')).single;
      await db.close();
      db = await databaseFactoryFfi.openDatabase('${dir.path}/test.db');
      expect((await repo.history('1')).single, original);
      expect(await repo.history('2'), isEmpty);
      await expectLater(queue(), throwsStateError);
      await expectLater(
        repo.queue(
          owner: '2',
          snapshot: snapshot(),
          assignment: snapshot().assignments.first,
          number: '2022004264',
          method: 'COMPUTER',
        ),
        throwsStateError,
      );
    },
  );
  test(
    'QR methods require token and retain supplied token with any method',
    () async {
      await expectLater(
        repo.queue(
          owner: '1',
          snapshot: snapshot(),
          assignment: snapshot().assignments.first,
          number: '2022004264',
          method: 'QR_CODE',
        ),
        throwsStateError,
      );
      await repo.queue(
        owner: '1',
        snapshot: snapshot(),
        assignment: snapshot().assignments.first,
        number: '2022004264',
        method: 'FACE_RECOGNITION',
        token: 'captured-pass',
      );
      final payload = jsonDecode(
        (await repo.history('1')).single['payload'] as String,
      );
      expect(payload['qrToken'], 'captured-pass');
      expect(payload['capturedAt'], endsWith('Z'));
    },
  );
  test(
    'network retry keeps identical UUID/payload and persists rejection',
    () async {
      await queue();
      final sent = <Object?>[];
      var fail = true;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            sent.add(jsonDecode(jsonEncode(options.data)));
            if (fail) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.receiveTimeout,
                ),
              );
              return;
            }
            final scan = (options.data['scans'] as List).single;
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'data': [
                    {
                      'scanId': scan['scanId'],
                      'outcome': 'REJECTED',
                      'reason': 'INVALID_QR',
                      'message': 'Revoked pass',
                      'processedAt': '2026-10-01T09:00:00Z',
                    },
                  ],
                },
              ),
            );
          },
        ),
      );
      await expectLater(
        repo.sync('1', () => true),
        throwsA(isA<DioException>()),
      );
      expect((await repo.history('1')).single['outcome'], isNull);
      fail = false;
      await repo.sync('1', () => true);
      expect(sent[0], sent[1]);
      expect((await repo.history('1')).single['reason'], 'INVALID_QR');
      await repo.sync('1', () => true);
      expect(sent.length, 2);
    },
  );
  test(
    '201 scans split 200/1; malformed item leaves siblings acknowledged',
    () async {
      await db.transaction((tx) async {
        for (var i = 0; i < 201; i++) {
          final id = OfflineRepository.newScanId();
          await tx.insert('offline_scans', {
            'scanId': id,
            'owner': '1',
            'payload': jsonEncode({'scanId': id}),
            'student': 'Test',
            'assignment': 'CSC',
          });
        }
      });
      final sizes = <int>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final scans = options.data['scans'] as List;
            sizes.add(scans.length);
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'data': [
                    for (var i = 0; i < scans.length; i++)
                      if (i == 0)
                        null
                      else
                        {
                          'scanId': scans[i]['scanId'],
                          'outcome': i == 1 ? 'ALREADY_RECORDED' : 'ACCEPTED',
                          'reason': 'RECORDED',
                          'message': 'Done',
                          'processedAt': '2026-10-01T09:00:00Z',
                          'attendanceId': i,
                        },
                  ],
                },
              ),
            );
          },
        ),
      );
      await repo.sync('1', () => true);
      expect(sizes, [200, 1]);
      final history = await repo.history('1');
      expect(history.where((r) => r['outcome'] == null).length, 2);
      expect(
        history.where((r) => r['outcome'] == 'ALREADY_RECORDED').length,
        1,
      );
      sizes.clear();
      await repo.sync('1', () => false);
      expect(sizes, isEmpty);
    },
  );
}
