class ExamAssignment {
  ExamAssignment({
    required this.examSessionId,
    required this.venueId,
    required this.courseCode,
    required this.examDate,
    required this.startTime,
    required this.endTime,
    required this.examStatus,
    required this.venueName,
    required this.building,
    required this.capacity,
    required this.lecturers,
  });

  final int examSessionId;
  final int venueId;
  final String courseCode;
  final String examDate;
  final String startTime;
  final String endTime;
  final String examStatus;
  final String venueName;
  final String building;
  final int capacity;
  final List<String> lecturers;

  bool get isInProgress => examStatus == 'IN_PROGRESS';
  bool get isScheduled => examStatus == 'SCHEDULED';
  bool get isCompleted => examStatus == 'COMPLETED';
  bool get canCheckIn => !isCompleted;

  String get statusLabel => examStatus.replaceAll('_', ' ');

  String get timeRangeLabel {
    final start = startTime.trim();
    final end = endTime.trim();
    if (start.isEmpty && end.isEmpty) return examDate;
    if (end.isEmpty) return '$examDate · $start';
    return '$examDate · $start–$end';
  }

  String get shortLabel => '$courseCode · $venueName';

  /// Identity key for an invigilator assignment (exam + venue).
  bool sameAs(ExamAssignment? other) {
    return other != null &&
        other.examSessionId == examSessionId &&
        other.venueId == venueId;
  }

  ExamAssignment copyWith({
    int? examSessionId,
    int? venueId,
    String? courseCode,
    String? examDate,
    String? startTime,
    String? endTime,
    String? examStatus,
    String? venueName,
    String? building,
    int? capacity,
    List<String>? lecturers,
  }) {
    return ExamAssignment(
      examSessionId: examSessionId ?? this.examSessionId,
      venueId: venueId ?? this.venueId,
      courseCode: courseCode ?? this.courseCode,
      examDate: examDate ?? this.examDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      examStatus: examStatus ?? this.examStatus,
      venueName: venueName ?? this.venueName,
      building: building ?? this.building,
      capacity: capacity ?? this.capacity,
      lecturers: lecturers ?? this.lecturers,
    );
  }

  factory ExamAssignment.fromMap(Map<String, dynamic> map) {
    final lecturers = <String>[];
    if (map['lecturers'] is List) {
      for (final item in map['lecturers']!) {
        if (item is String) {
          lecturers.add(item);
        } else if (item is Map && item['name'] is String) {
          lecturers.add(item['name'] as String);
        }
      }
    }

    return ExamAssignment(
      examSessionId: map['examSessionId'] is int ? map['examSessionId'] as int : int.tryParse('${map['examSessionId']}') ?? 0,
      venueId: map['venueId'] is int ? map['venueId'] as int : int.tryParse('${map['venueId']}') ?? 0,
      courseCode: '${map['courseCode'] ?? ''}',
      examDate: '${map['examDate'] ?? ''}',
      startTime: '${map['startTime'] ?? ''}',
      endTime: '${map['endTime'] ?? ''}',
      examStatus: '${map['examStatus'] ?? ''}',
      venueName: '${map['venueName'] ?? ''}',
      building: '${map['building'] ?? ''}',
      capacity: map['capacity'] is int ? map['capacity'] as int : int.tryParse('${map['capacity']}') ?? 0,
      lecturers: lecturers,
    );
  }
}
