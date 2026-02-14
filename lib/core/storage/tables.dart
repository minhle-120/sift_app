import 'package:drift/drift.dart';

/// Mixin for tables that support cross-device synchronization.
mixin Syncable on Table {
  TextColumn get uuid => text().withLength(min: 36, max: 36)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastUpdatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
}

/// Table for high-level organization (e.g., "Research Support", "Daily Chat").
class KnowledgeCollections extends Table with Syncable {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 255)();
  TextColumn get description => text().nullable()();
}

/// Table for individual chat sessions.
class Conversations extends Table with Syncable {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get collectionId => integer().references(KnowledgeCollections, #id)();
  TextColumn get title => text().withLength(min: 1, max: 255)();
  TextColumn get metadata => text().nullable()(); // JSON string for session-specific state
}

/// Table for chat messages.
class Messages extends Table with Syncable {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get conversationId => integer().references(Conversations, #id)();
  TextColumn get role => text()(); // user, assistant, system, tool
  TextColumn get content => text()();
  TextColumn get reasoning => text().nullable()();
  TextColumn get citations => text().nullable()(); // JSON array of citation objects
  IntColumn get sortOrder => integer()();
  TextColumn get metadata => text().nullable()(); // JSON map
}

/// A generic table for storing any resource that doesn't fit in the core schema.
/// This fulfills the "don't edit code to add new features" requirement.
class Resources extends Table with Syncable {
  IntColumn get id => integer().autoIncrement()();
  
  // The type of resource (e.g., 'document_chunk', 'diagram_spec', 'user_preference')
  TextColumn get type => text().withLength(min: 1, max: 50)();
  
  // The actual data payload as a JSON string
  TextColumn get data => text()();
  
  // Optional associations
  IntColumn get collectionId => integer().nullable().references(KnowledgeCollections, #id)();
  IntColumn get conversationId => integer().nullable().references(Conversations, #id)();
}

/// Table for storing sync-related metadata (pairing info, last global sync time).
class SyncMeta extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Table for tracking uploaded files and their processing status.
class Documents extends Table with Syncable {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get collectionId => integer().nullable().references(KnowledgeCollections, #id)();
  TextColumn get title => text().withLength(min: 1, max: 255)();
  TextColumn get filePath => text()(); // Local path to the file
  TextColumn get type => text().withLength(min: 1, max: 50)(); // pdf, md, txt, etc.
  
  // processing, completed, failed
  TextColumn get status => text().withDefault(const Constant('pending'))(); 
  TextColumn get error => text().nullable()();
  TextColumn get content => text().nullable()(); // Full extracted text (optional, for re-chunking)
}

/// Table for storing vector embeddings of document chunks.
class DocumentChunks extends Table with Syncable {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get documentId => integer().references(Documents, #id, onDelete: KeyAction.cascade)();
  TextColumn get content => text()();
  TextColumn get embedding => text()(); // JSON encoded List<double>
  IntColumn get index => integer()(); // Sequential index of the chunk
  
  // Optional: Link directly to other entities if needed
  IntColumn get conversationId => integer().nullable().references(Conversations, #id)();
}
