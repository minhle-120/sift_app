import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sift_app/core/storage/database_provider.dart';
import 'package:sift_app/core/storage/sift_database.dart';

class CollectionState {
  final KnowledgeCollection? activeCollection;
  final List<KnowledgeCollection> allCollections;
  final bool hasDocuments;

  CollectionState({
    this.activeCollection,
    this.allCollections = const [],
    this.hasDocuments = false,
  });

  CollectionState copyWith({
    KnowledgeCollection? activeCollection,
    bool clearActive = false,
    List<KnowledgeCollection>? allCollections,
    bool? hasDocuments,
  }) {
    return CollectionState(
      activeCollection: clearActive ? null : (activeCollection ?? this.activeCollection),
      allCollections: allCollections ?? this.allCollections,
      hasDocuments: hasDocuments ?? this.hasDocuments,
    );
  }
}

class CollectionController extends StateNotifier<CollectionState> {
  final AppDatabase _db;

  StreamSubscription? _documentsSubscription;

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
    _watchDocuments(collection.id);
  }

  void clearSelection() {
    _documentsSubscription?.cancel();
    state = state.copyWith(clearActive: true, hasDocuments: false);
  }

  void _watchDocuments(int collectionId) {
    _documentsSubscription?.cancel();
    _documentsSubscription = _db.watchCollectionDocuments(collectionId).listen((docs) {
      state = state.copyWith(hasDocuments: docs.isNotEmpty);
    });
  }

  @override
  void dispose() {
    _documentsSubscription?.cancel();
    super.dispose();
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
