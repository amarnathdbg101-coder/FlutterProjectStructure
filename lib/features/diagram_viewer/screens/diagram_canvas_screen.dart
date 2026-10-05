import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/routes/app_router.dart';
import '../controllers/diagram_controller.dart';
import '../models/diagram_model.dart';
import '../widgets/mind_map_painter.dart';

class DiagramCanvasScreen extends StatefulWidget {
  final String? initialTopic;
  final String? noteId;

  const DiagramCanvasScreen({
    super.key,
    this.initialTopic,
    this.noteId,
  });

  @override
  State<DiagramCanvasScreen> createState() => _DiagramCanvasScreenState();
}

class _DiagramCanvasScreenState extends State<DiagramCanvasScreen> {
  final Size _canvasSize = const Size(1400, 1000);
  final TextEditingController _topicController = TextEditingController();
  bool _isOutlineView = false;

  final List<String> _suggestedTopics = const [
    'Computer Architecture',
    'Thermodynamics & Heat Transfer',
    'Organic Chemistry Mechanisms',
    'Cell Division & Genetics',
    'Quantum Mechanics',
    'Calculus & Integration',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = context.read<DiagramController>();
      final topic = widget.initialTopic ?? 'Thermodynamics & Heat Transfer';
      _topicController.text = topic;
      if (controller.diagram == null) {
        controller.generateDiagram(
          topic,
          noteId: widget.noteId,
          canvasSize: _canvasSize,
        );
      }
    });
  }

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  void _handleCanvasTap(TapUpDetails details, DiagramModel diagram) {
    final localPos = details.localPosition;
    final controller = context.read<DiagramController>();

    DiagramNodeModel? hitNode;
    for (final node in diagram.nodes) {
      final rect = Rect.fromLTWH(node.x, node.y, node.width, node.height);
      if (rect.contains(localPos)) {
        hitNode = node;
        break;
      }
    }

    controller.selectNode(hitNode);
    if (hitNode != null) {
      _showNodeDetailsSheet(hitNode);
    }
  }

  void _showNodeDetailsSheet(DiagramNodeModel node) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color nodeColor;
    try {
      nodeColor = Color(int.parse(node.colorHex.replaceFirst('#', '0xFF')));
    } catch (_) {
      nodeColor = AppColors.primary;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(color: nodeColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      node.label,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: nodeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      node.nodeType.toUpperCase(),
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: nodeColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (node.description.isNotEmpty) ...[
                Text(
                  node.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (node.formulas.isNotEmpty) ...[
                const Text(
                  'Associated Formulas:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.accent),
                ),
                const SizedBox(height: 6),
                for (final formula in node.formulas)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Math.tex(
                        formula,
                        textStyle: TextStyle(
                          fontSize: 16,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
              ],
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.psychology, size: 18),
                      label: const Text('Explain with AI Tutor'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        context.push(AppRoutes.aiChat, extra: {
                          'initialQuery': 'Deeply explain the concept: ${node.label}\n\nContext:\n${node.description}',
                          'noteTitle': node.label,
                        });
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNewDiagramDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Generate AI Mind Map'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _topicController,
                decoration: const InputDecoration(
                  labelText: 'Topic or Concept',
                  hintText: 'e.g. Organic Chemistry, Calculus, Cell Division',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 14),
              const Text(
                'High-Yield Topics:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _suggestedTopics.map((t) {
                  return ActionChip(
                    label: Text(t, style: const TextStyle(fontSize: 11)),
                    onPressed: () {
                      _topicController.text = t;
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final topic = _topicController.text.trim();
              if (topic.isNotEmpty) {
                Navigator.pop(ctx);
                context.read<DiagramController>().generateDiagram(
                  topic,
                  canvasSize: _canvasSize,
                );
              }
            },
            child: const Text('Generate'),
          ),
        ],
      ),
    );
  }

  Widget _buildOutlineView(DiagramModel diagram, bool isDark) {
    final root = diagram.nodes.firstWhere((n) => n.isRoot, orElse: () => diagram.nodes.first);
    final branches = diagram.nodes.where((n) => n.isBranch).toList();
    final leaves = diagram.nodes.where((n) => n.isLeaf).toList();

    // Map parent to children
    final Map<String, List<DiagramNodeModel>> childrenMap = {};
    for (final edge in diagram.edges) {
      final child = diagram.nodes.firstWhere(
        (n) => n.id == edge.toId,
        orElse: () => DiagramNodeModel(id: '', label: ''),
      );
      if (child.id.isNotEmpty && child.id != root.id) {
        childrenMap.putIfAbsent(edge.fromId, () => []).add(child);
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Root Hero Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.hub_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'CORE CONCEPT HUB',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                root.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (root.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  root.description,
                  style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.35),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        const Text(
          'CONCEPTUAL BRANCHES & SUB-DOMAINS',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 0.4),
        ),
        const SizedBox(height: 8),

        // Branch Cards
        for (final branch in branches.isNotEmpty ? branches : leaves) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: ExpansionTile(
              initiallyExpanded: true,
              leading: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Color(int.tryParse(branch.colorHex.replaceFirst('#', '0xFF')) ?? 0xFF0EA5E9),
                  shape: BoxShape.circle,
                ),
              ),
              title: Text(
                branch.label,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              subtitle: branch.description.isNotEmpty
                  ? Text(
                      branch.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    )
                  : null,
              children: [
                if (branch.formulas.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        children: branch.formulas.map((f) {
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Math.tex(
                              f,
                              textStyle: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.cyanAccent : const Color(0xFF0284C7),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],

                // Children of this branch
                for (final leaf in childrenMap[branch.id] ?? []) ...[
                  ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
                    leading: const Icon(Icons.arrow_right_rounded, color: AppColors.primary, size: 20),
                    title: Text(leaf.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                    subtitle: leaf.description.isNotEmpty
                        ? Text(leaf.description, style: TextStyle(fontSize: 11.5, color: isDark ? Colors.grey[400] : Colors.grey[600]))
                        : null,
                    trailing: leaf.formulas.isNotEmpty
                        ? const Icon(Icons.functions_rounded, size: 16, color: AppColors.accent)
                        : null,
                    onTap: () => _showNodeDetailsSheet(leaf),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DiagramController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final diagram = controller.diagram;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          diagram != null ? diagram.title : 'AI Mind Map & Concept Canvas',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: _isOutlineView ? 'Switch to Vector Canvas' : 'Switch to Concept Tree Outline',
            icon: Icon(_isOutlineView ? Icons.grain_rounded : Icons.list_alt_rounded),
            onPressed: () {
              setState(() {
                _isOutlineView = !_isOutlineView;
              });
            },
          ),
          IconButton(
            tooltip: 'New Mind Map Topic',
            icon: const Icon(Icons.add_chart_rounded),
            onPressed: _showNewDiagramDialog,
          ),
          if (!_isOutlineView)
            IconButton(
              tooltip: 'Reset Canvas Position',
              icon: const Icon(Icons.center_focus_strong_rounded),
              onPressed: () => controller.resetView(),
            ),
        ],
      ),
      floatingActionButton: (!_isOutlineView && diagram != null && !controller.isLoading)
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'zoom_in_fab',
                  tooltip: 'Zoom In',
                  onPressed: () => controller.zoomIn(),
                  child: const Icon(Icons.zoom_in),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'zoom_out_fab',
                  tooltip: 'Zoom Out',
                  onPressed: () => controller.zoomOut(),
                  child: const Icon(Icons.zoom_out),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'recenter_fab',
                  tooltip: 'Recenter',
                  onPressed: () => controller.resetView(),
                  child: const Icon(Icons.filter_center_focus),
                ),
              ],
            )
          : null,
      body: controller.isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Generating AI Mind Map for "${_topicController.text}"...',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Synthesizing conceptual hierarchy, branches, and vector layout',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            )
          : controller.errorMessage != null && diagram == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 56, color: AppColors.error),
                        const SizedBox(height: 12),
                        const Text(
                          'Could Not Load Mind Map',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          controller.errorMessage ?? 'Something went wrong while generating the mind map.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Try Again'),
                          onPressed: () {
                            controller.generateDiagram(
                              _topicController.text.trim().isNotEmpty
                                  ? _topicController.text.trim()
                                  : 'Thermodynamics & Heat Transfer',
                              canvasSize: _canvasSize,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                )
              : diagram == null
                  ? Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.account_tree_outlined, size: 64, color: AppColors.primary),
                            const SizedBox(height: 16),
                            const Text(
                              'No Mind Map Loaded',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Generate a high-yield concept tree with formulas and visual branches',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.auto_awesome),
                              label: const Text('Generate Mind Map'),
                              onPressed: _showNewDiagramDialog,
                            ),
                          ],
                        ),
                      ),
                    )
                  : _isOutlineView
                      ? _buildOutlineView(diagram, isDark)
                      : InteractiveViewer(
                          transformationController: controller.transformController,
                          constrained: false,
                          boundaryMargin: const EdgeInsets.all(800),
                          minScale: 0.3,
                          maxScale: 3.5,
                          child: GestureDetector(
                            onTapUp: (details) => _handleCanvasTap(details, diagram),
                            child: Container(
                              width: _canvasSize.width,
                              height: _canvasSize.height,
                              color: isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC),
                              child: CustomPaint(
                                size: _canvasSize,
                                painter: MindMapPainter(
                                  diagram: diagram,
                                  isDark: isDark,
                                  selectedNode: controller.selectedNode,
                                ),
                              ),
                            ),
                          ),
                        ),
    );
  }
}
