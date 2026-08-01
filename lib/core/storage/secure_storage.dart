import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  SecureStorage._();

  static final FlutterSecureStorage instance = const FlutterSecureStorage();

  static Future<void> write(String key, String value) {
    return instance.write(key: key, value: value);
  }

  static Future<String?> read(String key) {
    return instance.read(key: key);
  }

  static Future<void> delete(String key) {
    return instance.delete(key: key);
  }
}
