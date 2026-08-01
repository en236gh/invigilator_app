class IncidentRecord {
  IncidentRecord({
    required this.incidentId,
    required this.examSessionId,
    required this.venueId,
    required this.computerNumber,
    required this.incidentType,
    required this.description,
    required this.severity,
    required this.evidencePath,
    required this.createdAt,
  });

  final int incidentId;
  final int examSessionId;
  final int venueId;
  final String computerNumber;
  final String incidentType;
  final String description;
  final String severity;
  final String evidencePath;
  final String createdAt;

  factory IncidentRecord.fromMap(Map<String, dynamic> map) {
    return IncidentRecord(
      incidentId: map['incidentId'] is int ? map['incidentId'] as int : int.tryParse('${map['incidentId']}') ?? 0,
      examSessionId: map['examSessionId'] is int ? map['examSessionId'] as int : int.tryParse('${map['examSessionId']}') ?? 0,
      venueId: map['venueId'] is int ? map['venueId'] as int : int.tryParse('${map['venueId']}') ?? 0,
      computerNumber: '${map['computerNumber'] ?? ''}',
      incidentType: '${map['incidentType'] ?? ''}',
      description: '${map['description'] ?? ''}',
      severity: '${map['severity'] ?? ''}',
      evidencePath: '${map['evidencePath'] ?? ''}',
      createdAt: '${map['createdAt'] ?? map['reportedAt'] ?? ''}',
    );
  }
}
