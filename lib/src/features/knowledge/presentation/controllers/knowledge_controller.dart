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

const List<String> kSupportedDocumentExtensions = [
  '.txt', '.md', '.csv', '.json', '.dart', '.py', '.js', '.html', '.css', 
  '.c', '.cpp', '.h', '.java', '.go', '.rs', '.pdf', '.docx'
];

const List<String> kImageExtensions = [
  '.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'
];

class PendingChunk {
  final int documentId;
  final int chunkIndex;
  final String content;

  PendingChunk({
    required this.documentId,
    required this.chunkIndex,
    required this.content,
  });
}

class KnowledgeState {
  final AsyncValue<void> status;
  final double reprocessingProgress; // 0.0 to 1.0
  final bool isReprocessing;
  final int totalFilesToProcess;
  final int processedFilesCount;

  const KnowledgeState({
    this.status = const AsyncValue.data(null),
    this.reprocessingProgress = 0.0,
    this.isReprocessing = false,
    this.totalFilesToProcess = 0,
    this.processedFilesCount = 0,
  });

  KnowledgeState copyWith({
    AsyncValue<void>? status,
    double? reprocessingProgress,
    bool? isReprocessing,
    int? totalFilesToProcess,
    int? processedFilesCount,
  }) {
    return KnowledgeState(
      status: status ?? this.status,
      reprocessingProgress: reprocessingProgress ?? this.reprocessingProgress,
      isReprocessing: isReprocessing ?? this.isReprocessing,
      totalFilesToProcess: totalFilesToProcess ?? this.totalFilesToProcess,
      processedFilesCount: processedFilesCount ?? this.processedFilesCount,
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

      uploadItems(paths);
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

  Future<void> uploadItems(List<String> paths) async {
    final db = _ref.read(databaseProvider);
    final activeCollection = _ref.read(collectionProvider).activeCollection;
    final collectionId = activeCollection?.id;

    state = state.copyWith(status: const AsyncValue.loading());

    try {
      // 1. Scan for valid text files
      final List<File> validFiles = [];

      Future<void> addIfValid(File file) async {
          final ext = p.extension(file.path).toLowerCase();
          
          if (kImageExtensions.contains(ext)) {
            return; // Explicitly reject images
          }
          
          if (kSupportedDocumentExtensions.contains(ext)) {
             validFiles.add(file);
          } else if (ext.isEmpty || ext == '.log' || ext == '.env') {
             try {
                // Read a small chunk (4KB) to verify if it's text, instead of limiting total file size
                final stream = file.openRead(0, 4096);
                final bytes = <int>[];
                await for (final chunk in stream) {
                  bytes.addAll(chunk);
                }
                
                if (bytes.isNotEmpty) {
                  // Text files rarely contain null bytes
                  if (bytes.contains(0)) throw Exception('Binary file');
                  
                  // Trim last 4 bytes to avoid ending in the middle of a multi-byte UTF-8 char
                  final safeLength = bytes.length > 4 ? bytes.length - 4 : bytes.length;
                  utf8.decode(bytes.sublist(0, safeLength), allowMalformed: false);
                }
                validFiles.add(file);
             } catch (_) {
                // Not valid UTF-8, ignore
             }
          }
      }

      for (final path in paths) {
         if (await Directory(path).exists()) {
            final dir = Directory(path);
            await for (final entity in dir.list(recursive: true, followLinks: false)) {
               if (entity is File) {
                  await addIfValid(entity);
               }
            }
         } else if (await File(path).exists()) {
            await addIfValid(File(path));
         }
      }

      state = state.copyWith(
        totalFilesToProcess: validFiles.length,
        processedFilesCount: 0,
      );

      if (validFiles.isEmpty) {
        state = state.copyWith(status: const AsyncValue.data(null), totalFilesToProcess: 0);
        return;
      }

      // 2. Batch Processing Pipeline
      final settings = _ref.read(settingsProvider);
      final embeddingService = _ref.read(embeddingServiceProvider);
      
      final List<PendingChunk> buffer = [];

      Future<void> flushBuffer() async {
        if (buffer.isEmpty) return;

        final textsToEmbed = buffer.map((c) => c.content).toList();
        List<List<double>>? vectors;
        
        // Retry logic for embedding
        for (int i = 0; i < 3; i++) {
          try {
             vectors = await embeddingService.getEmbeddings(textsToEmbed);
             break;
          } catch (e) {
             if (i == 2) throw Exception('Failed to get embeddings after 3 retries: $e');
             await Future.delayed(const Duration(seconds: 2));
          }
        }

        if (vectors != null) {
          final List<DocumentChunksCompanion> companions = [];
          for (var i = 0; i < buffer.length; i++) {
            companions.add(DocumentChunksCompanion.insert(
              uuid: const Uuid().v4(),
              documentId: buffer[i].documentId,
              content: buffer[i].content,
              embedding: jsonEncode(vectors[i]),
              index: buffer[i].chunkIndex,
            ));
          }
          await db.insertDocumentChunks(companions);
        }
        buffer.clear();
      }

      int processed = 0;
      for (final file in validFiles) {
        try {
          // Yield to event loop to keep UI responsive
          await Future.delayed(Duration.zero);
          
          // Use extension-aware extraction
          final extensionStr = p.extension(file.path).toLowerCase();
          String text;
          
          if (extensionStr == '.pdf' || extensionStr == '.docx') {
             text = await _processor.extractText(file, extension: extensionStr);
          } else {
             // For standard code/text files, use fast native reading instead
             final bytes = await file.readAsBytes();
             try {
               text = utf8.decode(bytes);
             } catch (_) {
               text = utf8.decode(bytes, allowMalformed: true);
             }
          }
          
          final fileName = p.basename(file.path);
          final cleanExtension = extensionStr.replaceAll('.', '');

          final doc = await db.createDocument(
            collectionId: collectionId,
            title: fileName,
            filePath: file.path,
            type: cleanExtension.isEmpty ? 'txt' : cleanExtension,
          );

          await (db.update(db.documents)..where((t) => t.id.equals(doc.id)))
            .write(DocumentsCompanion(content: Value(text)));

          final chunks = _processor.chunkText(text, settings.chunkSize, settings.chunkOverlap);

          if (chunks.isEmpty) {
             await db.updateDocumentStatus(doc.id, 'completed');
          } else {
             for (int i = 0; i < chunks.length; i++) {
                 buffer.add(PendingChunk(documentId: doc.id, chunkIndex: i, content: chunks[i]));
                 if (buffer.length >= 32) {
                    await flushBuffer();
                 }
             }
             await db.updateDocumentStatus(doc.id, 'completed');
          }
        } catch (e) {
          // Log error internally or ignore so upload can continue
          // debugPrint('Error processing file ${file.path}: $e');
        }

        processed++;
        state = state.copyWith(processedFilesCount: processed);
      }

      if (buffer.isNotEmpty) {
         await flushBuffer();
      }

      state = state.copyWith(
        status: const AsyncValue.data(null),
        totalFilesToProcess: 0,
        processedFilesCount: 0,
      );

    } catch (e) {
      state = state.copyWith(
        status: AsyncValue.error(e, StackTrace.current),
        totalFilesToProcess: 0,
        processedFilesCount: 0,
      );
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

      // 3. Generate Embeddings in batches of 32
      final embeddingService = _ref.read(embeddingServiceProvider);
      
      for (var batchStart = 0; batchStart < chunks.length; batchStart += 32) {
        final batchEnd = (batchStart + 32 < chunks.length) ? batchStart + 32 : chunks.length;
        final batchChunks = chunks.sublist(batchStart, batchEnd);
        
        List<List<double>>? vectors;
        // Retry logic for embedding
        for (int i = 0; i < 3; i++) {
          try {
             vectors = await embeddingService.getEmbeddings(batchChunks);
             break;
          } catch (e) {
             if (i == 2) throw Exception('Failed to get embeddings after 3 retries: $e');
             await Future.delayed(const Duration(seconds: 2));
          }
        }

        if (vectors != null) {
          final List<DocumentChunksCompanion> companions = [];
          for (var i = 0; i < batchChunks.length; i++) {
            companions.add(DocumentChunksCompanion.insert(
              uuid: const Uuid().v4(),
              documentId: doc.id,
              content: batchChunks[i],
              embedding: jsonEncode(vectors[i]),
              index: batchStart + i,
            ));
          }

          // 4. Save Chunks
          await db.insertDocumentChunks(companions);
        }
      }

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
