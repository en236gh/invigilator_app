import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../domain/incident_models.dart';

class IncidentRepository {
  IncidentRepository({Dio? dio}) : _dio = dio ?? ApiClient.instance;

  final Dio _dio;

  Future<List<IncidentRecord>> fetchIncidents() async {
    final resp = await _dio.get('/api/incidents');
    final data = resp.data is Map ? resp.data['data'] ?? resp.data : resp.data;
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(IncidentRecord.fromMap)
          .toList();
    }
    return [];
  }

  Future<IncidentRecord> reportIncident({
    required int examSessionId,
    required int venueId,
    String? computerNumber,
    required String incidentType,
    required String description,
    String severity = 'MAJOR',
    String? evidencePath,
  }) async {
    final resp = await _dio.post(
      '/api/incidents',
      data: {
        'examSessionId': examSessionId,
        'venueId': venueId,
        if (computerNumber != null && computerNumber.isNotEmpty)
          'computerNumber': computerNumber,
        'incidentType': incidentType,
        'description': description,
        'severity': severity,
        if (evidencePath != null && evidencePath.isNotEmpty)
          'evidencePath': evidencePath,
      },
    );

    final data = resp.data is Map ? resp.data['data'] ?? resp.data : resp.data;
    if (data is Map<String, dynamic>) {
      return IncidentRecord.fromMap(data);
    }

    throw DioException(
      requestOptions: RequestOptions(path: '/api/incidents'),
      error: 'Invalid server response',
      type: DioExceptionType.badResponse,
    );
  }
}
