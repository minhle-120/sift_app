import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sift_app/core/storage/sift_database.dart';
import 'package:sift_app/src/features/knowledge/presentation/views/documents_screen.dart';
import '../controllers/collection_controller.dart';
import '../controllers/workbench_controller.dart';
import '../controllers/chat_controller.dart';
import '../widgets/workspace_pane.dart';
import '../widgets/conversation_drawer.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat_input_field.dart';
import 'settings_screen.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }


  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;
    final theme = Theme.of(context);
    final workbench = ref.watch(workbenchProvider);
    final collectionState = ref.watch(collectionProvider);
    final chatState = ref.watch(chatControllerProvider);

    // Auto-scroll when messages change
    ref.listen<ChatState>(chatControllerProvider, (previous, next) {
      final messageCountChanged = previous?.messages.length != next.messages.length;
      if (messageCountChanged) {
        _scrollToBottom();
      }

      // Show error snackbar if error occurs
      if (next.error != null && next.error != previous?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
    });

    final chatView = Column(
      children: [
        _buildHeader(context, ref, collectionState.activeCollection),
        
        Expanded(
          child: Column(
            children: [
              if (!chatState.isConnectionValid)
                _buildConnectionWarning(theme, chatState.connectionError),
              Expanded(
                child: SelectionArea(
                  child: collectionState.activeCollection == null
                      ? _buildLibraryView(context, ref, collectionState)
                      : (chatState.messages.isEmpty && !chatState.isLoading
                          ? _buildEmptyChatState(theme) 
                          : _buildMessagesList(chatState)),
                ),
              ),
            ],
          ),
        ),

        if (collectionState.activeCollection != null)
          const ChatInputField(),
      ],
    );

    if (isDesktop) {
      final workbenchWidth = workbench.isCollapsed ? 0.0 : size.width * workbench.panelRatio;
      
      return Scaffold(
        drawer: const ConversationDrawer(),
        body: Row(
          children: [
            Expanded(child: chatView),
            if (!workbench.isCollapsed) ...[
              GestureDetector(
                onHorizontalDragUpdate: (details) {
                  final newRatio = (size.width * workbench.panelRatio - details.delta.dx) / size.width;
                  ref.read(workbenchProvider.notifier).updateRatio(newRatio);
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeLeftRight,
                  child: Container(
                    width: 4,
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
              ),
              SizedBox(
                width: workbenchWidth,
                child: const WorkbenchPanel(),
              ),
            ],
          ],
        ),
      );
    } else {
      return Scaffold(
        drawer: const ConversationDrawer(),
        body: chatView,
      );
    }
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, KnowledgeCollection? collection) {
    final theme = Theme.of(context);
    final hasActiveCollection = collection != null;

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              collection?.name ?? 'Sift Library',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Wrap actions in a scroll view to prevent overflow on very narrow views
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasActiveCollection) ...[
                  IconButton(
                    icon: Icon(
                      ref.watch(workbenchProvider).isCollapsed 
                          ? Icons.view_sidebar_outlined 
                          : Icons.view_sidebar,
                    ),
                    tooltip: 'Toggle Workbench',
                    onPressed: () => ref.read(workbenchProvider.notifier).toggleCollapsed(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.description_outlined),
                    tooltip: 'Collection Documents',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const DocumentsScreen()),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_comment_outlined),
                    tooltip: 'New Chat',
                    onPressed: () => ref.read(chatControllerProvider.notifier).newChat(),
                  ),
                ],
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLibraryView(BuildContext context, WidgetRef ref, CollectionState state) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.collections_bookmark_outlined, size: 64, color: theme.colorScheme.primary.withValues(alpha: 0.5)),
            const SizedBox(height: 24),
            Text(
              'Your Collections',
              style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
             Text(
              'Pick a collection to start researching or create a new one.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: [
                ...state.allCollections.map((c) => _buildCollectionCard(context, ref, c)),
                _buildCreateCard(context, ref),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollectionCard(BuildContext context, WidgetRef ref, KnowledgeCollection collection) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => ref.read(collectionProvider.notifier).selectCollection(collection),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 180,
        height: 140,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_outlined, size: 40, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              collection.name,
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateCard(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => _showCreateCollectionDialog(context, ref),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 180,
        height: 140,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.3), 
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, size: 32, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              'New Collection',
              style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyChatState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome,
            size: 48,
            color: theme.colorScheme.primary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'What can I help you with?',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ask a question based on this collection\'s documents.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList(ChatState chatState) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 20),
      itemCount: chatState.messages.length,
      itemBuilder: (context, index) {
        return MessageBubble(message: chatState.messages[index]);
      },
    );
  }

  // Remove _buildResearchStatusIndicator


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

  Widget _buildConnectionWarning(ThemeData theme, String? error) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.errorContainer,
      child: Row(
        children: [
          Icon(Icons.wifi_off_rounded, size: 20, color: theme.colorScheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error ?? "Cannot connect to AI Server",
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: () => ref.read(chatControllerProvider.notifier).checkAiConnection(),
            child: Text(
              "Retry",
              style: TextStyle(color: theme.colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}
