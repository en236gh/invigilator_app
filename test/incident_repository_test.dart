import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invigilator_app/core/network/api_client.dart';
import 'package:invigilator_app/features/examinations/application/exam_providers.dart';
import 'package:invigilator_app/features/examinations/domain/exam_assignment.dart';
import 'package:invigilator_app/features/incidents/presentation/incidents_screen.dart';
import 'package:invigilator_app/features/incidents/data/incident_repository.dart';

class _Adapter implements HttpClientAdapter {
  Map<String, dynamic>? submitted;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'GET') {
      return ResponseBody.fromString(
        '{"data":[]}',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    submitted = Map<String, dynamic>.from(options.data as Map);
    return ResponseBody.fromString(
      jsonEncode({
        'data': {...submitted!, 'incidentId': 1},
      }),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _SelectedExam extends SelectedExamNotifier {
  @override
  ExamAssignment? build() => ExamAssignment(
    examSessionId: 7,
    venueId: 2,
    courseCode: 'CSC 401',
    examDate: '2026-10-03',
    startTime: '09:00',
    endTime: '12:00',
    examStatus: 'IN_PROGRESS',
    venueName: 'Computer Lab',
    building: 'ICT',
    capacity: 64,
    lecturers: [],
  );
}

void main() {
  testWidgets(
    'narrow phone shows full incident labels and validates required fields',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final dio = ApiClient.instance;
      final oldAdapter = dio.httpClientAdapter;
      final oldInterceptors = dio.interceptors.toList();
      dio.interceptors.clear();
      dio.httpClientAdapter = _Adapter();
      addTearDown(() {
        dio.httpClientAdapter = oldAdapter;
        dio.interceptors.addAll(oldInterceptors);
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [selectedExamProvider.overrideWith(_SelectedExam.new)],
          child: const MaterialApp(home: Scaffold(body: IncidentsScreen())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('CSC 401'), findsOneWidget);
      expect(find.text('Student number (optional)'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Medical Emergency').last);
      await tester.pumpAndSettle();
      expect(find.text('Medical Emergency'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Report incident'));
      await tester.tap(find.text('Report incident'));
      await tester.pumpAndSettle();
      expect(find.text('Select severity.'), findsOneWidget);
      expect(
        find.text('Describe the incident before submitting.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final severity in ['MINOR', 'MAJOR', 'CRITICAL']) {
    test(
      'submits selected $severity severity and examination context',
      () async {
        final adapter = _Adapter();
        final dio = Dio()..httpClientAdapter = adapter;
        final record = await IncidentRepository(dio: dio).reportIncident(
          examSessionId: 7,
          venueId: 2,
          incidentType: 'WRONG_VENUE',
          severity: severity,
          description: 'Student arrived at the wrong venue.',
          evidencePath: 'https://example.com/evidence.jpg',
        );
        expect(adapter.submitted!['severity'], severity);
        expect(adapter.submitted!['examSessionId'], 7);
        expect(adapter.submitted!['venueId'], 2);
        expect(
          adapter.submitted!['evidencePath'],
          'https://example.com/evidence.jpg',
        );
        expect(adapter.submitted!.containsKey('computerNumber'), isFalse);
        expect(record.severity, severity);
        dio.close();
      },
    );
  }
}
