import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/storage/sift_database.dart';

/// Service responsible for orchestrating the generic sync process.
class SyncService {
  final AppDatabase db;

  SyncService(this.db);

  /// Perform a full sync cycle:
  /// 1. Fetch remote changes (Pull)
  /// 2. Merge remotely fetched items into local DB
  /// 3. Push local changes since last sync back to remote
  Future<void> performSync({
    required Future<List<Map<String, dynamic>>> Function(String tableName, DateTime since) onPull,
    required Future<void> Function(String tableName, List<Map<String, dynamic>> items) onPush,
  }) async {
    final lastSyncStr = await db.getSyncMeta('last_global_sync');
    final lastSync = lastSyncStr != null ? DateTime.parse(lastSyncStr) : DateTime.fromMillisecondsSinceEpoch(0);
    
    final now = DateTime.now();

    for (final tableName in db.syncableTables.keys) {
      // 1. Pull
      final remoteItems = await onPull(tableName, lastSync);
      if (remoteItems.isNotEmpty) {
        await db.upsertByUuid(tableName, remoteItems);
      }

      // 2. Push
      final localItems = await db.getItemsSince(tableName, lastSync);
      if (localItems.isNotEmpty) {
        await onPush(tableName, localItems);
      }
    }

    await db.setSyncMeta('last_global_sync', now.toIso8601String());
  }
}

// Extension to help manage sync metadata
extension SyncMetaOps on AppDatabase {
  Future<String?> getSyncMeta(String key) async {
    final row = await (select(syncMeta)..where((s) => s.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> setSyncMeta(String key, String value) async {
    await into(syncMeta).insertOnConflictUpdate(
      SyncMetaCompanion.insert(key: key, value: value),
    );
  }
}

final syncServiceProvider = Provider((ref) => SyncService(AppDatabase.instance));
