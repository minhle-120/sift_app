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
        // Try reading as string, fall back to malformed-allowed UTF8 if it fails
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

  /// Cleans up text by collapsing all whitespace (including \r\n) into single spaces.
  /// This is the most robust approach for fragmented PDF text and noisy documents.
  String normalizeText(String text) {
    if (text.isEmpty) return text;

    return text
        .replaceAll('\r', '')
        .replaceAll(RegExp(r'[\n\t ]+'), ' ')
        .trim();
  }

  Future<String> _extractFromPdf(File file) async {
    // Load the PDF document
    final bytes = await file.readAsBytes();
    final document = PdfDocument(inputBytes: bytes);
    
    try {
      final extractor = PdfTextExtractor(document);
      final text = extractor.extractText();
      return text;
    } finally {
      document.dispose();
    }
  }

  /// Splits text into units of word count, respecting semantic boundaries.
  /// [chunkSizeWords] is the target number of words per chunk.
  /// [overlapWords] is the number of words to carry over.
  List<String> chunkText(String text, int chunkSizeWords, int overlapWords) {
    if (text.isEmpty) return [];
    if (chunkSizeWords <= 0) return [text];
    
    // Priority: Paragraphs -> Newlines -> Sentences -> Words
    final List<String> separators = ['\n\n', '\n', '. ', ' '];
    final List<String> pieces = _recursiveSplit(text, separators, chunkSizeWords);
    
    final List<String> chunks = [];
    List<String> currentChunkPieces = [];
    int currentWordCount = 0;

    for (final piece in pieces) {
      final pieceWordCount = _countWords(piece);
      
      if (currentWordCount + pieceWordCount > chunkSizeWords && currentChunkPieces.isNotEmpty) {
        // Current chunk is full, finish it
        chunks.add(currentChunkPieces.join('').trim());
        
        // --- Handle Overlap ---
        // Backtrack to include overlapWords
        final List<String> nextChunkPieces = [];
        int overlapCounter = 0;
        for (int i = currentChunkPieces.length - 1; i >= 0; i--) {
          final p = currentChunkPieces[i];
          final wc = _countWords(p);
          if (overlapCounter + wc <= overlapWords || nextChunkPieces.isEmpty) {
            nextChunkPieces.insert(0, p);
            overlapCounter += wc;
          } else {
            break;
          }
        }
        currentChunkPieces = nextChunkPieces;
        currentWordCount = overlapCounter;
      }
      
      currentChunkPieces.add(piece);
      currentWordCount += pieceWordCount;
    }
    
    if (currentChunkPieces.isNotEmpty) {
      chunks.add(currentChunkPieces.join('').trim());
    }

    return chunks;
  }

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
      // Re-add the separator to all but the last part (or keep it as it was if possible)
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
    return trimmed.split(RegExp(r'\s+')).length;
  }
}
