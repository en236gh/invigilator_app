import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../domain/exam_assignment.dart';

class ExamRepository {
  ExamRepository({Dio? dio}) : _dio = dio ?? ApiClient.instance;

  final Dio _dio;

  Future<List<ExamAssignment>> fetchAssignments() async {
    final resp = await _dio.get('/api/invigilator/assignments');
    final data = resp.data is Map ? resp.data['data'] ?? resp.data : resp.data;
    if (data is List) {
      final assignments = data
          .whereType<Map<String, dynamic>>()
          .map(ExamAssignment.fromMap)
          .toList();
      return Future.wait(assignments.map(_withExpectedStudentCount));
    }
    return [];
  }

  Future<ExamAssignment> _withExpectedStudentCount(
    ExamAssignment assignment,
  ) async {
    try {
      final response = await _dio.get(
        '/api/invigilator/assignments/${assignment.examSessionId}/${assignment.venueId}/students',
      );
      final roster = response.data is Map
          ? response.data['data'] ?? response.data
          : response.data;
      if (roster is List) {
        return assignment.copyWith(studentCount: roster.length);
      }
    } on DioException {
      // Keep the dashboard usable if a roster cannot be retrieved.
    }
    return assignment;
  }

  /// Marks the exam `IN_PROGRESS` for tracking exam timing.
  Future<String> startSession({
    required int examSessionId,
    required int venueId,
  }) async {
    final resp = await _dio.post(
      '/api/invigilator/assignments/$examSessionId/$venueId/start',
    );
    final data = resp.data is Map ? resp.data['data'] ?? resp.data : resp.data;
    if (data is Map && data['examStatus'] != null) {
      return '${data['examStatus']}';
    }
    return 'IN_PROGRESS';
  }

  /// Marks the exam `COMPLETED` and records ABSENT for students with no attendance.
  Future<String> endSession({
    required int examSessionId,
    required int venueId,
  }) async {
    final resp = await _dio.post(
      '/api/invigilator/assignments/$examSessionId/$venueId/end',
    );
    final data = resp.data is Map ? resp.data['data'] ?? resp.data : resp.data;
    if (data is Map && data['examStatus'] != null) {
      return '${data['examStatus']}';
    }
    return 'COMPLETED';
  }

  Future<Map<String, dynamic>> getDashboardSummary() async {
    final resp = await _dio.get('/api/dashboard/invigilator');
    final data = resp.data is Map ? resp.data['data'] ?? resp.data : resp.data;
    return data is Map<String, dynamic> ? data : {};
  }
}
