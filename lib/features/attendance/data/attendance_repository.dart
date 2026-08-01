import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../domain/attendance_models.dart';

class AttendanceRepository {
  final Dio _dio = ApiClient.instance;

  Future<List<AttendanceRecord>> fetchAttendanceForExam({required int examSessionId}) async {
    final resp = await _dio.get('/api/attendance/exam/$examSessionId');
    final data = resp.data is Map ? resp.data['data'] ?? resp.data : resp.data;
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(AttendanceRecord.fromMap)
          .toList();
    }
    return [];
  }

  Future<AttendanceSummary> fetchAttendanceSummary({required int examSessionId}) async {
    final resp = await _dio.get('/api/attendance/exam/$examSessionId/summary');
    final data = resp.data is Map ? resp.data['data'] ?? resp.data : resp.data;
    if (data is Map<String, dynamic>) {
      return AttendanceSummary.fromMap(data);
    }
    throw DioException(
      requestOptions: RequestOptions(path: '/api/attendance/exam/$examSessionId/summary'),
      error: 'Invalid server response',
      type: DioExceptionType.badResponse,
    );
  }

  Future<void> markScriptsCollected({required int examSessionId, required int count}) async {
    await _dio.post(
      '/api/attendance/exam/$examSessionId/scripts-collected',
      data: {'count': count},
    );
  }
}
