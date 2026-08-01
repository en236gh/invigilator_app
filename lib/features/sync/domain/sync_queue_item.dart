class SyncQueueItem {
  const SyncQueueItem({required this.id, required this.entityType, required this.payload, required this.status});

  final int id;
  final String entityType;
  final String payload;
  final String status;
}
