import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invigilator_app/features/offline/application/offline_controller.dart';
import 'package:invigilator_app/features/offline/data/offline_repository.dart';
import 'package:invigilator_app/features/offline/presentation/offline_capture.dart';
import 'offline_attendance_test.dart' show snapshot;

class CaptureRepository extends OfflineRepository {
  final image = Completer<Uint8List?>();
  int saves = 0;
  @override
  Future<Map<String, Object?>?> cached(String owner) async => {
    'payload': snapshot().encode(),
  };
  @override
  Future<List<Map<String, Object?>>> history(String owner) async => [];
  @override
  Future<void> sync(String owner, bool Function() stillOwner) async {}
  @override
  Future<Uint8List?> photo(String owner, String path) => image.future;
  @override
  Future<void> queue({
    required String owner,
    required dynamic snapshot,
    required Map<String, dynamic> assignment,
    required String number,
    required String method,
    String? token,
  }) async {
    saves++;
  }
}

Future<void> tap(WidgetTester tester, String text) async {
  final target = find.text(text);
  await tester.pump();
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pump();
}

void main() {
  testWidgets(
    'guided capture validates input, loads photo and retains save receipt',
    (tester) async {
      final repository = CaptureRepository();
      final controller = OfflineController('1', repository, () => true);
      await controller.load();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [offlineProvider.overrideWith((ref) => controller)],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: OfflineCapture()),
            ),
          ),
        ),
      );
      expect(find.text('10-digit computer number'), findsNothing);
      await tap(tester, 'Exam and venue');
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('CSC · Lab').last);
      await tester.pumpAndSettle();
      await tap(tester, 'Use this exam and venue');
      await tester.enterText(find.byType(TextField).first, 'abc');
      await tester.pump();
      expect(find.text('Use numeric characters only.'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, '123');
      await tester.pump();
      expect(find.text('Enter exactly 10 digits (3/10).'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, '1234567890');
      await tap(tester, 'Find student locally');
      expect(
        find.textContaining('Valid computer number, but no match'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField).first, '2022004264');
      await tap(tester, 'Find student locally');
      expect(find.text('Loading downloaded photo…'), findsOneWidget);
      expect(find.text('Selected exam and venue'), findsOneWidget);
      repository.image.complete(null);
      await tester.pumpAndSettle();
      expect(find.text('Downloaded photo unavailable'), findsOneWidget);
      expect(find.text('Last downloaded status: not recorded'), findsOneWidget);
      final save = find.widgetWithText(FilledButton, 'Save pending scan');
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      await tap(
        tester,
        'I confirmed this student’s identity for the selected exam and venue.',
      );
      await tap(tester, 'Save pending scan');
      await tester.pumpAndSettle();
      expect(repository.saves, 1);
      expect(find.text('Pending scan saved'), findsOneWidget);
      expect(
        find.textContaining(
          'Student One · 2022004264\nCSC · Lab\nSaved on this device',
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('QR and facial methods require explicit confirmations', (
    tester,
  ) async {
    final repository = CaptureRepository();
    repository.image.complete(null);
    final controller = OfflineController('1', repository, () => true);
    await controller.load();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [offlineProvider.overrideWith((ref) => controller)],
        child: const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: OfflineCapture())),
        ),
      ),
    );
    await tap(tester, 'Exam and venue');
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('CSC · Lab').last);
    await tester.pumpAndSettle();
    await tap(tester, 'Use this exam and venue');
    await tap(tester, 'Computer number and ID');
    await tester.pumpAndSettle();
    await tester.tap(find.text('QR pass and separate facial check').last);
    await tester.pumpAndSettle();
    expect(find.text('No in-app facial check'), findsOneWidget);
    expect(find.text('QR not validated offline'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '2022004264');
    await tester.enterText(find.byType(TextField).last, 'unvalidated-token');
    await tap(tester, 'Find student locally');
    await tester.pumpAndSettle();
    final save = find.widgetWithText(FilledButton, 'Save pending scan');
    await tap(
      tester,
      'I confirmed this student’s identity for the selected exam and venue.',
    );
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    await tap(tester, 'I completed a separate facial comparison.');
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    await tap(tester, 'I understand that this QR pass has not been validated.');
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
    await tap(tester, 'Change exam and venue (clears current student)');
    expect(find.text('Student One · 2022004264'), findsNothing);
    await tap(tester, 'Use this exam and venue');
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      isEmpty,
    );
    await tester.pumpWidget(const SizedBox());
  });
}
