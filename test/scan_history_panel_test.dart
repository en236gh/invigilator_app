import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invigilator_app/features/sync/presentation/scan_history_panel.dart';

Map<String, Object?> scan(int i, [String? outcome]) => {
  'student': 'Student $i',
  'assignment': 'CSC 400 Venue A',
  'outcome': outcome,
  'reason': 'ALLOCATION_CHANGED',
  'message': 'Venue allocation changed',
  'payload': jsonEncode({
    'computerNumber': '202200${i.toString().padLeft(4, '0')}',
    'capturedAt': '2026-10-02T10:42:00+02:00',
  }),
};
Future<void> show(WidgetTester tester, List<Map<String, Object?>> scans) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: ScanHistoryPanel(scans: scans)),
      ),
    ),
  );
}

Future<void> press(WidgetTester tester, String label) async {
  final target = label == 'Clear search'
      ? find.byTooltip(label)
      : find.text(label);
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('results stay concise until details are expanded', (
    tester,
  ) async {
    await show(tester, [scan(2, 'REJECTED')]);
    final local = DateTime.parse('2026-10-02T10:42:00+02:00').toLocal();
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    expect(find.textContaining('Captured $time'), findsOneWidget);
    expect(
      find.textContaining('Needs review · attendance not recorded'),
      findsOneWidget,
    );
    expect(find.text('Reason: ALLOCATION_CHANGED'), findsNothing);
    expect(find.textContaining('Next steps:'), findsNothing);
    await press(tester, 'Student 2 · 2022000002');
    expect(find.text('Reason: ALLOCATION_CHANGED'), findsOneWidget);
    expect(
      find.text('Server message: Venue allocation changed'),
      findsOneWidget,
    );
    expect(find.text('Captured at: 2026-10-02T10:42:00+02:00'), findsOneWidget);
    expect(find.textContaining('Next steps:'), findsOneWidget);
  });

  testWidgets('completed results distinguish new and existing attendance', (
    tester,
  ) async {
    await show(tester, [scan(3, 'ACCEPTED'), scan(4, 'ALREADY_RECORDED')]);
    expect(find.textContaining('New attendance recorded'), findsOneWidget);
    expect(
      find.textContaining('Already recorded · no new attendance added'),
      findsOneWidget,
    );
  });

  testWidgets('review shortcut opens rejected scans without manual filtering', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ScanHistoryPanel(
              initialFilter: ScanHistoryFilter.review,
              scans: [
                scan(1),
                scan(2, 'REJECTED'),
                scan(3, 'ACCEPTED'),
                scan(4, 'ALREADY_RECORDED'),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.text('Student 2 · 2022000002'), findsOneWidget);
    expect(find.byType(Card), findsOneWidget);
    final chip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'Needs review'),
    );
    expect(chip.selected, isTrue);
  });
  testWidgets('pagination limits rows and search resets to the first page', (
    tester,
  ) async {
    await show(tester, List.generate(45, (i) => scan(i)));
    expect(find.byType(Card), findsNWidgets(20));
    expect(find.text('Showing 1–20 of 45 scans'), findsOneWidget);
    await press(tester, 'Next');
    expect(find.text('Showing 21–40 of 45 scans'), findsOneWidget);
    await press(tester, 'Next');
    expect(find.byType(Card), findsNWidgets(5));
    expect(find.text('Page 3 of 3'), findsOneWidget);
    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(find.byType(TextField), '2022000001');
    await tester.pumpAndSettle();
    expect(find.byType(Card), findsOneWidget);
    expect(find.text('Page 1 of 1'), findsOneWidget);
    await press(tester, 'Clear search');
    expect(find.byType(Card), findsNWidgets(20));
  });
  testWidgets(
    'filters distinguish pending, rejected and both completed outcomes',
    (tester) async {
      await show(tester, [
        scan(1),
        scan(2, 'REJECTED'),
        scan(3, 'ACCEPTED'),
        scan(4, 'ALREADY_RECORDED'),
      ]);
      await press(tester, 'Needs review');
      expect(find.byType(Card), findsOneWidget);
      expect(find.text('Student 2 · 2022000002'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'allocation');
      await tester.pumpAndSettle();
      expect(find.byType(Card), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'missing');
      await tester.pumpAndSettle();
      expect(
        find.text('No scans match this search and filter.'),
        findsOneWidget,
      );
      await press(tester, 'Clear search');
      await press(tester, 'Completed');
      expect(find.byType(Card), findsNWidgets(2));
      await press(tester, 'Pending');
      expect(find.text('Student 1 · 2022000001'), findsOneWidget);
    },
  );
  testWidgets(
    'sync shrinking results clamps the page and handles empty queues',
    (tester) async {
      await show(tester, List.generate(21, (i) => scan(i)));
      await press(tester, 'Pending');
      await press(tester, 'Next');
      expect(find.text('Page 2 of 2'), findsOneWidget);
      await show(tester, [scan(0)]);
      expect(find.text('Page 1 of 1'), findsOneWidget);
      expect(find.byType(Card), findsOneWidget);
      await show(tester, []);
      expect(
        find.text('No scans saved on this device for this account.'),
        findsOneWidget,
      );
    },
  );
}
