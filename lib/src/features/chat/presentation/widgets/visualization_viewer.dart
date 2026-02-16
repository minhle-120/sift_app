import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';

class VisualizationViewer extends StatefulWidget {
  final Map<String, dynamic> schema;

  const VisualizationViewer({super.key, required this.schema});

  @override
  State<VisualizationViewer> createState() => _VisualizationViewerState();
}

class _VisualizationViewerState extends State<VisualizationViewer> {
  final Graph graph = Graph();
  late final TransformationController _transformationController;
  late final GraphViewController controller;
  
  late Algorithm algorithm;
  bool _isInitialized = false;
  String? _rootNodeId;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    controller = GraphViewController(transformationController: _transformationController);
    _setupGraph();
  }

  @override
  void didUpdateWidget(VisualizationViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.schema != oldWidget.schema) {
      _setupGraph();
    }
  }

  @override
  void dispose() {
    // Note: GraphView internally disposes the transformationController
    // if it's passed via GraphViewController. We don't dispose it here
    // to avoid a 'used after disposed' error during unmounting.
    super.dispose();
  }

  void _setupGraph() {
    // Clear existing graph data
    graph.nodes.clear();
    graph.edges.clear();
    
    final nodesData = widget.schema['nodes'] as List? ?? [];
    final edgesData = widget.schema['edges'] as List? ?? [];
    var layoutType = widget.schema['layoutType'] as String? ?? 'tree';

    final Map<String, Node> nodeMap = {};
    final Map<String, int> incomingEdges = {};

    // 1. Create Nodes
    String? firstNodeId;
    for (final n in nodesData) {
      final id = n['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      
      final node = Node.Id(id);
      nodeMap[id] = node;
      graph.addNode(node);
      incomingEdges[id] = 0;
      
      firstNodeId ??= id;
    }
    _rootNodeId = firstNodeId;

    // 2. Create Edges & Track structure
    for (final e in edgesData) {
      final from = e['from']?.toString();
      final to = e['to']?.toString();
      if (from != null && to != null && 
          nodeMap.containsKey(from) && 
          nodeMap.containsKey(to)) {
        graph.addEdge(nodeMap[from]!, nodeMap[to]!);
        incomingEdges[to] = (incomingEdges[to] ?? 0) + 1;
      }
    }

    // 3. Structure Detection & Algorithm Selection
    final bool hasMultiParent = incomingEdges.values.any((count) => count > 1);
    
    if (hasMultiParent && (layoutType == 'tree' || layoutType == 'mindmap' || layoutType == 'balloon' || layoutType == 'radial')) {
      layoutType = 'directed';
    }

    switch (layoutType) {
      case 'tree':
        final config = BuchheimWalkerConfiguration()
          ..siblingSeparation = 100
          ..levelSeparation = 150
          ..subtreeSeparation = 150
          ..orientation = BuchheimWalkerConfiguration.ORIENTATION_TOP_BOTTOM;
        algorithm = BuchheimWalkerAlgorithm(config, TreeEdgeRenderer(config));
        graph.isTree = true;
        break;

      case 'mindmap':
        final config = BuchheimWalkerConfiguration()
          ..siblingSeparation = 100
          ..levelSeparation = 150
          ..subtreeSeparation = 150
          ..orientation = BuchheimWalkerConfiguration.ORIENTATION_LEFT_RIGHT;
        algorithm = MindmapAlgorithm(config, MindmapEdgeRenderer(config));
        graph.isTree = true;
        break;

      case 'balloon':
        final config = BuchheimWalkerConfiguration()
          ..siblingSeparation = 100
          ..levelSeparation = 150
          ..subtreeSeparation = 150;
        algorithm = BalloonLayoutAlgorithm(config, null);
        graph.isTree = true;
        break;

      case 'radial':
        final config = BuchheimWalkerConfiguration()
          ..siblingSeparation = 100
          ..levelSeparation = 150
          ..subtreeSeparation = 150;
        algorithm = RadialTreeLayoutAlgorithm(config, null);
        graph.isTree = true;
        break;

      case 'circular':
        algorithm = CircleLayoutAlgorithm(CircleLayoutConfiguration(), null);
        graph.isTree = false;
        break;

      case 'directed':
      default:
        final config = SugiyamaConfiguration()
          ..nodeSeparation = 150
          ..levelSeparation = 150
          ..orientation = SugiyamaConfiguration.ORIENTATION_TOP_BOTTOM;
        algorithm = SugiyamaAlgorithm(config)..renderer = ArrowEdgeRenderer();
        graph.isTree = false;
        break;
    }

    setState(() {
      _isInitialized = true;
    });

    if (_isInitialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // Both jump to root and zoom to fit for the best starting view
          if (_rootNodeId != null) {
            controller.jumpToNode(ValueKey(_rootNodeId!));
          }
          controller.zoomToFit();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || graph.nodeCount() == 0) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);

    return Stack(
      children: [
        SizedBox.expand(
          child: InteractiveViewer(
            transformationController: _transformationController,
            constrained: false, // Essential for GraphView to layout freely
            boundaryMargin: const EdgeInsets.all(double.infinity),
            minScale: 0.4,
            maxScale: 3.0,
            // Near-zero friction effectively disables pan/zoom momentum
            interactionEndFrictionCoefficient: 0.0000000001,
            child: GraphView(
              graph: graph,
              algorithm: algorithm,
              controller: controller,
              centerGraph: true,
              paint: Paint()
                ..color = theme.colorScheme.outline.withValues(alpha: 0.5)
                ..strokeWidth = 1.5
                ..style = PaintingStyle.stroke,
              builder: (Node node) {
                final id = node.key?.value.toString();
                final nodeData = (widget.schema['nodes'] as List).firstWhere(
                  (n) => n['id'].toString() == id,
                  orElse: () => {'label': '?', 'type': 'normal'},
                );
                return IgnorePointer(
                  child: _buildNodeWidget(nodeData, theme),
                );
              },
            ),
          ),
        ),
        // Precise Controls
        Positioned(
          bottom: 24,
          right: 24,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: theme.colorScheme.surface.withValues(alpha: 0.9),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildControlButton(
                  icon: Icons.fullscreen_exit,
                  tooltip: 'Zoom to Fit',
                  onPressed: () => controller.zoomToFit(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        padding: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildNodeWidget(Map<String, dynamic> data, ThemeData theme) {
    final isImportant = data['type'] == 'important';
    final label = data['label'] ?? 'Node';
    
    return Tooltip(
      message: label,
      waitDuration: const Duration(milliseconds: 500),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: const BoxConstraints(maxWidth: 180),
        decoration: BoxDecoration(
          color: isImportant ? theme.colorScheme.primaryContainer : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isImportant ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
            width: isImportant ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isImportant ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurface,
            fontWeight: isImportant ? FontWeight.bold : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
