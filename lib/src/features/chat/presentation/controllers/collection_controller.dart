import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sift_app/core/storage/database_provider.dart';
import 'package:sift_app/core/storage/sift_database.dart';

class CollectionState {
  final KnowledgeCollection? activeCollection;
  final List<KnowledgeCollection> allCollections;

  CollectionState({
    this.activeCollection,
    this.allCollections = const [],
  });

  CollectionState copyWith({
    KnowledgeCollection? activeCollection,
    bool clearActive = false,
    List<KnowledgeCollection>? allCollections,
  }) {
    return CollectionState(
      activeCollection: clearActive ? null : (activeCollection ?? this.activeCollection),
      allCollections: allCollections ?? this.allCollections,
    );
  }
}

class CollectionController extends StateNotifier<CollectionState> {
  final AppDatabase _db;

  CollectionController(this._db) : super(CollectionState()) {
    _init();
  }

  void _init() {
    _db.watchCollections().listen((collections) {
      state = state.copyWith(allCollections: collections);
    });
  }

  void selectCollection(KnowledgeCollection collection) {
    state = state.copyWith(activeCollection: collection);
  }

  void clearSelection() {
    state = state.copyWith(clearActive: true);
  }

  Future<void> createCollection(String name, {String? description}) async {
    final collection = await _db.createCollection(name, description: description);
    selectCollection(collection);
  }

  Future<void> deleteCollection(int id) async {
    await _db.deleteCollection(id);
    if (state.activeCollection?.id == id) {
      clearSelection();
    }
  }
}

final collectionProvider = StateNotifierProvider<CollectionController, CollectionState>((ref) {
  return CollectionController(ref.watch(databaseProvider));
});
