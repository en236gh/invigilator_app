import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invigilator_app/features/offline/domain/offline_snapshot.dart';
import 'package:invigilator_app/features/sync/presentation/roster_details_panel.dart';

OfflineSnapshot snapshot({bool empty = false}) => OfflineSnapshot({
  'snapshotId': '11111111-1111-4111-8111-111111111111',
  'staffId': 1,
  'generatedAt': DateTime(2026, 10, 2, 7).toUtc().toIso8601String(),
  'assignments': empty
      ? []
      : [
          {
            'examSessionId': 1,
            'venueId': 1,
            'courseCode': 'CSC 400',
            'venueName': 'Main hall',
            'examDate': '2026-10-02',
            'startTime': '09:00:00',
            'endTime': '12:00:00',
            'status': 'PUBLISHED',
          },
        ],
  'students': empty
      ? []
      : [
          for (final path in ['photo-a', 'photo-a', 'photo-b', ''])
            {'examSessionId': 1, 'venueId': 1, 'photoPath': path},
        ],
});
Future<void> show(
  WidgetTester tester, {
  Map<String, Object?>? metadata,
  bool empty = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: RosterDetailsPanel(
            snapshot: snapshot(empty: empty),
            metadata: metadata,
            now: DateTime(2026, 10, 2, 10),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'today freshness, unique photo downloads and labeled assignments fit mobile',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await show(
        tester,
        metadata: {
          'downloadedAt': DateTime(
            2026,
            10,
            2,
            7,
            10,
          ).toUtc().toIso8601String(),
          'photoFailures': 1,
        },
      );
      expect(find.text('Downloaded today, 07:10'), findsOneWidget);
      expect(find.text('Roster generated'), findsOneWidget);
      expect(find.text('today, 07:00'), findsOneWidget);
      expect(find.text('2 downloaded · 1 unavailable'), findsOneWidget);
      expect(find.text('Assigned exams and venues (1)'), findsOneWidget);
      expect(find.text('Venue'), findsOneWidget);
      expect(find.text('Main hall'), findsOneWidget);
      expect(find.text('09:00–12:00'), findsOneWidget);
      expect(
        find.textContaining('Roster may have changed since download.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('older downloads show yesterday or an explicit date', (
    tester,
  ) async {
    await show(
      tester,
      metadata: {
        'downloadedAt': DateTime(2026, 10, 1, 7, 10).toUtc().toIso8601String(),
        'photoFailures': 0,
      },
    );
    expect(find.text('Downloaded yesterday, 07:10'), findsOneWidget);
    await show(
      tester,
      metadata: {
        'downloadedAt': DateTime(2026, 9, 28, 7, 10).toUtc().toIso8601String(),
        'photoFailures': 0,
      },
    );
    final context = tester.element(find.byType(RosterDetailsPanel));
    final date = MaterialLocalizations.of(
      context,
    ).formatMediumDate(DateTime(2026, 9, 28));
    expect(find.text('Downloaded $date, 07:10'), findsOneWidget);
  });
  testWidgets(
    'missing metadata and empty assignments show explicit fallback labels',
    (tester) async {
      await show(tester, empty: true);
      expect(find.text('Download time unavailable'), findsOneWidget);
      expect(find.text('Download status unavailable'), findsOneWidget);
      expect(find.text('No assigned exams in this download.'), findsOneWidget);
      expect(
        find.textContaining('Roster may have changed since download.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
