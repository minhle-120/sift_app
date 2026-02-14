import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/sift_database.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase.instance;
});
final documentsStreamProvider = StreamProvider.autoDispose.family<List<Document>, int>((ref, collectionId) {
  final db = ref.watch(databaseProvider);
  return db.watchCollectionDocuments(collectionId);
});
