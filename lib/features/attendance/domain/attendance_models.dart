class AttendanceRecord {
  AttendanceRecord({
    required this.computerNumber,
    required this.fullName,
    required this.program,
    required this.allocatedVenueName,
    required this.seatNumber,
    required this.attendanceStatus,
    required this.verificationMethod,
    required this.checkedInAt,
  });

  final String computerNumber;
  final String fullName;
  final String program;
  final String allocatedVenueName;
  final String seatNumber;
  final String attendanceStatus;
  final String verificationMethod;
  final String checkedInAt;

  factory AttendanceRecord.fromMap(Map<String, dynamic> map) {
    return AttendanceRecord(
      computerNumber: '${map['computerNumber'] ?? ''}',
      fullName: '${map['fullName'] ?? ''}',
      program: '${map['program'] ?? ''}',
      allocatedVenueName: '${map['allocatedVenueName'] ?? ''}',
      seatNumber: '${map['seatNumber'] ?? ''}',
      attendanceStatus: '${map['attendanceStatus'] ?? ''}',
      verificationMethod: '${map['verificationMethod'] ?? ''}',
      checkedInAt: '${map['checkedInAt'] ?? map['createdAt'] ?? ''}',
    );
  }
}

class AttendanceSummary {
  AttendanceSummary({
    required this.present,
    required this.absent,
    required this.scriptsCollected,
  });

  final int present;
  final int absent;
  final int scriptsCollected;

  factory AttendanceSummary.fromMap(Map<String, dynamic> map) {
    return AttendanceSummary(
      present: map['present'] is int ? map['present'] as int : int.tryParse('${map['present']}') ?? 0,
      absent: map['absent'] is int ? map['absent'] as int : int.tryParse('${map['absent']}') ?? 0,
      scriptsCollected: map['scriptsCollected'] is int ? map['scriptsCollected'] as int : int.tryParse('${map['scriptsCollected']}') ?? 0,
    );
  }
}
