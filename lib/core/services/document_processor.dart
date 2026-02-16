import 'dart:convert';
import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path/path.dart' as p;

class DocumentProcessor {
  /// Extracts plain text from the given file based on its extension.
  Future<String> extractText(File file) async {
    final ext = p.extension(file.path).toLowerCase();
    
    String text;
    try {
      if (ext == '.pdf') {
        text = await _extractFromPdf(file);
      } else {
        // Basic text file handling with fallback for encoding issues
        try {
          text = await file.readAsString();
        } catch (_) {
          final bytes = await file.readAsBytes();
          text = utf8.decode(bytes, allowMalformed: true);
        }
      }
    } catch (e) {
      text = '';
    }
    
    return normalizeText(text);
  }

  /// Normalizes text to be clean for AI consumption while preserving semantic structure.
  /// It collapses layout-induced breaks but preserves paragraph boundaries.
  String normalizeText(String text) {
    if (text.isEmpty) return text;

    return text
        // 1. Normalize line endings
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        // 2. Protect paragraph breaks (double newlines)
        .replaceAll('\n\n', '[[PARA]]')
        // 3. Collapse single newlines and other whitespace that are often purely layout-based
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .join(' ')
        // 4. Restore paragraph breaks
        .replaceAll('[[PARA]]', '\n\n')
        // 5. Final cleanup of whitespace
        .replaceAll(RegExp(r' +'), ' ')
        .trim();
  }

  /// Official implementation pattern for PDF text extraction.
  Future<String> _extractFromPdf(File file) async {
    final bytes = await file.readAsBytes();
    final PdfDocument document = PdfDocument(inputBytes: bytes);
    
    try {
      final PdfTextExtractor extractor = PdfTextExtractor(document);
      // Extracts all text including layout info
      final String text = extractor.extractText();
      return text;
    } finally {
      // CRITICAL: Always dispose documents to prevent memory leaks
      document.dispose();
    }
  }

  /// Splits text into units of word count, respecting semantic boundaries.
  /// [chunkSizeWords] is the target number of words per chunk.
  /// [overlapWords] is the number of words to carry over for context continuity.
  List<String> chunkText(String text, int chunkSizeWords, int overlapWords) {
    if (text.isEmpty) return [];
    if (chunkSizeWords <= 0) return [text];
    
    // Priority for splitting: Paragraphs -> Newlines -> Sentences -> Words
    final List<String> separators = ['\n\n', '\n', '. ', '? ', '! ', ' '];
    final List<String> basePieces = _recursiveSplit(text, separators, chunkSizeWords);
    
    final List<String> chunks = [];
    List<String> currentChunkBuffer = [];
    int currentWordCount = 0;

    for (final piece in basePieces) {
      final pieceWordCount = _countWords(piece);
      
      // If adding this piece exceeds chunk size, finalize current and handle overlap
      if (currentWordCount + pieceWordCount > chunkSizeWords && currentChunkBuffer.isNotEmpty) {
        chunks.add(currentChunkBuffer.join('').trim());
        
        // --- Handle Overlap ---
        // Backtrack to reach the overlap target
        final List<String> overlapPieces = [];
        int overlapCounter = 0;
        for (int i = currentChunkBuffer.length - 1; i >= 0; i--) {
          final p = currentChunkBuffer[i];
          final wc = _countWords(p);
          if (overlapCounter + wc <= overlapWords || overlapPieces.isEmpty) {
            overlapPieces.insert(0, p);
            overlapCounter += wc;
          } else {
            break;
          }
        }
        currentChunkBuffer = overlapPieces;
        currentWordCount = overlapCounter;
      }
      
      currentChunkBuffer.add(piece);
      currentWordCount += pieceWordCount;
    }
    
    // Add the final remaining buffer
    if (currentChunkBuffer.isNotEmpty) {
      chunks.add(currentChunkBuffer.join('').trim());
    }

    return chunks;
  }

  /// Recursively splits text until parts are within [maxWords].
  List<String> _recursiveSplit(String text, List<String> separators, int maxWords) {
    if (_countWords(text) <= maxWords || separators.isEmpty) {
      return [text];
    }

    final separator = separators.first;
    final nextSeparators = separators.sublist(1);
    
    final List<String> result = [];
    final List<String> parts = text.split(separator);

    for (int i = 0; i < parts.length; i++) {
      String part = parts[i];
      // Keep the separator on all but the last part for integrity
      if (i < parts.length - 1) {
        part += separator;
      }
      
      if (part.isEmpty) continue;
      
      if (_countWords(part) > maxWords) {
        result.addAll(_recursiveSplit(part, nextSeparators, maxWords));
      } else {
        result.add(part);
      }
    }

    return result;
  }

  int _countWords(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 0;
    // Split by any whitespace but count non-empty fragments
    return trimmed.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
  }
}
