import 'package:dio/dio.dart';
import 'interceptors/auth_interceptor.dart';

class ApiClient {
  ApiClient._();

  // Use your laptop's LAN IP for a real phone, for example:
  // flutter run --dart-define=API_BASE_URL=http://192.168.1.25:8080
  // or: flutter build apk --dart-define=API_BASE_URL=http://192.168.1.25:8080
  // 10.0.2.2 works for Android emulator; a physical phone must use the laptop's IP.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.0.150:8080',
  );

  static final Dio instance = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ))..interceptors.addAll([
      AuthInterceptor(),
    ]);
}
