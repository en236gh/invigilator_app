import 'package:dio/dio.dart';
import 'package:invigilator_app/core/network/api_client.dart';

import '../domain/verification_models.dart';

class VerificationRepository {
  final Dio _dio = ApiClient.instance;

  Future<StudentPreview> lookupByComputerNumber({
    required String computerNumber,
    required int examSessionId,
  }) async {
    final resp = await _dio.get(
      '/api/attendance/lookup',
      queryParameters: {
        'computerNumber': computerNumber,
        'examSessionId': examSessionId,
      },
    );

    final data = _extractData(resp.data);
    return StudentPreview.fromMap(data);
  }

  Future<VerificationResult> checkInByComputerNumber({
    required String computerNumber,
    required int examSessionId,
    required int venueId,
  }) async {
    final resp = await _dio.post(
      '/api/attendance/check-in',
      data: {
        'computerNumber': computerNumber,
        'examSessionId': examSessionId,
        'venueId': venueId,
        'verificationMethod': 'COMPUTER',
      },
    );

    return VerificationResult.fromMap(_normalizeResponse(resp.data));
  }

  Future<StudentPreview> lookupByQrToken({
    required String qrToken,
    required int examSessionId,
  }) async {
    final resp = await _dio.post(
      '/api/attendance/lookup-by-qr',
      data: {
        'qrToken': qrToken,
        'examSessionId': examSessionId,
      },
    );

    final data = _extractData(resp.data);
    return StudentPreview.fromMap(data);
  }

  Future<VerificationResult> checkInByQrToken({
    required String qrToken,
    required int examSessionId,
    required int venueId,
  }) async {
    final resp = await _dio.post(
      '/api/attendance/check-in-by-qr',
      data: {
        'qrToken': qrToken,
        'examSessionId': examSessionId,
        'venueId': venueId,
      },
    );

    return VerificationResult.fromMap(_normalizeResponse(resp.data));
  }

  Map<String, dynamic> _extractData(Object? responseData) {
    if (responseData is Map<String, dynamic>) {
      final data = responseData['data'];
      if (data is Map<String, dynamic>) {
        return data;
      }
      return responseData;
    }
    throw DioException(
      requestOptions: RequestOptions(path: '/api/attendance'),
      error: 'Invalid server response',
      type: DioExceptionType.badResponse,
    );
  }

  Map<String, dynamic> _normalizeResponse(Object? responseData) {
    if (responseData is Map<String, dynamic>) {
      return responseData;
    }
    return {'success': false, 'message': 'Invalid server response'};
  }
}
