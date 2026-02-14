import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
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
        sortOrder: sortOrder,
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

  Future<void> insertDocumentChunks(List<DocumentChunksCompanion> chunks) async {
    await batch((batch) {
      batch.insertAll(documentChunks, chunks);
    });
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
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'sift.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
