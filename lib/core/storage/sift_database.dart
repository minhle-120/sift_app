import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'dart:math' as math;
import 'package:uuid/uuid.dart';
import 'tables.dart';

part 'sift_database.g.dart';

@DriftDatabase(tables: [
  KnowledgeCollections,
  Conversations,
  Messages,
  Resources,
  SyncMeta,
  Documents,
  DocumentChunks,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase._() : super(_openConnection());

  static AppDatabase? _instance;
  static AppDatabase get instance {
    _instance ??= AppDatabase._();
    return _instance!;
  }

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
      );

  // --- Core CRUD Operations ---

  /// Watch all non-deleted collections.
  Stream<List<KnowledgeCollection>> watchCollections() {
    return (select(knowledgeCollections)
          ..where((t) => t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  /// Create a new collection.
  Future<KnowledgeCollection> createCollection(String name, {String? description}) {
    return into(knowledgeCollections).insertReturning(
      KnowledgeCollectionsCompanion.insert(
        uuid: _uuid.v4(),
        name: name,
      ),
    );
  }

  /// Delete a collection (soft delete).
  Future<int> deleteCollection(int id) {
    return (update(knowledgeCollections)..where((t) => t.id.equals(id)))
        .write(const KnowledgeCollectionsCompanion(isDeleted: Value(true)));
  }

  /// Get a single collection.
  Future<KnowledgeCollection?> getCollectionById(int id) {
    return (select(knowledgeCollections)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Watch conversations for a collection.
  Stream<List<Conversation>> watchConversations(int collectionId) {
    return (select(conversations)
          ..where((t) => t.collectionId.equals(collectionId) & t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.lastUpdatedAt)]))
        .watch();
  }

  /// Create a new conversation.
  Future<Conversation> createConversation(int collectionId, String title) {
    return into(conversations).insertReturning(
      ConversationsCompanion.insert(
        uuid: _uuid.v4(),
        collectionId: collectionId,
        title: title,
      ),
    );
  }

  /// Delete a conversation (soft delete).
  Future<int> deleteConversation(int id) {
    return (update(conversations)..where((t) => t.id.equals(id)))
        .write(const ConversationsCompanion(isDeleted: Value(true)));
  }

  /// Get a single conversation.
  Future<Conversation?> getConversationById(int id) {
    return (select(conversations)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Watch messages for a conversation.
  Stream<List<Message>> watchMessages(int conversationId) {
    return (select(messages)
          ..where((t) => t.conversationId.equals(conversationId) & t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch();
  }

  /// Insert a new message.
  Future<Message> insertMessage({
    required int conversationId,
    required String role,
    required String content,
    String? reasoning,
    String? citations,
    String? metadata,
    required int sortOrder,
  }) {
    return into(messages).insertReturning(
      MessagesCompanion.insert(
        uuid: _uuid.v4(),
        conversationId: conversationId,
        role: role,
        content: content,
        reasoning: Value(reasoning),
        citations: Value(citations),
        metadata: Value(metadata),
        sortOrder: sortOrder,
      ),
    );
  }

  /// Update a message's content.
  Future<void> updateMessageContent(int id, String content) {
    return (update(messages)..where((t) => t.id.equals(id))).write(
      MessagesCompanion(
        content: Value(content),
        lastUpdatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Update a message's reasoning content.
  Future<void> updateMessageReasoning(int id, String reasoning) {
    return (update(messages)..where((t) => t.id.equals(id))).write(
      MessagesCompanion(
        reasoning: Value(reasoning),
        lastUpdatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Soft delete a message.
  Future<void> softDeleteMessage(int id) {
    return (update(messages)..where((t) => t.id.equals(id))).write(
      MessagesCompanion(
        isDeleted: const Value(true),
        lastUpdatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Clear all metadata/citations for a message (used for regeneration).
  Future<void> clearMessageMetadata(int id) {
    return (update(messages)..where((t) => t.id.equals(id))).write(
      MessagesCompanion(
        content: const Value(''),
        reasoning: const Value(null),
        citations: const Value(null),
        metadata: const Value(null),
        lastUpdatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Finds the message immediately before the given ID in the same conversation.
  Future<Message?> getMessageBefore(int conversationId, int currentSortOrder) {
    return (select(messages)
          ..where((t) => 
            t.conversationId.equals(conversationId) & 
            t.sortOrder.isSmallerThan(Variable(currentSortOrder)) &
            t.isDeleted.equals(false)
          )
          ..orderBy([(t) => OrderingTerm.desc(t.sortOrder)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Get the maximum sort order for a conversation.
  Future<int> getMaxSortOrder(int conversationId) async {
    final query = selectOnly(messages)
      ..addColumns([messages.sortOrder.max()])
      ..where(messages.conversationId.equals(conversationId) & messages.isDeleted.equals(false));
    final result = await query.map((row) => row.read(messages.sortOrder.max())).getSingle();
    return result ?? -1;
  }

  /// Update a message's metadata and citations.
  Future<void> updateMessageMetadata(int id, {String? citations, String? metadata}) {
    return (update(messages)..where((t) => t.id.equals(id))).write(
      MessagesCompanion(
        citations: citations != null ? Value(citations) : const Value.absent(),
        metadata: metadata != null ? Value(metadata) : const Value.absent(),
      ),
    );
  }

  // --- Document Operations ---

  Stream<List<Document>> watchCollectionDocuments(int collectionId) {
    return (select(documents)
          ..where((t) => t.collectionId.equals(collectionId))
          ..orderBy([(t) => OrderingTerm.desc(t.id)]))
        .watch();
  }

  Future<Document> createDocument({
    required int? collectionId,
    required String title,
    required String filePath,
    required String type,
  }) {
    return into(documents).insertReturning(
      DocumentsCompanion.insert(
        uuid: _uuid.v4(),
        collectionId: Value(collectionId),
        title: title,
        filePath: filePath,
        type: type,
        status: const Value('pending'),
      ),
    );
  }

  Future<void> updateDocumentStatus(int id, String status, {String? error}) {
    return (update(documents)..where((t) => t.id.equals(id))).write(
      DocumentsCompanion(
        status: Value(status),
        error: Value(error),
      ),
    );
  }

  Future<int> deleteDocument(int id) {
    return (delete(documents)..where((t) => t.id.equals(id))).go();
  }

  Future<Document?> getDocumentById(int id) {
    return (select(documents)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<List<DocumentChunk>> getDocumentChunks(int documentId) {
    return (select(documentChunks)
          ..where((t) => t.documentId.equals(documentId))
          ..orderBy([(t) => OrderingTerm.asc(t.index)]))
        .get();
  }

  /// Fetches only the content of a specific chunk by its index.
  /// Used for memory-efficient document highlighting.
  Future<String?> getChunkContent(int documentId, int index) async {
    final query = selectOnly(documentChunks)
      ..addColumns([documentChunks.content])
      ..where(documentChunks.documentId.equals(documentId) & documentChunks.index.equals(index));
    final row = await query.getSingleOrNull();
    return row?.read(documentChunks.content);
  }

  Future<int> deleteDocumentChunks(int documentId) {
    return (delete(documentChunks)..where((t) => t.documentId.equals(documentId))).go();
  }

  Future<void> insertDocumentChunks(List<DocumentChunksCompanion> chunks) async {
    await batch((batch) {
      batch.insertAll(documentChunks, chunks);
    });
  }

  // --- Vector Search & Scoring ---

  /// Memory-optimized vector search with selective fetching, paging, and hydration.
  /// Parallelized via Isolates across multiple CPU cores.
  Future<List<TypedResult>> vectorSearch({
    required int collectionId,
    required List<double> queryEmbedding,
    int limit = 10,
  }) async {
    // 1. Initial Selective Scan: Only pull IDs and embeddings
    final List<MapEntry<int, double>> topScores = [];
    final workerCount = Platform.numberOfProcessors;
    final batchSize = workerCount * 1000;
    int offset = 0;

    // Helper to fetch a batch asynchronously
    Future<List<TypedResult>> fetchBatch(int currentOffset) {
      final query = selectOnly(documentChunks)
        ..addColumns([documentChunks.id, documentChunks.embedding])
        ..join([
          innerJoin(documents, documents.id.equalsExp(documentChunks.documentId))
        ])
        ..where(documents.collectionId.equals(collectionId))
        ..limit(batchSize, offset: currentOffset);
      return query.get();
    }

    // 1. Initial Selective Scan: Pre-start the first fetch
    Future<List<TypedResult>>? nextBatchFuture = fetchBatch(offset);
    
    while (nextBatchFuture != null) {
      final batch = await nextBatchFuture;
      if (batch.isEmpty) break;

      // START fetching the next batch immediately (Pipelining)
      offset += batchSize;
      if (batch.length == batchSize) {
        nextBatchFuture = fetchBatch(offset);
      } else {
        nextBatchFuture = null;
      }

      // 2. Parallel Dispatch: Score the CURRENT batch while NEXT fetch is in progress
      final List<int> batchIds = [];
      final List<String> batchEmbeddings = [];
      for (final row in batch) {
          batchIds.add(row.read(documentChunks.id)!);
          batchEmbeddings.add(row.read(documentChunks.embedding)!);
      }

      final subBatchSize = (batchIds.length / workerCount).ceil();
      final List<Future<List<MapEntry<int, double>>>> futures = [];

      for (var i = 0; i < workerCount; i++) {
          final start = i * subBatchSize;
          if (start >= batchIds.length) break;
          final end = (start + subBatchSize < batchIds.length) ? start + subBatchSize : batchIds.length;
          
          final task = _ScoreTask(
              ids: batchIds.sublist(start, end),
              embeddings: batchEmbeddings.sublist(start, end),
              queryEmbedding: queryEmbedding,
          );

          futures.add(compute(_scoreBatchIsolate, task));
      }

      final partialResults = await Future.wait(futures);
      for (final list in partialResults) {
          topScores.addAll(list);
      }

      // Sort and prune to keep memory low
      topScores.sort((a, b) => b.value.compareTo(a.value));
      if (topScores.length > 50) {
        topScores.removeRange(50, topScores.length);
      }

      // Yield briefly
      await Future.delayed(Duration.zero);
    }

    if (topScores.isEmpty) return [];

    // 3. Final Pruning to requested limit
    topScores.sort((a, b) => b.value.compareTo(a.value));
    final winnerIds = topScores.take(limit).map((e) => e.key).toList();

    // 4. Hydration: Fetch full objects only for the winners
    final hydrationQuery = select(documentChunks).join([
      innerJoin(documents, documents.id.equalsExp(documentChunks.documentId))
    ])
      ..where(documentChunks.id.isIn(winnerIds));

    final hydratedResults = await hydrationQuery.get();
    
    // Sort hydrated results to match the original score order
    hydratedResults.sort((a, b) {
      final idA = a.readTable(documentChunks).id;
      final idB = b.readTable(documentChunks).id;
      return winnerIds.indexOf(idA).compareTo(winnerIds.indexOf(idB));
    });

    return hydratedResults;
  }


  // --- Shared Sync Logic ---

  /// Map of table names to their drift table instances for generic sync.
  Map<String, TableInfo<Table, dynamic>> get syncableTables => {
        'knowledge_collections': knowledgeCollections,
        'conversations': conversations,
        'messages': messages,
        'resources': resources,
        'documents': documents,
        'document_chunks': documentChunks,
      };

  /// Maps table names to their generated fromJson factories for generic deserialization.
  Map<String, Insertable Function(Map<String, dynamic>)> get _tableFactories => {
        'knowledge_collections': KnowledgeCollection.fromJson,
        'conversations': Conversation.fromJson,
        'messages': Message.fromJson,
        'resources': Resource.fromJson,
        'documents': Document.fromJson,
        'document_chunks': DocumentChunk.fromJson,
      };

  /// Get rows from a table modified since [since].
  Future<List<Map<String, dynamic>>> getItemsSince(
      String tableName, DateTime since) async {
    final table = syncableTables[tableName];
    if (table == null) return [];

    final query = select(table)
      ..where((row) {
        final lastUpdatedCol = table.columnsByName['last_updated_at'] as Column<DateTime>;
        return lastUpdatedCol.isBiggerThanValue(since);
      });

    final rows = await query.get();
    return rows.map((row) => row.toJson()).toList().cast<Map<String, dynamic>>();
  }

  /// Finalizes the generic upsert logic using UUID as the anchor and 
  /// 'last_updated_at' for conflict resolution.
  Future<void> upsertByUuid(
      String tableName, List<Map<String, dynamic>> items) async {
    final table = syncableTables[tableName];
    final factory = _tableFactories[tableName];
    if (table == null || factory == null || items.isEmpty) return;

    await transaction(() async {
      for (final item in items) {
        final json = Map<String, dynamic>.from(item);
        final uuid = json['uuid'] as String;
        final incomingUpdate = DateTime.parse(json['last_updated_at'] as String);

        // 1. Check if item exists locally
        final existing = await (select(table)..where((t) {
          final uuidCol = table.columnsByName['uuid'] as Column<String>;
          return uuidCol.equals(uuid);
        })).getSingleOrNull();

        if (existing == null) {
          // New: Insert, but remove local 'id' to let DB generate it
          final data = Map<String, dynamic>.from(json)..remove('id');
          await into(table).insert(factory(data));
        } else {
          // Exists: Conflict Check
          final localUpdate = (existing as dynamic).lastUpdatedAt as DateTime;
          if (incomingUpdate.isAfter(localUpdate)) {
            await (update(table)..where((t) {
              final uuidCol = table.columnsByName['uuid'] as Column<String>;
              return uuidCol.equals(uuid);
            })).write(factory(json));
          }
        }
      }
    });
  }
}

const _uuid = Uuid();

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    String dataDirPath;
    if (Platform.isAndroid || Platform.isIOS) {
      final appDir = await getApplicationDocumentsDirectory();
      dataDirPath = p.join(appDir.path, 'data');
    } else {
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      dataDirPath = p.join(exeDir, 'data');
    }

    final dataDir = Directory(dataDirPath);
    if (!await dataDir.exists()) {
      await dataDir.create(recursive: true);
    }
    final file = File(p.join(dataDir.path, 'sift.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

// --- Top-level Isolate Workers ---
// We move these outside the class to ensure Isolate.run doesn't capture 'this' (AppDatabase).

class _ScoreTask {
  final List<int> ids;
  final List<String> embeddings;
  final List<double> queryEmbedding;

  _ScoreTask({
    required this.ids,
    required this.embeddings,
    required this.queryEmbedding,
  });
}

/// Helper for parallel isolate scoring
List<MapEntry<int, double>> _scoreBatchIsolate(_ScoreTask task) {
  final results = <MapEntry<int, double>>[];
  for (var i = 0; i < task.ids.length; i++) {
    final id = task.ids[i];
    final embeddingStr = task.embeddings[i];

    // Fast parse directly to Float32List
    final embeddingList = _fastParseVector(embeddingStr);

    // Compute similarity
    final score = _cosineSimilarityF32(task.queryEmbedding, embeddingList);
    results.add(MapEntry(id, score));
  }
  return results;
}

/// Fast vector parser that avoids jsonDecode entirely.
/// Parses "[0.123,0.456,...]" directly into a Float32List.
Float32List _fastParseVector(String jsonStr) {
  final inner = jsonStr.substring(1, jsonStr.length - 1);
  final parts = inner.split(',');
  final result = Float32List(parts.length);
  for (var i = 0; i < parts.length; i++) {
    result[i] = double.parse(parts[i]);
  }
  return result;
}

/// Inline cosine similarity optimized for Float32List.
double _cosineSimilarityF32(List<double> a, Float32List b) {
  if (a.length != b.length) return 0.0;
  double dotProduct = 0.0;
  double normA = 0.0;
  double normB = 0.0;
  for (int i = 0; i < a.length; i++) {
    final ai = a[i];
    final bi = b[i];
    dotProduct += ai * bi;
    normA += ai * ai;
    normB += bi * bi;
  }
  final denom = math.sqrt(normA) * math.sqrt(normB);
  return denom == 0 ? 0.0 : dotProduct / denom;
}
