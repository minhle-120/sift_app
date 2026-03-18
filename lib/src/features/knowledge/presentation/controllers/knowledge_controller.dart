import 'dart:io';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sift_app/core/storage/database_provider.dart';
import 'package:sift_app/core/storage/sift_database.dart';
import 'package:sift_app/core/services/document_processor.dart';
import 'package:sift_app/core/services/embedding_service.dart';
import 'package:sift_app/src/features/chat/presentation/controllers/settings_controller.dart';
import 'package:sift_app/src/features/chat/presentation/controllers/collection_controller.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';

class KnowledgeState {
  final AsyncValue<void> status;
  final double reprocessingProgress; // 0.0 to 1.0
  final bool isReprocessing;

  const KnowledgeState({
    this.status = const AsyncValue.data(null),
    this.reprocessingProgress = 0.0,
    this.isReprocessing = false,
  });

  KnowledgeState copyWith({
    AsyncValue<void>? status,
    double? reprocessingProgress,
    bool? isReprocessing,
  }) {
    return KnowledgeState(
      status: status ?? this.status,
      reprocessingProgress: reprocessingProgress ?? this.reprocessingProgress,
      isReprocessing: isReprocessing ?? this.isReprocessing,
    );
  }
}

final knowledgeControllerProvider = StateNotifierProvider<KnowledgeController, KnowledgeState>((ref) {
  return KnowledgeController(ref);
});

final filteredDocumentsProvider = StreamProvider<List<Document>>((ref) {
  final db = ref.watch(databaseProvider);
  final collectionState = ref.watch(collectionProvider);
  final activeCollection = collectionState.activeCollection;
  
  if (activeCollection == null) {
    // If no collection selected, maybe return all? Or empty?
    // Let's return all documents that have NULL collectionId (global)
    // Or just empty for now to match previous logic.
    // Actually, user might want to see all documents.
    // Let's stick to empty for "Collection Documents" screen context, or prompt selection.
    return Stream.value([]);
  }
  
  return db.watchCollectionDocuments(activeCollection.id);
});

class KnowledgeController extends StateNotifier<KnowledgeState> {
  final Ref _ref;
  final DocumentProcessor _processor = DocumentProcessor();

  KnowledgeController(this._ref) : super(const KnowledgeState());

  bool _isPickingFile = false;

  Future<void> pickAndUploadDocument() async {
    if (_isPickingFile) return;
    _isPickingFile = true;
    
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) return;

      final paths = result.files.map((f) => f.path).whereType<String>().toList();
      if (paths.isEmpty) return;

