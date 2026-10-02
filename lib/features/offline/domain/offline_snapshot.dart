import 'dart:convert';

const verificationMethods = [
  'COMPUTER',
  'QR_CODE',
  'FACE_RECOGNITION',
  'QR_AND_FACE',
  'QR_AND_FACIAL',
];

class OfflineSnapshot {
  OfflineSnapshot(this.data) {
    if (data['snapshotId'] is! String ||
        !RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
        ).hasMatch(data['snapshotId'] as String) ||
        data['staffId'] == null ||
        DateTime.tryParse('${data['generatedAt']}') == null) {
      throw const FormatException('Invalid snapshot metadata');
    }
    for (final row in [...assignments, ...students]) {
      if (row['examSessionId'] is! int ||
          row['venueId'] is! int ||
          (row['examSessionId'] as int) <= 0 ||
          (row['venueId'] as int) <= 0) {
        throw const FormatException('Invalid exam or venue');
      }
    }
  }
  final Map<String, dynamic> data;
  String get id => data['snapshotId'] as String;
  String get owner => '${data['staffId']}';
  DateTime get generatedAt => DateTime.parse(data['generatedAt'] as String);
  List<Map<String, dynamic>> get assignments => (data['assignments'] as List)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
  List<Map<String, dynamic>> get students => (data['students'] as List)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
  Map<String, dynamic>? lookup(int exam, int venue, String number) {
    for (final student in students) {
      if (student['examSessionId'] == exam &&
          student['venueId'] == venue &&
          student['computerNumber'] == number) {
        return student;
      }
    }
    return null;
  }

  String encode() => jsonEncode(data);
}
