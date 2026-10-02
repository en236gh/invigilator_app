import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/app_database.dart';
import '../../../core/network/api_client.dart';
import '../domain/offline_snapshot.dart';

class OfflineRepository {
  OfflineRepository({Dio? dio, Future<Database> Function()? database})
    : dio = dio ?? ApiClient.instance,
      database = database ?? (() => AppDatabase.database);
  final Dio dio;
  final Future<Database> Function() database;

  static Future<void> createTables(DatabaseExecutor db) async {
    await db.execute(
      'CREATE TABLE offline_snapshots(owner TEXT PRIMARY KEY, payload TEXT NOT NULL, downloadedAt TEXT NOT NULL, photoFailures INTEGER NOT NULL)',
    );
    await db.execute(
      'CREATE TABLE offline_photos(owner TEXT NOT NULL, path TEXT NOT NULL, bytes BLOB NOT NULL, PRIMARY KEY(owner,path))',
    );
    await db.execute(
      'CREATE TABLE offline_scans(scanId TEXT PRIMARY KEY, owner TEXT NOT NULL, payload TEXT NOT NULL, student TEXT NOT NULL, assignment TEXT NOT NULL, outcome TEXT, reason TEXT, message TEXT, attendanceId INTEGER, processedAt TEXT)',
    );
    await db.execute(
      'CREATE INDEX offline_scans_owner ON offline_scans(owner,outcome)',
    );
  }

