import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../models/diagram_model.dart';

class MindMapMinimap extends StatefulWidget {
  final DiagramModel diagram;
  final TransformationController transformController;
  final Size canvasSize;
  final Size viewportSize;
  final bool isDark;
  final VoidCallback? onToggleCollapse;

  const MindMapMinimap({
    super.key,
    required this.diagram,
    required this.transformController,
    required this.canvasSize,
    required this.viewportSize,
    required this.isDark,
    this.onToggleCollapse,
  });

  @override
  State<MindMapMinimap> createState() => _MindMapMinimapState();
}

class _MindMapMinimapState extends State<MindMapMinimap> {
  static const double _width = 150.0;
  static const double _height = 100.0;

  void _handleMinimapInteraction(Offset localOffset) {
    HapticFeedback.selectionClick();
    final scaleX = _width / widget.canvasSize.width;
    final scaleY = _height / widget.canvasSize.height;

    final targetCanvasX = (localOffset.dx / scaleX).clamp(0.0, widget.canvasSize.width);
    final targetCanvasY = (localOffset.dy / scaleY).clamp(0.0, widget.canvasSize.height);

    final currentScale = widget.transformController.value.getMaxScaleOnAxis().clamp(0.4, 3.0);
    final targetTx = (widget.viewportSize.width / 2) - (targetCanvasX * currentScale);
    final targetTy = (widget.viewportSize.height / 2) - (targetCanvasY * currentScale);

    widget.transformController.value = Matrix4.translationValues(targetTx, targetTy, 0.0)
      ..scaleByDouble(currentScale, currentScale, 1.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.transformController,
      builder: (context, _) {
        return Container(
          width: _width,
          decoration: BoxDecoration(
            color: widget.isDark
                ? const Color(0xFF0F172A).withValues(alpha: 0.90)
                : Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isDark
                  ? const Color(0xFF334155).withValues(alpha: 0.8)
                  : const Color(0xFFCBD5E1),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: widget.isDark ? 0.45 : 0.12),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Mini Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.isDark
                      ? const Color(0xFF1E293B).withValues(alpha: 0.95)
                      : const Color(0xFFF1F5F9),
                  border: Border(
                    bottom: BorderSide(
                      color: widget.isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      width: 0.8,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.map_outlined, size: 12, color: AppColors.primary),
                        SizedBox(width: 4),
                        Text(
                          'NAVIGATOR',
                          style: TextStyle(
                            fontSize: 9.0,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.6,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    if (widget.onToggleCollapse != null)
                      GestureDetector(
                        onTap: widget.onToggleCollapse,
                        child: const Icon(Icons.close_rounded, size: 13, color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ),

              // Interactive Minimap Canvas
              GestureDetector(
                onTapDown: (details) => _handleMinimapInteraction(details.localPosition),
                onPanUpdate: (details) => _handleMinimapInteraction(details.localPosition),
                child: SizedBox(
                  width: _width,
                  height: _height,
                  child: CustomPaint(
                    size: const Size(_width, _height),
                    painter: _MinimapPainter(
                      diagram: widget.diagram,
                      transformMatrix: widget.transformController.value,
                      canvasSize: widget.canvasSize,
                      viewportSize: widget.viewportSize,
                      isDark: widget.isDark,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MinimapPainter extends CustomPainter {
  final DiagramModel diagram;
  final Matrix4 transformMatrix;
  final Size canvasSize;
  final Size viewportSize;
  final bool isDark;

  _MinimapPainter({
    required this.diagram,
    required this.transformMatrix,
    required this.canvasSize,
    required this.viewportSize,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / canvasSize.width;
    final scaleY = size.height / canvasSize.height;

    // Background fill
    final bgPaint = Paint()
      ..color = isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Offset.zero & size, bgPaint);

    // 1. Draw Edges
    final edgePaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    final nodeMap = {for (final n in diagram.nodes) n.id: n};
    for (final edge in diagram.edges) {
      final from = nodeMap[edge.fromId];
      final to = nodeMap[edge.toId];
      if (from == null || to == null || !from.isVisible || !to.isVisible) continue;

      final p1 = Offset(
        (from.x + from.width / 2) * scaleX,
        (from.y + from.height / 2) * scaleY,
      );
      final p2 = Offset(
        (to.x + to.width / 2) * scaleX,
        (to.y + to.height / 2) * scaleY,
      );
      canvas.drawLine(p1, p2, edgePaint);
    }

    // 2. Draw Nodes as Mini Shapes
    for (final node in diagram.nodes) {
      if (!node.isVisible) continue;

      Color color;
      try {
        color = Color(int.parse(node.colorHex.replaceFirst('#', '0xFF')));
      } catch (_) {
        color = node.isRoot ? AppColors.primary : AppColors.secondary;
      }

      final miniRect = Rect.fromLTWH(
        node.x * scaleX,
        node.y * scaleY,
        (node.width * scaleX).clamp(4.0, 20.0),
        (node.height * scaleY).clamp(3.0, 12.0),
      );

      final nodePaint = Paint()
        ..color = color.withValues(alpha: node.isRoot ? 1.0 : 0.8)
        ..style = PaintingStyle.fill;

      canvas.drawRRect(RRect.fromRectAndRadius(miniRect, const Radius.circular(1.5)), nodePaint);
    }

    // 3. Draw Camera Viewport Viewfinder
    try {
      final inverse = Matrix4.inverted(transformMatrix);
      final pTopLeft = MatrixUtils.transformPoint(inverse, Offset.zero);
      final pBottomRight = MatrixUtils.transformPoint(inverse, Offset(viewportSize.width, viewportSize.height));

      final viewLeft = (pTopLeft.dx * scaleX).clamp(0.0, size.width);
      final viewTop = (pTopLeft.dy * scaleY).clamp(0.0, size.height);
      final viewRight = (pBottomRight.dx * scaleX).clamp(0.0, size.width);
      final viewBottom = (pBottomRight.dy * scaleY).clamp(0.0, size.height);

      final viewportRect = Rect.fromLTRB(viewLeft, viewTop, viewRight, viewBottom);

      // Semi-transparent viewfinder overlay
      final viewFillPaint = Paint()
        ..color = const Color(0xFF06B6D4).withValues(alpha: 0.18)
        ..style = PaintingStyle.fill;
      canvas.drawRect(viewportRect, viewFillPaint);

      // Viewfinder border
      final viewBorderPaint = Paint()
        ..color = const Color(0xFF06B6D4)
        ..strokeWidth = 1.4
        ..style = PaintingStyle.stroke;
      canvas.drawRect(viewportRect, viewBorderPaint);
    } catch (_) {
      // Inversion failure guard
    }
  }

  @override
  bool shouldRepaint(covariant _MinimapPainter oldDelegate) => true;
}
