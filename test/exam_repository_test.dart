import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invigilator_app/features/examinations/data/exam_repository.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);
  final ResponseBody Function(RequestOptions) respond;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => respond(options);

  @override
  void close({bool force = false}) {}
}

ResponseBody _body(Object data, {int status = 200}) => ResponseBody.fromString(
  jsonEncode({'data': data}),
  status,
  headers: {
    Headers.contentTypeHeader: ['application/json'],
  },
);

void main() {
  test('counts allocated students separately for each exam venue', () async {
    final dio = Dio();
    final paths = <String>[];
    dio.httpClientAdapter = _Adapter((request) {
      paths.add(request.path);
      if (request.path == '/api/invigilator/assignments') {
        return _body([
          {'examSessionId': 7, 'venueId': 1, 'capacity': 100},
          {'examSessionId': 7, 'venueId': 2, 'capacity': 200},
        ]);
      }
      if (request.path == '/api/invigilator/assignments/7/1/students') {
        return _body([
          {'computer_number': '1', 'attendance_status': 'PRESENT'},
          {'computer_number': '2', 'attendance_status': null},
        ]);
      }
      expect(request.path, '/api/invigilator/assignments/7/2/students');
      return _body([]);
    });

    final assignments = await ExamRepository(dio: dio).fetchAssignments();
    expect(assignments.map((exam) => exam.studentCount), [2, 0]);
    expect(paths.length, 3);
  });

  test(
    'roster failure keeps assignments without using capacity as count',
    () async {
      final dio = Dio();
      dio.httpClientAdapter = _Adapter((request) {
        if (request.path == '/api/invigilator/assignments') {
          return _body([
            {'examSessionId': 7, 'venueId': 1, 'capacity': 100},
          ]);
        }
        return _body({}, status: 503);
      });

      final assignments = await ExamRepository(dio: dio).fetchAssignments();
      expect(assignments.single.studentCount, isNull);
      expect(assignments.single.capacity, 100);
    },
  );
}
