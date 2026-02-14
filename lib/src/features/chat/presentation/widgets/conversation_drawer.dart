import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sift_app/core/storage/sift_database.dart';
import 'package:sift_app/core/storage/database_provider.dart';
import '../controllers/collection_controller.dart';
import '../controllers/chat_controller.dart';
import 'package:sift_app/src/features/knowledge/presentation/views/documents_screen.dart';

class ConversationDrawer extends ConsumerWidget {
  const ConversationDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final collectionState = ref.watch(collectionProvider);

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Row(
                children: [
                  Icon(Icons.hub_outlined, size: 24, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Collections',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.add_box_outlined, size: 22),
                    tooltip: 'New Collection',
                    onPressed: () => _showCreateCollectionDialog(context, ref),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            
            // Library & Collections List
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                   _buildLibraryTile(context, ref),
                   ...collectionState.allCollections.map(
                    (collection) => _buildCollectionFolder(context, ref, collection),
                  ),
                ],
              ),
            ),
            
          ],
        ),
      ),
    );
  }

  Widget _buildLibraryTile(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const Icon(Icons.library_books_outlined),
      title: const Text('Library Overview'),
      onTap: () {
        ref.read(collectionProvider.notifier).clearSelection();
        Navigator.pop(context);
      },
    );
  }

  Widget _buildCollectionFolder(BuildContext context, WidgetRef ref, KnowledgeCollection collection) {
    final theme = Theme.of(context);
    final db = ref.watch(databaseProvider);
    final activeCollectionId = ref.watch(collectionProvider).activeCollection?.id;
    final isSelected = activeCollectionId == collection.id;

    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        leading: Icon(
          Icons.folder_shared_outlined, 
          size: 20,
          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
        ),
        title: Text(
          collection.name,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
          ),
        ),
        initiallyExpanded: isSelected,
        children: [
          StreamBuilder<List<Conversation>>(
            stream: db.watchConversations(collection.id),
            builder: (context, snapshot) {
              final conversations = snapshot.data ?? [];
              
              return Column(
                children: [
                   // Collection Actions
                   Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    child: ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      contentPadding: const EdgeInsets.only(left: 32, right: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      leading: Icon(Icons.description_outlined, size: 18, color: theme.colorScheme.primary),
                      title: Text(
                        'View Documents',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onTap: () {
                        ref.read(collectionProvider.notifier).selectCollection(collection);
                        Navigator.pop(context); // Close drawer
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const DocumentsScreen()),
                        );
                      },
                    ),
                  ),

                  // Collection Settings
                   Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    child: ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      contentPadding: const EdgeInsets.only(left: 32, right: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      leading: Icon(Icons.settings_outlined, size: 18, color: theme.colorScheme.onSurfaceVariant),
                      title: Text(
                        'Collection Settings',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                      onTap: () {
                         showDialog(
                          context: context,
                          builder: (context) => SimpleDialog(
                            title: Text('Settings: ${collection.name}'),
                            children: [
                              SimpleDialogOption(
                                onPressed: () {
                                  Navigator.pop(context); // Close settings
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Delete Collection?'),
                                      content: Text('Are you sure you want to delete "${collection.name}"?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            ref.read(collectionProvider.notifier).deleteCollection(collection.id);
                                            Navigator.pop(context);
                                          },
                                          style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline, size: 20, color: theme.colorScheme.error),
                                    const SizedBox(width: 12),
                                    Text('Delete Collection', style: TextStyle(color: theme.colorScheme.error)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  if (conversations.isEmpty)
                     Padding(
                        padding: const EdgeInsets.only(left: 56, bottom: 8, top: 4),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'No chats yet',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      )
                  else
                    ...conversations.map((conv) => _buildConversationTile(context, ref, conv)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildConversationTile(BuildContext context, WidgetRef ref, Conversation conversation) {
     final theme = Theme.of(context);
     // TODO: Highlight if active conversation
     
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.only(left: 32, right: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: Text(
          conversation.title,
          style: const TextStyle(fontSize: 13),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          _formatDate(conversation.lastUpdatedAt),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 10,
          ),
        ),
        trailing: SizedBox(
          width: 28,
          height: 28,
          child: PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, size: 16, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
            padding: EdgeInsets.zero,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'delete',
                height: 32,
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 16, color: theme.colorScheme.error),
                    const SizedBox(width: 8),
                    Text(
                      'Delete', 
                      style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.error),
                    ),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'delete') {
                 ref.read(chatControllerProvider.notifier).deleteConversation(conversation.id);
              }
            },
          ),
        ),
        onTap: () {
          // Select collection first if not already
          final activeCollectionId = ref.read(collectionProvider).activeCollection?.id;
          if (activeCollectionId != conversation.collectionId) {
             // We need to fetch the collection object to select it. 
             // For now, assume it's in the list or just load conversation.
             // Ideally collectionController should have selectById.
          }
          
          ref.read(chatControllerProvider.notifier).loadConversation(conversation.id);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showCreateCollectionDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Collection'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Collection Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          onSubmitted: (val) {
             if (val.isNotEmpty) {
                ref.read(collectionProvider.notifier).createCollection(val);
                Navigator.pop(context);
              }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                ref.read(collectionProvider.notifier).createCollection(controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.month}/${date.day}';
  }
}