      uploadFiles(paths);
    } finally {
      _isPickingFile = false;
    }
  }

  Future<void> savePastedText(String title, String content) async {
    final db = _ref.read(databaseProvider);
    final activeCollection = _ref.read(collectionProvider).activeCollection;
    final collectionId = activeCollection?.id;

    try {
      state = state.copyWith(status: const AsyncValue.loading());

      // 1. Prepare Directory
      final appDocDir = await getApplicationDocumentsDirectory();
      final pastedDir = Directory(p.join(appDocDir.path, 'pasted_content'));
      if (!await pastedDir.exists()) {
        await pastedDir.create(recursive: true);
      }

      // 2. Generate Filename
      String fileName;
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      
      if (title.trim().isEmpty) {
        fileName = 'pasted_text_$timestamp.txt';
      } else {
        // Sanitize title: remove illegal chars for filesystem, replace space with underscore
        final sanitizedTitle = title.trim().replaceAll(RegExp(r'[<>:"/\\|?*]'), '').replaceAll(' ', '_');
        fileName = '${sanitizedTitle}_$timestamp.txt';
      }

      final filePath = p.join(pastedDir.path, fileName);
      final file = File(filePath);

      // 3. Save File
      await file.writeAsString(content);

      // 4. Create Document Entry
      final doc = await db.createDocument(
        collectionId: collectionId,
        title: title.trim().isEmpty ? fileName : title.trim(),
        filePath: filePath,
        type: 'txt',
      );

      // 5. Process for RAG
      await _processDocument(doc, extractedText: content);
      
      state = state.copyWith(status: const AsyncValue.data(null));
    } catch (e) {
      state = state.copyWith(status: AsyncValue.error(e, StackTrace.current));
      rethrow;
    }
  }

  Future<void> uploadFiles(List<String> paths) async {
    final db = _ref.read(databaseProvider);
    final activeCollection = _ref.read(collectionProvider).activeCollection;
    final collectionId = activeCollection?.id;

    for (final path in paths) {
      final file = File(path);
      if (!await file.exists()) continue;

      final fileName = path.split(Platform.pathSeparator).last;
      final extension = fileName.split('.').last;

      final doc = await db.createDocument(
        collectionId: collectionId,
        title: fileName,
        filePath: path,
        type: extension,
      );

      _processDocument(doc);
    }
  }

  Future<void> _processDocument(Document doc, {String? extractedText}) async {
    final db = _ref.read(databaseProvider);
    
    try {
      String text;
      if (extractedText != null) {
        text = extractedText;
      } else {
        final file = File(doc.filePath);
        if (!await file.exists()) {
          throw Exception('Local file not found at ${doc.filePath}');
        }
        text = await _processor.extractText(file);
      }
      
      // Update DB with full text
      await (db.update(db.documents)..where((t) => t.id.equals(doc.id)))
        .write(DocumentsCompanion(content: Value(text)));

      // 2. Chunk Text
      // 2. Chunk Text
      final settings = _ref.read(settingsProvider);
      final chunks = _processor.chunkText(
        text, 
        settings.chunkSize,
        settings.chunkOverlap,
      );

      if (chunks.isEmpty) {
        await db.updateDocumentStatus(doc.id, 'completed');
        return;
      }

      // 3. Generate Embeddings
      final embeddingService = _ref.read(embeddingServiceProvider);
      
      final vectors = await embeddingService.getEmbeddings(chunks);
      
      final List<DocumentChunksCompanion> companions = [];
      for (var i = 0; i < chunks.length; i++) {
        final chunkContent = chunks[i];
        final vector = vectors[i];
        
        companions.add(DocumentChunksCompanion.insert(
          uuid: const Uuid().v4(),
          documentId: doc.id,
          content: chunkContent,
          embedding: jsonEncode(vector),
          index: i,
        ));
      }

      // 4. Save Chunks
      await db.insertDocumentChunks(companions);

      // 5. Complete
      await db.updateDocumentStatus(doc.id, 'completed');

    } catch (e) {
      await db.updateDocumentStatus(doc.id, 'failed', error: e.toString());
    }
  }

  Future<void> reprocessAllDocuments() async {
    if (state.isReprocessing) return;

    final db = _ref.read(databaseProvider);
    state = state.copyWith(isReprocessing: true, reprocessingProgress: 0.0);

    try {
      final allDocs = await db.select(db.documents).get();
      if (allDocs.isEmpty) {
        state = state.copyWith(isReprocessing: false);
        return;
      }

      for (var i = 0; i < allDocs.length; i++) {
        final doc = allDocs[i];
        
        // Clear old chunks for this document
        await db.deleteDocumentChunks(doc.id);
        
        // Re-process
        await _processDocument(doc);

        // Update progress
        state = state.copyWith(reprocessingProgress: (i + 1) / allDocs.length);
      }
    } catch (e) {
      state = state.copyWith(status: AsyncValue.error(e, StackTrace.current));
    } finally {
      state = state.copyWith(isReprocessing: false, reprocessingProgress: 0.0);
    }
  }

  Future<void> deleteDocument(int id) async {
    final db = _ref.read(databaseProvider);
    await db.deleteDocument(id);
  }

  Future<void> processWebLink(String url) async {
    final db = _ref.read(databaseProvider);
    final activeCollection = _ref.read(collectionProvider).activeCollection;
    final collectionId = activeCollection?.id;

    try {
      state = state.copyWith(status: const AsyncValue.loading());
      
      final dio = Dio();
      // Set a common browser User-Agent to avoid being blocked by some websites
      dio.options.headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36';
      
      final response = await dio.get(url);
      
      if (response.statusCode != 200) {
        throw Exception('Failed to load website: ${response.statusCode}');
      }

      final html = response.data.toString();
      
      final cleanText = _processor.extractTextFromHtml(html);

      if (cleanText.isEmpty) {
        throw Exception('Could not extract any content from the provided link.');
      }

      // Create a "virtual" document for the web link
      // We'll use the URL as the title if we can't find a title in the HTML
      String title = url;
      final titleMatch = RegExp(r'<title>(.*?)</title>', caseSensitive: false).firstMatch(html);
      if (titleMatch != null && titleMatch.group(1) != null) {
        title = titleMatch.group(1)!.trim();
      }

      final doc = await db.createDocument(
        collectionId: collectionId,
        title: title,
        filePath: url, // Store the URL as filePath for web docs
        type: 'web',
      );

      await _processDocument(doc, extractedText: cleanText);
      state = state.copyWith(status: const AsyncValue.data(null));
    } catch (e) {
      state = state.copyWith(status: AsyncValue.error(e, StackTrace.current));
      rethrow;
    }
  }
}
