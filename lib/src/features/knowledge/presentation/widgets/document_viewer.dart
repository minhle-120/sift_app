import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sift_app/core/storage/sift_database.dart';
import 'package:sift_app/core/storage/database_provider.dart';

class DocumentViewer extends ConsumerStatefulWidget {
  final int documentId;
  final int? initialChunkIndex;

  const DocumentViewer({
    super.key,
    required this.documentId,
    this.initialChunkIndex,
  });

  @override
  ConsumerState<DocumentViewer> createState() => _DocumentViewerState();
}

class _DocumentViewerState extends ConsumerState<DocumentViewer> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _highlightKey = GlobalKey();

  @override
  void didUpdateWidget(DocumentViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialChunkIndex != oldWidget.initialChunkIndex && widget.initialChunkIndex != null) {
      _scrollToHighlight();
    }
  }

  void _scrollToHighlight() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_highlightKey.currentContext != null) {
        Scrollable.ensureVisible(
          _highlightKey.currentContext!,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          alignment: 0.1, // Scroll until it's near the top
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final theme = Theme.of(context);

    return FutureBuilder<Document?>(
      future: db.getDocumentById(widget.documentId),
      builder: (context, docSnapshot) {
        if (docSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final doc = docSnapshot.data;
        if (doc == null) {
          return const Center(child: Text('Document not found.'));
        }

        return FutureBuilder<List<DocumentChunk>>(
          future: db.getDocumentChunks(widget.documentId),
          builder: (context, chunksSnapshot) {
            if (chunksSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
            }
            
            final fullText = doc.content ?? '';
            final chunks = chunksSnapshot.data ?? [];
            final targetChunkIndex = widget.initialChunkIndex;
            
            if (fullText.isEmpty) {
              return const Center(child: Text('Document has no content.'));
            }

            // If we have a target chunk, search for it in the full text
            String? targetContent;
            if (targetChunkIndex != null && targetChunkIndex < chunks.length) {
              targetContent = chunks[targetChunkIndex].content;
            }

            // Build the text segments
            final List<TextSpan> spans = [];
            if (targetContent != null) {
              final startIndex = fullText.indexOf(targetContent);
              if (startIndex != -1) {
                _scrollToHighlight(); // Trigger scroll after build

                spans.add(TextSpan(text: fullText.substring(0, startIndex)));
                spans.add(TextSpan(
                  children: [
                    WidgetSpan(
                      child: SizedBox.shrink(key: _highlightKey),
                    ),
                    TextSpan(
                      text: targetContent,
                      style: TextStyle(
                        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.3),
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ));
                spans.add(TextSpan(text: fullText.substring(startIndex + targetContent.length)));
              } else {
                spans.add(TextSpan(text: fullText));
              }
            } else {
              spans.add(TextSpan(text: fullText));
            }

            return DefaultTabController(
              length: 2,
              child: Container(
                color: theme.colorScheme.surface,
                child: Column(
                  children: [
                    TabBar(
                      tabs: const [
                        Tab(text: 'Parsed Text'),
                        Tab(text: 'Chunks'),
                      ],
                      labelColor: theme.colorScheme.primary,
                      unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                      indicatorColor: theme.colorScheme.primary,
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          // Tab 1: Full Parsed Text
                          SingleChildScrollView(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(24),
                            child: SelectionArea(
                              child: Text.rich(
                                TextSpan(
                                  children: spans,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    height: 1.8,
                                    letterSpacing: 0.2,
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          
                          // Tab 2: Chunks List
                          chunks.isEmpty
                              ? const Center(child: Text('No chunks available.'))
                              : ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: chunks.length,
                                  itemBuilder: (context, index) {
                                    final chunk = chunks[index];
                                    final isTarget = targetChunkIndex == index;
                                    return Card(
                                      elevation: isTarget ? 4 : 1,
                                      color: isTarget 
                                          ? theme.colorScheme.primaryContainer 
                                          : theme.colorScheme.surfaceContainer,
                                      margin: const EdgeInsets.only(bottom: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: isTarget 
                                            ? BorderSide(color: theme.colorScheme.primary, width: 2)
                                            : BorderSide.none,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Text(
                                                    'Chunk ${chunk.index}', // assuming chunk has index property, else just index
                                                    style: theme.textTheme.labelMedium?.copyWith(
                                                      color: theme.colorScheme.primary,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            SelectionArea(
                                              child: Text(
                                                chunk.content,
                                                style: theme.textTheme.bodyMedium?.copyWith(
                                                  height: 1.6,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
