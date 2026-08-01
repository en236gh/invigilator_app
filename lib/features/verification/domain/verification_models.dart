class StudentPreview {
  StudentPreview({
    required this.computerNumber,
    required this.fullName,
    required this.program,
    required this.photoPath,
    required this.allocatedVenueId,
    required this.allocatedVenueName,
    required this.seatNumber,
    required this.alreadyCheckedIn,
  });

  final String computerNumber;
  final String fullName;
  final String program;
  final String photoPath;
  final int allocatedVenueId;
  final String allocatedVenueName;
  final String seatNumber;
  final bool alreadyCheckedIn;

  String get initials {
    final parts = fullName.split(' ').where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) {
      return '';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  factory StudentPreview.fromMap(Map<String, dynamic> map) {
    return StudentPreview(
      computerNumber: '${map['computerNumber'] ?? ''}',
      fullName: '${map['fullName'] ?? ''}',
      program: '${map['program'] ?? ''}',
      photoPath: '${map['photoPath'] ?? ''}',
      allocatedVenueId: map['allocatedVenueId'] is int ? map['allocatedVenueId'] as int : int.tryParse('${map['allocatedVenueId']}') ?? 0,
      allocatedVenueName: '${map['allocatedVenueName'] ?? ''}',
      seatNumber: '${map['seatNumber'] ?? ''}',
      alreadyCheckedIn: map['alreadyCheckedIn'] == true || map['alreadyCheckedIn'] == 'true',
    );
  }
}

class VerificationResult {
  VerificationResult({
    required this.success,
    required this.message,
    required this.verificationMethod,
    required this.attendanceStatus,
    required this.studentPreview,
  });

  final bool success;
  final String message;
  final String verificationMethod;
  final String attendanceStatus;
  final StudentPreview? studentPreview;

  factory VerificationResult.fromMap(Map<String, dynamic> map) {
    final studentData = map['data'] is Map<String, dynamic> ? map['data'] as Map<String, dynamic> : map;
    return VerificationResult(
      success: map['success'] == true,
      message: '${map['message'] ?? map['error'] ?? ''}',
      verificationMethod: '${studentData['verificationMethod'] ?? ''}',
      attendanceStatus: '${studentData['attendanceStatus'] ?? ''}',
      studentPreview: studentData.isNotEmpty ? StudentPreview.fromMap(studentData) : null,
    );
  }
}
