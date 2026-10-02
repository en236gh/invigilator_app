import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invigilator_app/features/offline/application/offline_controller.dart';

void main() {
  test(
    'download errors distinguish HTTP status without exposing response data',
    () {
      for (final status in [401, 403, 404, 500]) {
        final request = RequestOptions(
          path: '/api/attendance/offline-exam-data',
        );
        final failure = DioException(
          requestOptions: request,
          response: Response(
            requestOptions: request,
            statusCode: status,
            data: {'accessToken': 'secret-token'},
          ),
        );
        final message = OfflineController.describeDownloadFailure(
          failure,
          'Downloading roster',
        );
        expect(message, contains('HTTP $status'));
        expect(message, isNot(contains('secret-token')));
      }
    },
  );
  test('timeout and unsupported storage have different recovery messages', () {
    final timeout = DioException(
      requestOptions: RequestOptions(),
      type: DioExceptionType.receiveTimeout,
    );
    expect(
      OfflineController.describeDownloadFailure(timeout, 'Downloading roster'),
      contains('timed out'),
    );
    expect(
      OfflineController.describeDownloadFailure(
        MissingPluginException(),
        'Saving offline data',
      ),
      contains('Local storage is unavailable'),
    );
    expect(
      OfflineController.describeDownloadFailure(
        Exception(),
        'Saving offline data',
      ),
      contains('SQLite'),
    );
  });
}
