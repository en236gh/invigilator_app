import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invigilator_app/features/offline/application/offline_controller.dart';
import 'package:invigilator_app/features/sync/presentation/sync_status_screen.dart';
import 'offline_capture_test.dart' show CaptureRepository;

class SyncProgressRepository extends CaptureRepository {
  final finish = Completer<void>();
  int requests = 0;
  final rows = <Map<String, Object?>>[
    for (var i = 0; i < 2; i++)
      {
        'id': i,
        'scanId': 'scan-$i',
        'student': 'Student $i',
        'assignment': 'CSC · Lab',
        'payload': jsonEncode({'computerNumber': '202200426$i'}),
        'outcome': null,
      },
  ];
  @override
  Future<List<Map<String, Object?>>> history(String owner) async =>
      rows.map((row) => Map<String, Object?>.from(row)).toList();
  @override
  Future<void> sync(String owner, bool Function() stillOwner) async {
    requests++;
    await finish.future;
  }
}

void main() {
  testWidgets('manual sync shows live pending, synced and completion stages', (
    tester,
  ) async {
    final repository = SyncProgressRepository();
    final controller = OfflineController('1', repository, () => true);
    await controller.load();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [offlineProvider.overrideWith((ref) => controller)],
        child: const MaterialApp(home: Scaffold(body: SyncStatusScreen())),
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.requests, 0);
    expect(find.text('Pending (2)'), findsOneWidget);
    await tester.tap(find.text('Sync to server'));
    await tester.pump();
    expect(find.text('Syncing attendance'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
    repository.rows.first['outcome'] = 'ACCEPTED';
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.text('Pending (1)'), findsOneWidget);
    expect(find.text('Synced (1)'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(controller.syncProgress, 0.5);
    repository.rows.last['outcome'] = 'ALREADY_RECORDED';
    repository.finish.complete();
    await tester.pumpAndSettle();
    expect(find.text('Sync successful'), findsOneWidget);
    expect(find.text('Pending (1)'), findsNothing);
    expect(find.text('Synced (2)'), findsOneWidget);
    expect(find.text('Attendance already recorded'), findsOneWidget);
  });
}