  Future<Map<String, Object?>?> cached(String owner) async {
    final rows = await (await database()).query(
      'offline_snapshots',
      where: 'owner=?',
      whereArgs: [owner],
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, Object?>>> history(String owner) async =>
      (await database()).query(
        'offline_scans',
        where: 'owner=?',
        whereArgs: [owner],
        orderBy: 'rowid DESC',
      );
  Future<Uint8List?> photo(String owner, String path) async {
    final rows = await (await database()).query(
      'offline_photos',
      where: 'owner=? AND path=?',
      whereArgs: [owner, path],
    );
    return rows.isEmpty ? null : rows.first['bytes'] as Uint8List;
  }

  Future<String> download(
    String? owner, {
    int? authSession,
    Future<void> Function(String owner)? onOwnerResolved,
    bool Function()? isCurrentSession,
    void Function(double progress, String stage)? onProgress,
  }) async {
    onProgress?.call(0, 'Downloading assigned exams and students…');
    final response = await dio.get(
      '/api/attendance/offline-exam-data',
      onReceiveProgress: (received, total) {
        if (received > 0 && total <= 0) {
          // A response confirms reachability even without a content length.
          onProgress?.call(0.001, 'Downloading assigned exams and students…');
        }
        if (total > 0) {
          onProgress?.call(
            0.3 * (received / total).clamp(0, 1),
            'Downloading assigned exams and students…',
          );
        }
      },
      options: Options(extra: {'staffId': ?owner, 'authSession': ?authSession}),
    );
    if (response.data is! Map || response.data['success'] != true) {
      throw const FormatException('Download failed');
    }
    final snapshot = OfflineSnapshot(
      Map<String, dynamic>.from(response.data['data'] as Map),
    );
    if (isCurrentSession != null && !isCurrentSession()) {
      throw StateError('Account changed during download');
    }
    if (owner != null && snapshot.owner != owner) {
      throw StateError('Snapshot belongs to a different staff account');
    }
    await onOwnerResolved?.call(snapshot.owner);
    final photos = <String, List<int>>{};
    var failures = 0;
    final paths = snapshot.students
        .map((s) => '${s['photoPath'] ?? ''}')
        .toSet();
    var completed = 0;
    onProgress?.call(0.3, 'Caching student photos: 0/${paths.length}');
    for (final path in paths) {
      if (isCurrentSession != null && !isCurrentSession()) {
        throw StateError('Account changed during download');
      }
      try {
        if (path.isEmpty) {
          failures++;
          continue;
        }
        final uri = Uri.parse(dio.options.baseUrl).resolve(path);
        // Never forward bearer credentials to an external image host.
        if (uri.origin != Uri.parse(dio.options.baseUrl).origin) {
          failures++;
          continue;
        }
        final response = await dio.get<List<int>>(
          uri.toString(),
          options: Options(
            responseType: ResponseType.bytes,
            followRedirects: false,
            extra: {'staffId': snapshot.owner, 'authSession': ?authSession},
          ),
        );
        if (response.data == null || response.data!.isEmpty) {
          failures++;
          continue;
        }
        photos[path] = response.data!;
      } catch (_) {
        failures++;
      } finally {
        completed++;
        onProgress?.call(
          0.3 + 0.6 * completed / paths.length,
          'Caching student photos: $completed/${paths.length}',
        );
      }
    }
    if (isCurrentSession != null && !isCurrentSession()) {
      throw StateError('Account changed during download');
    }
    onProgress?.call(0.9, 'Saving offline data on this device…');
    await saveSnapshot(snapshot, photos, failures);
    onProgress?.call(
      1,
      failures == 0
          ? 'Offline data ready'
          : 'Offline data ready · $failures photos unavailable',
    );
    return snapshot.owner;
  }

  Future<void> saveSnapshot(
    OfflineSnapshot snapshot,
    Map<String, List<int>> photos,
    int failures,
  ) async {
    await (await database()).transaction((tx) async {
      await tx.insert('offline_snapshots', {
        'owner': snapshot.owner,
        'payload': snapshot.encode(),
        'downloadedAt': DateTime.now().toUtc().toIso8601String(),
        'photoFailures': failures,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      for (final entry in photos.entries) {
        await tx.insert('offline_photos', {
          'owner': snapshot.owner,
          'path': entry.key,
          'bytes': Uint8List.fromList(entry.value),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  static String newScanId() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<void> queue({
    required String owner,
    required OfflineSnapshot snapshot,
    required Map<String, dynamic> assignment,
    required String number,
    required String method,
    String? token,
  }) async {
    final student = snapshot.lookup(
      assignment['examSessionId'] as int,
      assignment['venueId'] as int,
      number,
    );
    if (snapshot.owner != owner || student == null) {
      throw StateError(
        'Student is not in this account’s exam and venue roster',
      );
    }
    if (!RegExp(r'^\d{10}$').hasMatch(number) ||
        !verificationMethods.contains(method) ||
        (method.startsWith('QR') && (token == null || token.isEmpty))) {
      throw StateError(
        'A valid computer number and captured token for QR methods are required',
      );
    }
    if (assignment['status'] == 'COMPLETED' ||
        student['attendanceStatus'] != null) {
      throw StateError(
        'Cached attendance or exam status blocks a new scan. Review online.',
      );
    }
    final now = DateTime.now().toUtc();
    if (now.isBefore(snapshot.generatedAt)) {
      throw StateError(
        'Device clock precedes snapshot generation. Correct the clock.',
      );
    }
    final payload = {
      'scanId': newScanId(),
      'snapshotId': snapshot.id,
      'examSessionId': assignment['examSessionId'],
      'venueId': assignment['venueId'],
      'computerNumber': number,
      if (token != null && token.isNotEmpty) 'qrToken': token,
      'verificationMethod': method,
      'capturedAt': now.toIso8601String(),
    };
    await (await database()).transaction((tx) async {
      final existing = await tx.query(
        'offline_scans',
        where: 'owner=?',
        whereArgs: [owner],
      );
      for (final row in existing) {
        final prior = jsonDecode(row['payload'] as String) as Map;
        if (prior['examSessionId'] == payload['examSessionId'] &&
            prior['computerNumber'] == number &&
            row['outcome'] != 'REJECTED') {
          throw StateError(
            'This student already has a pending or recorded scan',
          );
        }
      }
      await tx.insert('offline_scans', {
        'scanId': payload['scanId'],
        'owner': owner,
        'payload': jsonEncode(payload),
        'student': student['fullName'],
        'assignment':
            '${assignment['courseCode']} · ${assignment['venueName']}',
      });
    });
  }

  Future<void> sync(String owner, bool Function() stillOwner) async {
    final pending = (await history(
      owner,
    )).where((r) => r['outcome'] == null).toList();
    for (var offset = 0; offset < pending.length; offset += 200) {
      if (!stillOwner()) return;
      final batch = pending.skip(offset).take(200).toList();
      final response = await dio.post(
        '/api/attendance/sync',
        data: {
          'scans': batch
              .map((r) => jsonDecode(r['payload'] as String))
              .toList(),
        },
        options: Options(extra: {'staffId': owner}),
      );
      if (response.data is! Map ||
          response.data['success'] == false ||
          response.data['data'] is! List) {
        throw const FormatException(
          'Invalid sync response; scans remain pending',
        );
      }
      final results = response.data['data'] as List;
      for (var i = 0; i < results.length && i < batch.length; i++) {
        final r = results[i];
        if (r is! Map ||
            r['scanId'] != batch[i]['scanId'] ||
            ![
              'ACCEPTED',
              'ALREADY_RECORDED',
              'REJECTED',
            ].contains(r['outcome']) ||
            r['reason'] is! String ||
            r['message'] is! String ||
            r['processedAt'] is! String ||
            DateTime.tryParse(r['processedAt']) == null ||
            (r['attendanceId'] != null && r['attendanceId'] is! int)) {
          continue;
        }
        await (await database()).update(
          'offline_scans',
          {
            'outcome': r['outcome'],
            'reason': r['reason'],
            'message': r['message'],
            'attendanceId': r['attendanceId'],
            'processedAt': r['processedAt'],
          },
          where: 'owner=? AND scanId=? AND outcome IS NULL',
          whereArgs: [owner, r['scanId']],
        );
      }
    }
  }
}
