import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sift_app/core/storage/sift_database.dart';
import 'package:sift_app/src/features/chat/presentation/controllers/collection_controller.dart';
import '../controllers/knowledge_controller.dart';
import 'package:intl/intl.dart';

class DocumentsScreen extends ConsumerWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final activeCollection = ref.watch(collectionProvider).activeCollection;
    
    final AsyncValue<List<Document>> documentsAsync = ref.watch(filteredDocumentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(activeCollection?.name ?? 'All Documents'),
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: documentsAsync.when<Widget>(
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
      floatingActionButton: activeCollection != null ? FloatingActionButton.extended(
        onPressed: () {
          ref.read(knowledgeControllerProvider.notifier).pickAndUploadDocument();
        },
        icon: const Icon(Icons.upload_file),
        label: const Text('Upload Document'),
      ) : null,
    );
  }

  Widget _buildDocumentCard(BuildContext context, WidgetRef ref, Document doc, ThemeData theme) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainer,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
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
