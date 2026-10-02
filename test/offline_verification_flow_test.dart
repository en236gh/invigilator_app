import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invigilator_app/features/offline/application/offline_controller.dart';
import 'package:invigilator_app/features/offline/presentation/offline_verification_flow.dart';
import 'package:invigilator_app/features/offline/presentation/offline_attendance_screen.dart';
import 'offline_capture_test.dart' show CaptureRepository;

String pass(String number) =>
    'header.${base64Url.encode(utf8.encode(jsonEncode({'sub': number}))).replaceAll('=', '')}.signature';

void main() {
  test('reads the pass subject and rejects unreadable identifiers', () {
    expect(offlinePassComputerNumber(pass('2022004264')), '2022004264');
    expect(offlinePassComputerNumber('invalid'), isNull);
    expect(offlinePassComputerNumber(pass('abc')), isNull);
  });

  testWidgets('exam selection precedes methods and focused capture', (
    tester,
  ) async {
    final repository = CaptureRepository();
    final controller = OfflineController('1', repository, () => true);
    await controller.load();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [offlineProvider.overrideWith((ref) => controller)],
        child: const MaterialApp(
          home: Scaffold(body: OfflineAttendanceScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Select exam or venue'), findsOneWidget);
    expect(find.text('Verification methods'), findsNothing);
    await tester.tap(find.text('Select exam and venue'));
    await tester.pumpAndSettle();
    expect(find.text('Verification methods'), findsOneWidget);
    expect(find.text('Select exam or venue'), findsNothing);
    await tester.tap(find.text('Computer number'));
    await tester.pumpAndSettle();
    expect(find.text('Enter computer number'), findsOneWidget);
    expect(find.text('QR code'), findsNothing);
    final back = find.byTooltip('Back');
    expect(tester.getSize(back).width, greaterThanOrEqualTo(48));
    expect(tester.getCenter(back).dy, greaterThan(500));
    await tester.tap(back);
    await tester.pumpAndSettle();
    expect(find.text('Verification methods'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Select exam or venue'), findsOneWidget);
  });

  testWidgets('exam cards and methods support enlarged text on a phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = CaptureRepository();
    final controller = OfflineController('1', repository, () => true);
    await controller.load();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [offlineProvider.overrideWith((ref) => controller)],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const Scaffold(body: OfflineAttendanceScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Select exam and venue'));
    await tester.tap(find.text('Select exam and venue'));
    await tester.pumpAndSettle();
    expect(find.text('Verification methods'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'reject discards scan, accept saves and automatically restores camera',
    (tester) async {
      final repository = CaptureRepository();
      repository.image.complete(null);
      final controller = OfflineController('1', repository, () => true);
      await controller.load();
      final assignment = controller.snapshot!.assignments.first;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [offlineProvider.overrideWith((ref) => controller)],
          child: MaterialApp(
            home: Scaffold(
              body: OfflineVerificationFlow(
                assignment: assignment,
                method: 'QR_CODE',
                cameraBuilder: (onScan) => TextButton(
                  onPressed: () => onScan(pass('2022004264')),
                  child: const Text('Test scan'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Test scan'));
      await tester.pumpAndSettle();
      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('Test scan'), findsNothing);
      await tester.tap(find.text('Reject'));
      await tester.pumpAndSettle();
      expect(repository.saves, 0);
      expect(find.text('Test scan'), findsOneWidget);
      await tester.tap(find.text('Test scan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();
      expect(repository.saves, 1);
      expect(find.text('Test scan'), findsOneWidget);
      expect(find.text('Scan the student’s QR code'), findsOneWidget);
    },
  );
}
