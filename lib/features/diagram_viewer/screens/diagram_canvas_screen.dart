import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/utils/latex_sanitizer.dart';
import '../controllers/diagram_controller.dart';
import '../models/diagram_model.dart';
import '../widgets/mind_map_minimap.dart';
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
  // Doubled canvas dimensions (2800 x 2000) to ensure zero cutoff even with deep multi-level sub-branches
  final Size _canvasSize = const Size(2800, 2000);
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  bool _isOutlineView = false;
  bool _isSearchOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = context.read<DiagramController>();
      controller.loadSavedMindMaps();
      // Only generate if an explicit initialTopic was passed from a specific note/screen
      if (widget.initialTopic != null && widget.initialTopic!.trim().isNotEmpty) {
        final topic = widget.initialTopic!.trim();
        _topicController.text = topic;
        if (controller.diagram == null || controller.diagram!.title.toLowerCase() != topic.toLowerCase()) {
          controller.generateDiagram(
            topic,
            noteId: widget.noteId,
            canvasSize: _canvasSize,
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _topicController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  final GlobalKey _repaintBoundaryKey = GlobalKey();
  bool _showMinimap = true;
  Offset? _lastDragPosition;

  void _handleCanvasTap(TapUpDetails details, DiagramModel diagram) {
    final localPos = details.localPosition;
    final controller = context.read<DiagramController>();

    DiagramNodeModel? hitNode;
    bool tappedFoldPill = false;
    for (final node in diagram.nodes.reversed) {
      if (!node.isVisible) continue;
      final rect = Rect.fromLTWH(node.x, node.y, node.width, node.height);
      if (rect.contains(localPos)) {
        hitNode = node;
        if (controller.canWrapOrUnwrap(node)) {
          // Generous touch target (28x28) around the right-edge fold indicator pill
          final pillRect = Rect.fromCenter(
            center: Offset(node.x + node.width - 8, node.y + node.height / 2),
            width: 28,
            height: 28,
          );
          if (pillRect.contains(localPos)) {
            tappedFoldPill = true;
          }
        }
        break;
      }
    }

    if (tappedFoldPill && hitNode != null) {
      HapticFeedback.mediumImpact();
      controller.toggleCollapse(hitNode.id, canvasSize: _canvasSize);
      return;
    }

    controller.selectNode(hitNode);
    if (hitNode != null) {
      if (controller.isActiveRecallMode && !hitNode.isRoot) {
        controller.revealNode(hitNode.id);
      }
      HapticFeedback.selectionClick();
      _showNodeDetailsSheet(hitNode);
    }
  }

  void _handleLongPressStart(LongPressStartDetails details, DiagramModel diagram) {
    final localPos = details.localPosition;
    final controller = context.read<DiagramController>();

    DiagramNodeModel? hitNode;
    for (final node in diagram.nodes.reversed) {
      if (!node.isVisible) continue;
      final rect = Rect.fromLTWH(node.x, node.y, node.width, node.height);
      if (rect.contains(localPos)) {
        hitNode = node;
        break;
      }
    }

    if (hitNode != null) {
      HapticFeedback.heavyImpact();
      _lastDragPosition = localPos;
      controller.startDraggingNode(hitNode);
    }
  }

  void _handleLongPressMoveUpdate(LongPressMoveUpdateDetails details, DiagramModel diagram) {
    final controller = context.read<DiagramController>();
    final dragged = controller.draggedNode;
    if (dragged == null || _lastDragPosition == null) return;

    final currentPos = details.localPosition;
    final delta = currentPos - _lastDragPosition!;
    _lastDragPosition = currentPos;

    controller.moveNode(dragged.id, delta, moveSubtree: true);
  }

  void _handleLongPressEnd(LongPressEndDetails details) {
    final controller = context.read<DiagramController>();
    if (controller.draggedNode != null) {
      HapticFeedback.lightImpact();
      controller.stopDraggingNode();
      _lastDragPosition = null;
    }
  }

  void _handleDoubleTapDown(TapDownDetails details, DiagramModel diagram, Size viewportSize) {
    final localPos = details.localPosition;
    final controller = context.read<DiagramController>();

    DiagramNodeModel? hitNode;
    for (final node in diagram.nodes.reversed) {
      if (!node.isVisible) continue;
      final rect = Rect.fromLTWH(node.x, node.y, node.width, node.height);
      if (rect.contains(localPos)) {
        hitNode = node;
        break;
      }
    }

    HapticFeedback.mediumImpact();
    if (hitNode != null) {
      controller.focusNode(hitNode, viewportSize, zoomLevel: 1.25);
    } else {
      controller.resetView();
    }
  }

  Future<void> _exportMindMapImage() async {
    try {
      final boundary = _repaintBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final controller = context.read<DiagramController>();

      // 1-Tap HD PNG Poster Export: pixelRatio 2.5 for crystal-clear wall-poster print quality
      final image = await boundary.toImage(pixelRatio: 2.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final pngBytes = byteData.buffer.asUint8List();
      final docsDir = await getApplicationDocumentsDirectory();
      final safeTitle = (controller.diagram?.title ?? 'mindmap')
          .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final fileName = 'StudySilo_HD_Poster_${safeTitle}_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${docsDir.path}/$fileName');
      await file.writeAsBytes(pngBytes);

      // Efficiently sync mind map state to PostgreSQL database
      if (controller.diagram != null) {
        await controller.saveCurrentMindMap();
      }

      if (!mounted) return;
      HapticFeedback.selectionClick();
      _showExportSuccessDialog(file.path, pngBytes, isSyncedToDb: controller.diagram?.id != null);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export HD PNG poster: $e')),
      );
    }
  }

  void _showExportSuccessDialog(String filePath, Uint8List imageBytes, {bool isSyncedToDb = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 24),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('1-Tap HD PNG Poster', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  Text('Exported @ pixelRatio: 2.5', style: TextStyle(fontSize: 11.5, color: Color(0xFF10B981), fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('📐 Ultra-HD 2.5x Resolution', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                ),
                const SizedBox(width: 6),
                if (isSyncedToDb)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('💾 PostgreSQL Synced', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 180),
                decoration: BoxDecoration(
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Image.memory(imageBytes, fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Saved to device storage for easy printing & sharing:',
              style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                filePath,
                style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppColors.primary),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _generateQuizFromMap(DiagramController controller) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('⚡ Compiling 4D Mind Map into Active Recall Quiz...')),
    );
    final quiz = await controller.generateQuizFromMindMap(numQuestions: 5);
    if (quiz != null && mounted) {
      final quizId = quiz['id']?.toString();
      if (quizId != null && quizId.isNotEmpty && !quizId.startsWith('quiz_')) {
        context.push(AppRoutes.quizTake, extra: quizId);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚡ Active Recall Quiz generated with ${quiz['questions']?.length ?? 5} questions!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to generate quiz. Please check network connection.'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _generateFlashcardsFromMap(DiagramController controller) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('🃏 Generating 3D Flip Flashcards from Mind Map...')),
    );
    final deck = await controller.generateFlashcardsFromMindMap(cardCount: 6);
    if (deck != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deck "${deck['title']}" created with ${deck['total_cards'] ?? 6} active recall cards!'),
          backgroundColor: AppColors.success,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to generate flashcards.'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _exportMindMapPDFPoster(DiagramController controller) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('🖨️ Compiling High-Res Printable Wall Poster PDF...')),
    );
    final pdfBytes = await controller.exportMindMapPDF(paperSize: 'A4');
    if (pdfBytes != null && pdfBytes.isNotEmpty && mounted) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/StudySilo_MindMap_${DateTime.now().millisecondsSinceEpoch}.pdf');
        await file.writeAsBytes(pdfBytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Printable Poster PDF exported (${(pdfBytes.length / 1024).toStringAsFixed(1)} KB)!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('PDF compiled (${pdfBytes.length} bytes)!'), backgroundColor: AppColors.success),
          );
        }
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to export PDF poster.'), backgroundColor: AppColors.error),
      );
    }
  }

  void _confirmDeleteNode(DiagramNodeModel node) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controller = context.read<DiagramController>();
    final childCount = controller.diagram?.edges.where((e) => e.fromId == node.id && !e.isCrossLink).length ?? 0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Delete Topic Card?',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kya aap "${node.label}" ${childCount > 0 ? "aur iske saare ($childCount) sub-topics" : ""} ko delete karna chahte hain?',
              style: TextStyle(
                fontSize: 13.5,
                height: 1.45,
                color: isDark ? Colors.grey[200] : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.storage_rounded, size: 18, color: Color(0xFF10B981)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Unwanted branches delete hone se unnecessary database storage reduce hogi aur canvas clean rahega.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.delete_forever_rounded, size: 18),
            label: const Text('Delete & Save Storage'),
            onPressed: () async {
              Navigator.pop(ctx); // Close dialog
              if (mounted && Navigator.canPop(context)) {
                Navigator.pop(context); // Close bottom sheet
              }
              final success = await controller.deleteNode(node.id, canvasSize: _canvasSize);
              if (mounted && success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF10B981),
                    content: Text('"${node.label}" delete ho gaya & database storage update ho gayi!'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _showNodeDetailsSheet(DiagramNodeModel node) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controller = context.read<DiagramController>();

    Color nodeColor;
    try {
      nodeColor = Color(int.parse(node.colorHex.replaceFirst('#', '0xFF')));
    } catch (_) {
      nodeColor = AppColors.primary;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.88,
        expand: false,
        builder: (_, scrollController) => SafeArea(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Header: Title & Badges
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(color: nodeColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          LatexSanitizer.clean(node.label),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              '★' * node.importance + '☆' * (5 - node.importance),
                              style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 13),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              node.importance >= 4 ? 'High Yield' : 'Standard Yield',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: node.importance >= 4 ? const Color(0xFF10B981) : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (node.badge.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: nodeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        node.badge.toUpperCase(),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: nodeColor),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  if (!node.isRoot)
                    IconButton(
                      iconSize: 20,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      tooltip: 'Delete Card & Free Storage',
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                      onPressed: () => _confirmDeleteNode(node),
                    ),
                ],
              ),
              const SizedBox(height: 14),

              // Description / AI Explanation (Point-by-Point, enjoyable, zero boring paragraphs)
              if (node.description.isNotEmpty) ...[
                _buildPointByPointContent(node.description, nodeColor, isDark),
                const SizedBox(height: 14),
              ],

              // Optional LaTeX formulas (clean, simple display only if mathematically relevant)
              if (node.formulas.isNotEmpty) ...[
                for (final formula in node.formulas)
                  if (formula.trim().isNotEmpty)
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Math.tex(
                          formula,
                          textStyle: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                const SizedBox(height: 12),
              ],

              // --- SMART PROFESSIONAL ACTION BAR ---
              Container(
                padding: const EdgeInsets.only(top: 14),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // 1. Expand Sub-Branch Button (Clean, modern secondary pill)
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: BorderSide(
                            color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                          ),
                          backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        ),
                        icon: controller.isExpandingNode
                            ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.account_tree_outlined, size: 16, color: Color(0xFF6366F1)),
                        label: Text(
                          controller.isExpandingNode ? 'Expanding...' : 'Expand Branch',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onPressed: controller.isExpandingNode
                            ? null
                            : () {
                                Navigator.pop(ctx);
                                _handleNodeExpansion(node);
                              },
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 2. AI Deep Dive Button (Sleek, high-contrast indigo primary)
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.auto_awesome_rounded, size: 16, color: Colors.white),
                        label: const Text(
                          'AI Deep Dive',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          final promptBuilder = StringBuffer()
                            ..writeln('Please provide a crisp, point-by-point tutorial on: "${node.label}"')
                            ..writeln()
                            ..writeln('Context: ${node.description}');
                          if (node.metrics.isNotEmpty) {
                            promptBuilder.writeln('Metrics: ${node.metrics.entries.map((e) => "${e.key}: ${e.value}").join(", ")}');
                          }
                          if (node.codeSnippet.isNotEmpty) {
                            promptBuilder.writeln('Code / Logic:\n${node.codeSnippet}');
                          }
                          if (node.keyTakeaway.isNotEmpty) {
                            promptBuilder.writeln('Key Principle: ${node.keyTakeaway}');
                          }
                          if (node.examTrap.isNotEmpty) {
                            promptBuilder.writeln('Exam Trap: ${node.examTrap}');
                          }
                          if (node.vivaInsight.isNotEmpty) {
                            promptBuilder.writeln('Viva / Oral Drill: ${node.vivaInsight}');
                          }
                          if (node.crossSubject.isNotEmpty) {
                            promptBuilder.writeln('Cross-Subject: ${node.crossSubject}');
                          }
                          if (node.formulas.isNotEmpty) {
                            promptBuilder.writeln('Formulas: ${node.formulas.join(', ')}');
                          }

                          context.push(AppRoutes.aiChat, extra: {
                            'initialQuery': promptBuilder.toString(),
                            'noteTitle': node.label,
                          });
                        },
                      ),
                    ),
                    if (controller.canWrapOrUnwrap(node)) ...[
                      const SizedBox(width: 8),
                      // Universal Wrap / Unwrap (Fold / Unfold) Button
                      IconButton(
                        tooltip: node.isCollapsed ? 'Unwrap Card (Show Sub-Topics)' : 'Wrap Card (Clean Canvas Space)',
                        style: IconButton.styleFrom(
                          backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.all(11),
                        ),
                        icon: Icon(
                          node.isCollapsed ? Icons.unfold_more_rounded : Icons.unfold_less_rounded,
                          size: 19,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                        onPressed: () {
                          controller.toggleCollapse(node.id, canvasSize: _canvasSize);
                          Navigator.pop(ctx);
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPointByPointContent(String rawText, Color accentColor, bool isDark) {
    if (rawText.trim().isEmpty) return const SizedBox.shrink();

    // Cleanly extract points (support \n, bullet •, emojis, numbers, or sentences)
    List<String> points = [];

    if (rawText.contains('\n')) {
      points = rawText
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    } else if (rawText.contains('•')) {
      points = rawText
          .split('•')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    } else {
      // Split on emojis or sentence ends
      final regex = RegExp(r'(💡|⚙️|📌|🎯|⚠️|✅|❌)');
      final matches = regex.allMatches(rawText).toList();
      if (matches.length > 1) {
        int lastIndex = 0;
        for (int i = 0; i < matches.length; i++) {
          final start = matches[i].start;
          if (start > lastIndex && i > 0) {
            final part = rawText.substring(lastIndex, start).trim();
            if (part.isNotEmpty) points.add(part);
          }
          lastIndex = start;
        }
        if (lastIndex < rawText.length) {
          final part = rawText.substring(lastIndex).trim();
          if (part.isNotEmpty) points.add(part);
        }
      } else {
        final sentences = rawText
            .split(RegExp(r'\. (?=[A-Z0-9])'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        if (sentences.length > 1) {
          points = sentences;
        } else {
          points = [rawText.trim()];
        }
      }
    }

    if (points.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.6) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1.1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < points.length; i++) ...[
            Builder(
              builder: (_) {
                var cleanText = points[i].replaceAll(RegExp(r'^[•\-\*]\s*'), '').trim();
                cleanText = cleanText.replaceAll(
                  RegExp(r'^(Core Idea|Key Rule|How It Works|How it Operates|Mechanism|High-Yield Takeaway|Exam Takeaway|Key Takeaway|Takeaway):\s*', caseSensitive: false),
                  '',
                );
                cleanText = LatexSanitizer.clean(cleanText);
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 7, right: 10),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: accentColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        cleanText,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.5,
                          fontWeight: FontWeight.w400,
                          color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            if (i < points.length - 1)
              const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Future<void> _handleNodeExpansion(DiagramNodeModel node, {bool force = false}) async {
    final controller = context.read<DiagramController>();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(force
            ? '⚡ Forcing microscopic deep-dive expansion for "${node.label}"...'
            : 'Analyzing depth & expanding "${node.label}" with AI...'),
        duration: const Duration(seconds: 2),
      ),
    );

    final result = await controller.expandNode(node, canvasSize: _canvasSize, force: force);
    if (!mounted) return;

    if (result.isSaturated && !force) {
      _showSaturationAdvisoryDialog(node, result.saturationReason ?? 'Yeh topic already atomic depth par hai.');
    } else if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF10B981),
          content: Text('"${node.label}" successfully expanded & saved to database!'),
        ),
      );
    } else if (result.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text(result.errorMessage!),
        ),
      );
    }
  }

  void _showSaturationAdvisoryDialog(DiagramNodeModel node, String reason) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.psychology_outlined, color: Color(0xFFF59E0B), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'AI PEDAGOGICAL ADVISORY',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFF59E0B),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Atomic Depth Reached',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: Color(0xFF6366F1)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          node.label,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    reason,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: isDark ? Colors.grey[300] : Colors.grey[800],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'StudySilo AI Recommendation: Stop here for maximum active recall efficiency without confusion.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Agar aap phir bhi microscopic internal mechanics dekhna chahte hain, toh Force Expand kar sakte hain.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Samajh Gaya (Recommended)'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.bolt, size: 16),
            label: const Text('Phir Bhi Expand Karein'),
            onPressed: () {
              Navigator.pop(ctx);
              _handleNodeExpansion(node, force: true);
            },
          ),
        ],
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
                  labelText: 'Topic or Academic Concept',
                  hintText: 'Enter concept or topic to map...',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
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

  void _confirmRegenerateMindMap(DiagramController controller) {
    if (controller.diagram == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Regenerate Mind Map?'),
        content: const Text(
          'This will reset your current canvas layout, zoom, and any expanded sub-branches. Are you sure you want to proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              HapticFeedback.mediumImpact();
              controller.refreshDiagram(canvasSize: _canvasSize);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('⚡ Mind Map regenerated!'),
                  duration: Duration(milliseconds: 1200),
                ),
              );
            },
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );
  }

  void _showSaveMindMapDialog() {
    final controller = context.read<DiagramController>();
    if (controller.diagram == null) return;

    final titleController = TextEditingController(text: controller.diagram!.title);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save Mind Map to Cloud'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Save this concept canvas so you can review or expand it anytime from any device.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Mind Map Title',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.cloud_upload_rounded, size: 18),
            label: const Text('Save'),
            onPressed: () async {
              final newTitle = titleController.text.trim();
              Navigator.pop(ctx);
              final success = await controller.saveCurrentMindMap(customTitle: newTitle);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Mind Map "$newTitle" saved successfully!'
                          : (controller.errorMessage ?? 'Failed to save mind map'),
                    ),
                    backgroundColor: success ? AppColors.success : AppColors.error,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _showSavedMindMapsSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controller = context.read<DiagramController>();
    controller.loadSavedMindMaps();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Consumer<DiagramController>(
        builder: (context, ctrl, _) {
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.collections_bookmark_rounded, color: AppColors.primary, size: 24),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Saved Mind Maps Library',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded),
                        tooltip: 'Refresh List',
                        onPressed: () => ctrl.loadSavedMindMaps(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ctrl.isLoadingSaved
                      ? const Center(child: CircularProgressIndicator())
                      : ctrl.savedMindMaps.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey[400]),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'No saved mind maps yet',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Generate any concept map and click Save to store it here.',
                                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: ctrl.savedMindMaps.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final item = ctrl.savedMindMaps[index];
                                return _buildSavedMapCard(item, isDark, ctrl, inSheet: true);
                              },
                            ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSavedMapCard(
    SavedMindMapSummaryModel item,
    bool isDark,
    DiagramController ctrl, {
    bool inSheet = false,
  }) {
    return Material(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: item.isPinned
                ? AppColors.primary.withValues(alpha: 0.6)
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: item.isPinned ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: (item.isPinned ? AppColors.primary : Colors.indigo).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              item.isPinned ? Icons.push_pin : Icons.hub_rounded,
              color: item.isPinned ? AppColors.primary : Colors.indigo,
              size: 19,
            ),
          ),
          title: Text(
            item.title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  item.domainType.toUpperCase(),
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blue),
                ),
              ),
              Text(
                '${item.updatedAt.day}/${item.updatedAt.month}/${item.updatedAt.year}',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                icon: Icon(
                  item.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                  size: 18,
                  color: item.isPinned ? AppColors.primary : Colors.grey,
                ),
                tooltip: item.isPinned ? 'Unpin' : 'Pin to top',
                onPressed: () => ctrl.togglePinSavedMindMap(item.id),
              ),
              const SizedBox(width: 6),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                tooltip: 'Delete Mind Map',
                onPressed: () => _confirmDeleteSavedMap(item, ctrl),
              ),
            ],
          ),
          onTap: () {
            if (inSheet) {
              Navigator.pop(context);
            }
            ctrl.loadMindMapById(item.id, canvasSize: _canvasSize);
          },
        ),
      ),
    );
  }

  void _confirmDeleteSavedMap(SavedMindMapSummaryModel item, DiagramController ctrl) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Mind Map?'),
        content: Text('Are you sure you want to permanently delete "${item.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await ctrl.deleteSavedMindMap(item.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Mind Map deleted' : 'Failed to delete mind map'),
                    backgroundColor: success ? AppColors.success : AppColors.error,
                  ),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildOutlineView(DiagramModel diagram, bool isDark) {
    final root = diagram.nodes.firstWhere((n) => n.isRoot, orElse: () => diagram.nodes.first);
    final branches = diagram.nodes.where((n) => n.isBranch).toList();

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
        for (final branch in branches) ...[
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
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      branch.label,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                  if (branch.badge.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        branch.badge,
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                    ),
                ],
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                    leading: const Icon(Icons.arrow_right_rounded, color: AppColors.primary, size: 20),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(leaf.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                        ),
                        if (leaf.examTrap.isNotEmpty)
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFF59E0B)),
                          ),
                        if (leaf.formulas.isNotEmpty)
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(Icons.functions_rounded, size: 14, color: Color(0xFF06B6D4)),
                          ),
                      ],
                    ),
                    subtitle: leaf.description.isNotEmpty
                        ? Text(
                            leaf.description,
                            style: TextStyle(fontSize: 11.5, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          )
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
      backgroundColor: AppColors.getBackground(isDark),
      appBar: _isSearchOpen
          ? AppBar(
              backgroundColor: AppColors.getSurface(isDark),
              elevation: 0,
              shape: Border(
                bottom: BorderSide(color: AppColors.getBorder(isDark), width: 1),
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back to Canvas',
                onPressed: () {
                  setState(() {
                    _isSearchOpen = false;
                    _searchController.clear();
                    controller.setSearchQuery('');
                  });
                },
              ),
              title: TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(fontSize: 15, color: AppColors.getTextPrimary(isDark)),
                decoration: InputDecoration(
                  hintText: 'Search concepts, laws, traps...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: AppColors.getTextSecondary(isDark)),
                ),
                onChanged: (val) => controller.setSearchQuery(val),
              ),
              actions: [
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    tooltip: 'Clear query',
                    onPressed: () {
                      _searchController.clear();
                      controller.setSearchQuery('');
                    },
                  ),
              ],
            )
          : AppBar(
              backgroundColor: AppColors.getSurface(isDark),
              elevation: 0,
              shape: Border(
                bottom: BorderSide(color: AppColors.getBorder(isDark), width: 1),
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Back',
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(AppRoutes.dashboard);
                  }
                },
              ),
              title: Text(
                diagram != null ? diagram.title : 'Concept Mind Maps',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16.5,
                  color: AppColors.getTextPrimary(isDark),
                  letterSpacing: -0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              actions: [
                // ➕ Create New Mind Map (Direct 1-Tap Access in AppBar)
                IconButton(
                  tooltip: 'Create New Mind Map',
                  icon: const Icon(Icons.add_chart_rounded, color: AppColors.primary),
                  onPressed: _showNewDiagramDialog,
                ),

                // 💾 Save / Update Mind Map in Database
                if (diagram != null)
                  IconButton(
                    tooltip: controller.isSaving
                        ? 'Saving...'
                        : (diagram.id != null ? 'Update in Database' : 'Save Mind Map'),
                    icon: controller.isSaving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(diagram.id != null ? Icons.bookmark_added_rounded : Icons.bookmark_add_outlined),
                    onPressed: controller.isSaving ? null : _showSaveMindMapDialog,
                  ),
                // 📁 Saved Maps Library
                IconButton(
                  tooltip: 'Saved Maps Library',
                  icon: const Icon(Icons.collections_bookmark_rounded),
                  onPressed: _showSavedMindMapsSheet,
                ),
                // 🔍 Search Concepts
                IconButton(
                  tooltip: 'Search Concepts',
                  icon: const Icon(Icons.search_rounded),
                  onPressed: () {
                    setState(() {
                      _isSearchOpen = true;
                    });
                  },
                ),
                // ⋮ More Tools & Actions
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded),
                  tooltip: 'More Actions',
                  onSelected: (val) {
                    switch (val) {
                      case 'toggle_view':
                        setState(() => _isOutlineView = !_isOutlineView);
                        break;
                      case 'collapse_all':
                        controller.toggleCollapseAll(canvasSize: _canvasSize);
                        break;
                      case 'recenter':
                        controller.resetView();
                        break;
                      case 'generate_quiz':
                        _generateQuizFromMap(controller);
                        break;
                      case 'generate_flashcards':
                        _generateFlashcardsFromMap(controller);
                        break;
                      case 'export_pdf':
                        _exportMindMapPDFPoster(controller);
                        break;
                      case 'export_png':
                        _exportMindMapImage();
                        break;
                      case 'new_map':
                        _showNewDiagramDialog();
                        break;
                      case 'regenerate':
                        _confirmRegenerateMindMap(controller);
                        break;
                      case 'close':
                        controller.clearDiagram();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'new_map',
                      child: Row(
                        children: [
                          Icon(Icons.add_chart_rounded, size: 20, color: AppColors.primary),
                          SizedBox(width: 10),
                          Text('New Mind Map'),
                        ],
                      ),
                    ),
                    if (diagram != null)
                      const PopupMenuItem(
                        value: 'regenerate',
                        child: Row(
                          children: [
                            Icon(Icons.refresh_rounded, size: 20, color: Color(0xFFEF4444)),
                            SizedBox(width: 10),
                            Text('Regenerate Map...'),
                          ],
                        ),
                      ),
                    if (diagram != null) ...[
                      const PopupMenuItem(
                        value: 'generate_quiz',
                        child: Row(
                          children: [
                            Icon(Icons.bolt_rounded, size: 20, color: Color(0xFFF59E0B)),
                            SizedBox(width: 10),
                            Text('⚡ Test Me on This Map (Quiz)'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'generate_flashcards',
                        child: Row(
                          children: [
                            Icon(Icons.flip_to_back_rounded, size: 20, color: Color(0xFF6366F1)),
                            SizedBox(width: 10),
                            Text('🃏 3D Flip Flashcards'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'export_pdf',
                        child: Row(
                          children: [
                            Icon(Icons.picture_as_pdf_rounded, size: 20, color: Color(0xFFEC4899)),
                            SizedBox(width: 10),
                            Text('🖨️ Printable Wall Poster (PDF)'),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'toggle_view',
                        child: Row(
                          children: [
                            Icon(_isOutlineView ? Icons.grain_rounded : Icons.list_alt_rounded, size: 20),
                            SizedBox(width: 10),
                            Text(_isOutlineView ? 'Vector Canvas View' : 'Outline Tree View'),
                          ],
                        ),
                      ),
                      if (!_isOutlineView) ...[
                        const PopupMenuItem(
                          value: 'collapse_all',
                          child: Row(
                            children: [
                              Icon(Icons.account_tree_outlined, size: 20),
                              SizedBox(width: 10),
                              Text('Fold / Unfold All'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'recenter',
                          child: Row(
                            children: [
                              Icon(Icons.center_focus_strong_rounded, size: 20),
                              SizedBox(width: 10),
                              Text('Recenter View'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'export_png',
                          child: Row(
                            children: [
                              Icon(Icons.photo_camera_back_outlined, size: 20, color: AppColors.primary),
                              SizedBox(width: 10),
                              Text('📸 1-Tap HD PNG Poster (2.5x)'),
                            ],
                          ),
                        ),
                      ],
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'close',
                        child: Row(
                          children: [
                            Icon(Icons.close_rounded, size: 20, color: Colors.redAccent),
                            SizedBox(width: 10),
                            Text('Close Canvas'),
                          ],
                        ),
                      ),
                    ],
                  ],
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
                  tooltip: 'Recenter Canvas',
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
                    'Synthesizing conceptual hierarchy, key takeaways, and academic traps',
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
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.account_tree_rounded, size: 52, color: AppColors.primary),
                              ),
                              const SizedBox(height: 18),
                              const Text(
                                'Concept Mind Maps',
                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Visualize concepts, branches, and formulas interactively.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
                              ),
                              const SizedBox(height: 24),

                              // Topic Input Card
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextField(
                                      controller: _topicController,
                                      decoration: InputDecoration(
                                        hintText: 'Enter concept or academic topic...',
                                        prefixIcon: const Icon(Icons.psychology_rounded, color: AppColors.primary),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                      ),
                                      onSubmitted: (val) {
                                        final topic = val.trim();
                                        if (topic.isNotEmpty) {
                                          controller.generateDiagram(topic, canvasSize: _canvasSize);
                                        }
                                      },
                                    ),
                                    const SizedBox(height: 14),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        icon: const Icon(Icons.auto_awesome, size: 20),
                                        label: const Text('Generate Mind Map', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                        onPressed: () {
                                          final topic = _topicController.text.trim();
                                          if (topic.isNotEmpty) {
                                            controller.generateDiagram(topic, canvasSize: _canvasSize);
                                          } else {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Please enter a concept or topic first')),
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 22),

                              if (controller.savedMindMaps.isNotEmpty) ...[
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'YOUR SAVED MIND MAPS:',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textSecondary,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _showSavedMindMapsSheet,
                                      child: const Text('View All', style: TextStyle(fontSize: 12)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                for (final savedItem in controller.savedMindMaps.take(3)) ...[
                                  _buildSavedMapCard(savedItem, isDark, controller),
                                  const SizedBox(height: 8),
                                ],
                                const SizedBox(height: 16),
                              ],
                            ],
                          ),
                        ),
                      ),
                    )
                  : _isOutlineView
                      ? _buildOutlineView(diagram, isDark)
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final viewportSize = Size(constraints.maxWidth, constraints.maxHeight);
                            return Stack(
                              children: [
                                InteractiveViewer(
                                  transformationController: controller.transformController,
                                  constrained: false,
                                  panEnabled: controller.draggedNode == null,
                                  boundaryMargin: const EdgeInsets.all(1200),
                                  minScale: 0.15,
                                  maxScale: 3.5,
                                  child: GestureDetector(
                                    onTapUp: (details) => _handleCanvasTap(details, diagram),
                                    onDoubleTapDown: (details) => _handleDoubleTapDown(details, diagram, viewportSize),
                                    onLongPressStart: (details) => _handleLongPressStart(details, diagram),
                                    onLongPressMoveUpdate: (details) => _handleLongPressMoveUpdate(details, diagram),
                                    onLongPressEnd: _handleLongPressEnd,
                                    child: RepaintBoundary(
                                      key: _repaintBoundaryKey,
                                      child: Container(
                                        width: _canvasSize.width,
                                        height: _canvasSize.height,
                                        color: isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC),
                                        child: CustomPaint(
                                          key: ValueKey('mindmap_canvas_${controller.version}'),
                                          size: _canvasSize,
                                          painter: MindMapPainter(
                                            diagram: diagram,
                                            isDark: isDark,
                                            selectedNode: controller.selectedNode,
                                            draggedNode: controller.draggedNode,
                                            searchQuery: controller.searchQuery,
                                            repaintVersion: controller.version,
                                            isActiveRecallMode: controller.isActiveRecallMode,
                                            revealedNodeIds: controller.revealedNodeIds,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                // Top Floating Canvas Toolbar
                                Positioned(
                                  top: 14,
                                  left: 16,
                                  right: 16,
                                  child: Center(
                                    child: _buildCanvasFloatingToolbar(isDark, controller),
                                  ),
                                ),

                                // Bottom Right Minimap Navigator
                                if (_showMinimap)
                                  Positioned(
                                    bottom: 16,
                                    right: 76,
                                    child: MindMapMinimap(
                                      diagram: diagram,
                                      transformController: controller.transformController,
                                      canvasSize: _canvasSize,
                                      viewportSize: viewportSize,
                                      isDark: isDark,
                                      onToggleCollapse: () {
                                        setState(() => _showMinimap = false);
                                      },
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
    );
  }

  Widget _buildCanvasFloatingToolbar(bool isDark, DiagramController controller) {
    final currentStyle = controller.layoutStyle;
    final layoutLabel = currentStyle.label;
    final layoutIcon = currentStyle.icon;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E293B).withValues(alpha: 0.94)
            : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 6 Domain Archetypes & Layout Selector Menu
          PopupMenuButton<MindMapLayoutStyle>(
            tooltip: '6 Domain Archetypes & Layout',
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            initialValue: controller.layoutStyle,
            onSelected: (style) {
              HapticFeedback.selectionClick();
              controller.changeLayoutStyle(style, canvasSize: _canvasSize);
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: MindMapLayoutStyle.flow,
                child: Row(
                  children: [
                    Icon(Icons.alt_route_rounded, size: 18, color: Color(0xFF6366F1)),
                    SizedBox(width: 10),
                    Text('➔ Flow Pipeline (Algorithms & Steps)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: MindMapLayoutStyle.cycle,
                child: Row(
                  children: [
                    Icon(Icons.sync_rounded, size: 18, color: Color(0xFF0EA5E9)),
                    SizedBox(width: 10),
                    Text('⟳ Closed Cycle (Orbit Loop)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: MindMapLayoutStyle.comparison,
                child: Row(
                  children: [
                    Icon(Icons.compare_arrows_rounded, size: 18, color: Color(0xFFEC4899)),
                    SizedBox(width: 10),
                    Text('⚔️ Versus Matrix (Side-by-Side)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: MindMapLayoutStyle.stack,
                child: Row(
                  children: [
                    Icon(Icons.layers_rounded, size: 18, color: Color(0xFF8B5CF6)),
                    SizedBox(width: 10),
                    Text('📚 Layered Stack (Pyramid Tiers)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: MindMapLayoutStyle.tree,
                child: Row(
                  children: [
                    Icon(Icons.account_tree_rounded, size: 18, color: Color(0xFF10B981)),
                    SizedBox(width: 10),
                    Text('🌳 Taxonomy Tree (Classification)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: MindMapLayoutStyle.hub,
                child: Row(
                  children: [
                    Icon(Icons.hub_rounded, size: 18, color: Color(0xFFF59E0B)),
                    SizedBox(width: 10),
                    Text('🧠 Concept Hub (360° Radial Map)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(layoutIcon, size: 15, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    layoutLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, size: 16, color: AppColors.primary),
                ],
              ),
            ),
          ),

          // Auto-Tidy / Reset Layout button (shown when nodes have been dragged)
          if (controller.isCustomPositions) ...[
            const SizedBox(width: 6),
            InkWell(
              onTap: () {
                HapticFeedback.mediumImpact();
                controller.resetToAutoLayout(canvasSize: _canvasSize);
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_fix_high_rounded, size: 14, color: Color(0xFFF59E0B)),
                    SizedBox(width: 4),
                    Text(
                      'Tidy Layout',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFF59E0B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(width: 4),
          const SizedBox(
            height: 18,
            child: VerticalDivider(width: 12, thickness: 1),
          ),

          // Minimap Toggle
          IconButton(
            iconSize: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            tooltip: _showMinimap ? 'Hide Navigator' : 'Show Navigator',
            icon: Icon(
              _showMinimap ? Icons.map_rounded : Icons.map_outlined,
              color: _showMinimap ? AppColors.primary : AppColors.textSecondary,
            ),
            onPressed: () {
              HapticFeedback.selectionClick();
              setState(() => _showMinimap = !_showMinimap);
            },
          ),

          // Live Refresh Button
          IconButton(
            iconSize: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            tooltip: 'Live Refresh Layout',
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: () {
              HapticFeedback.selectionClick();
              controller.refreshDiagram(canvasSize: _canvasSize);
            },
          ),

          // Active Recall Mode Toggle
          const SizedBox(width: 6),
          InkWell(
            onTap: () {
              HapticFeedback.mediumImpact();
              controller.toggleActiveRecallMode();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: controller.isActiveRecallMode ? const Color(0xFF6366F1) : const Color(0xFF475569),
                  duration: const Duration(seconds: 2),
                  content: Text(
                    controller.isActiveRecallMode
                        ? '🧠 Active Recall Mode ON! Tap cards to test your memory.'
                        : 'Active Recall Mode OFF.',
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: controller.isActiveRecallMode
                    ? const Color(0xFF6366F1).withValues(alpha: 0.18)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: controller.isActiveRecallMode
                      ? const Color(0xFF6366F1)
                      : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                  width: 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.psychology_rounded,
                    size: 15,
                    color: controller.isActiveRecallMode
                        ? const Color(0xFF6366F1)
                        : (isDark ? Colors.white70 : AppColors.textSecondary),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    controller.isActiveRecallMode
                        ? 'Recall: ${controller.revealedCount}/${controller.totalTestableNodes}'
                        : 'Active Recall',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: controller.isActiveRecallMode
                          ? const Color(0xFF6366F1)
                          : (isDark ? Colors.white70 : AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 1-Tap Mind Map to Practice Quiz
          IconButton(
            iconSize: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            tooltip: 'Practice Quiz from Mind Map',
            icon: const Icon(Icons.quiz_rounded, color: Color(0xFF10B981)),
            onPressed: () => _handleGenerateQuizFromMindMap(controller),
          ),

          // 1-Tap HD PNG Poster Export (pixelRatio: 2.5)
          IconButton(
            iconSize: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            tooltip: '1-Tap HD PNG Poster (pixelRatio: 2.5)',
            icon: const Icon(Icons.camera_alt_outlined, color: AppColors.textSecondary),
            onPressed: _exportMindMapImage,
          ),
        ],
      ),
    );
  }

  Future<void> _handleGenerateQuizFromMindMap(DiagramController controller) async {
    if (controller.diagram == null || controller.diagram!.nodes.isEmpty) return;
    HapticFeedback.mediumImpact();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 16),
            ],
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Synthesizing Practice Quiz from Mind Map...',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );

    final quizData = await controller.generateQuizFromMindMap(numQuestions: 5, difficulty: 'medium');
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    if (quizData != null) {
      context.push(
        AppRoutes.quizzes,
        extra: {'title': controller.diagram?.concept ?? 'Mind Map Quiz'},
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text(controller.errorMessage ?? 'Failed to generate quiz from mind map'),
        ),
      );
    }
  }
}
