import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sift_app/core/storage/sift_database.dart';
import 'package:sift_app/src/features/chat/presentation/controllers/collection_controller.dart';
import '../controllers/knowledge_controller.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:intl/intl.dart';
import '../widgets/document_viewer.dart';

class DocumentsScreen extends ConsumerStatefulWidget {
  final bool autoOpenAddMenu;

  const DocumentsScreen({
    super.key,
    this.autoOpenAddMenu = false,
  });

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoOpenAddMenu) {
      Future.microtask(() {
        if (mounted) {
          _showAddMenu(context, ref);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeCollection = ref.watch(collectionProvider).activeCollection;
    final AsyncValue<List<Document>> documentsAsync = ref.watch(filteredDocumentsProvider);
    final knowledgeState = ref.watch(knowledgeControllerProvider);
    final isProcessingFolder = knowledgeState.totalFilesToProcess > 0;

    // Listen for errors from the knowledge controller
    ref.listen<KnowledgeState>(knowledgeControllerProvider, (previous, next) {
      next.status.whenOrNull(
        error: (error, stack) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $error'),
              backgroundColor: theme.colorScheme.error,
            ),
          );
        },
      );
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(activeCollection?.name ?? 'All Documents'),
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: (MediaQuery.of(context).size.width * 0.95).clamp(0.0, 900.0),
          child: DropTarget(
        onDragEntered: (details) => setState(() => _isDragging = true),
        onDragExited: (details) => setState(() => _isDragging = false),
        onDragDone: (details) {
          final paths = details.files.map((f) => f.path).toList();
          setState(() => _isDragging = false);
          
          ref.read(knowledgeControllerProvider.notifier).uploadItems(paths);
        },
        child: Stack(
          children: [
            documentsAsync.when<Widget>(
              data: (documents) {
                if (documents.isEmpty) {
                  return _buildEmptyState(theme, activeCollection == null);
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: documents.length,
                  itemBuilder: (context, index) {
                    final doc = documents[index];
                    return _buildDocumentCard(context, ref, doc, theme);
                  },
                );
              },
              error: (err, stack) => Center(child: Text('Error: $err')),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
            if (_isDragging)
              Container(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.colorScheme.primary, width: 2),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.upload_file, color: theme.colorScheme.onPrimaryContainer),
                        const SizedBox(width: 12),
                        Text(
                          'Drop documents to upload',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (isProcessingFolder)
              Positioned(
                bottom: activeCollection != null ? 80 : 16, // avoid fab
                left: 16,
                right: 16,
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Processing Folder...',
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${knowledgeState.processedFilesCount} / ${knowledgeState.totalFilesToProcess}',
                              style: theme.textTheme.labelMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: knowledgeState.processedFilesCount / knowledgeState.totalFilesToProcess,
                            minHeight: 8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
        ),
      ),
      floatingActionButton: activeCollection != null ? FloatingActionButton.extended(
        onPressed: () => _showAddMenu(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add Content'),
      ) : null,
    );
  }

  void _showAddMenu(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Add Documents',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 24),
              _buildAddAction(
                context,
                icon: Icons.upload_file_rounded,
                title: 'Upload Files',
                subtitle: 'PDF, DOCX, Markdown, or Text',
                color: theme.colorScheme.primary,
                onTap: () {
                  Navigator.pop(context);
                  ref.read(knowledgeControllerProvider.notifier).pickAndUploadDocument();
                },
              ),
              const SizedBox(height: 12),
              _buildAddAction(
                context,
                icon: Icons.link_rounded,
                title: 'Add Web Link',
                subtitle: 'Import content from a website',
                color: theme.colorScheme.secondary,
                onTap: () {
                  Navigator.pop(context);
                  _showUrlInputDialog(context, ref);
                },
              ),
              const SizedBox(height: 12),
              _buildAddAction(
                context,
                icon: Icons.paste_rounded,
                title: 'Paste Text',
                subtitle: 'Save text directy to your library',
                color: theme.colorScheme.tertiary,
                onTap: () {
                  Navigator.pop(context);
                  _showPasteTextInputDialog(context, ref);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddAction(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPasteTextInputDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    final contentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Paste Text Content'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  hintText: 'Document Title (Optional)',
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: contentController,
                maxLines: 10,
                minLines: 5,
                decoration: const InputDecoration(
                  hintText: 'Paste your text here...',
                  labelText: 'Content',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                autofocus: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final content = contentController.text.trim();
              if (content.isNotEmpty) {
                ref.read(knowledgeControllerProvider.notifier).savePastedText(
                  titleController.text.trim(),
                  content,
                );
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please paste some content first')),
                );
              }
            },
            child: const Text('Save Document'),
          ),
        ],
      ),
    );
  }

  void _showUrlInputDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Web Link'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'https://example.com',
            labelText: 'Website URL',
          ),
          keyboardType: TextInputType.url,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final url = controller.text.trim();
              if (url.isNotEmpty && (url.startsWith('http://') || url.startsWith('https://'))) {
                ref.read(knowledgeControllerProvider.notifier).processWebLink(url);
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid URL starting with http:// or https://')),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(BuildContext context, WidgetRef ref, Document doc, ThemeData theme) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainer,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => Dialog(
              backgroundColor: theme.colorScheme.surface,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 800, maxHeight: 800),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 16, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              doc.title,
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: DocumentViewer(documentId: doc.id),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        leading: _buildFileIcon(doc.type, theme),
        title: Text(
          doc.title,
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        subtitle: Row(
          children: [
            Text(
              DateFormat.yMMMd().format(doc.createdAt),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (doc.status != 'completed') ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _getStatusColor(doc.status, theme).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  doc.status.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: _getStatusColor(doc.status, theme),
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ],
        ),
        trailing: doc.status == 'processing'
            ? const SizedBox(
                width: 16, 
                height: 16, 
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) async {
                  if (value == 'delete') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Document'),
                        content: Text('Are you sure you want to delete "${doc.title}"?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      ref.read(knowledgeControllerProvider.notifier).deleteDocument(doc.id);
                    }
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Text('Delete'),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Color _getStatusColor(String status, ThemeData theme) {
    switch (status) {
      case 'processing': return theme.colorScheme.primary;
      case 'failed': return theme.colorScheme.error;
      case 'completed': return theme.colorScheme.tertiary; // success
      default: return theme.colorScheme.outline;
    }
  }

  Widget _buildEmptyState(ThemeData theme, bool isGlobal) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open,
            size: 64,
            color: theme.colorScheme.outline.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            isGlobal ? 'No global documents' : 'No documents in this collection',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isGlobal ? 'Upload files to the general library.' : 'Upload files to give Sift more context for this collection.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileIcon(String type, ThemeData theme) {
    IconData icon;
    Color color;

    switch (type) {
      case 'pdf':
        icon = Icons.picture_as_pdf;
        color = Colors.redAccent;
        break;
      case 'md':
      case 'txt':
        icon = Icons.description;
        color = theme.colorScheme.primary;
        break;
      case 'image':
        icon = Icons.image;
        color = Colors.purpleAccent;
        break;
      case 'web':
        icon = Icons.public;
        color = Colors.blue;
        break;
      default:
        icon = Icons.insert_drive_file;
        color = theme.colorScheme.secondary;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }
}
