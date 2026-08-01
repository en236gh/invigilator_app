import 'package:invigilator_app/core/database/app_database.dart';

class SyncRepository {
  Future<List<Map<String, Object?>>> getPendingSyncs() async {
    final db = await AppDatabase.database;
    return db.query('sync_queue', where: 'status = ?', whereArgs: ['pending']);
  }
}
