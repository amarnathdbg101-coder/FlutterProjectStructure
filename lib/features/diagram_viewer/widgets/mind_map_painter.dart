import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../models/diagram_model.dart';

class MindMapPainter extends CustomPainter {
  final DiagramModel diagram;
  final bool isDark;
  final DiagramNodeModel? selectedNode;

  MindMapPainter({
    required this.diagram,
    required this.isDark,
    this.selectedNode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawGridBackground(canvas, size);
    _drawEdges(canvas);
    _drawNodes(canvas);
  }

  void _drawGridBackground(Canvas canvas, Size size) {
    final dotPaint = Paint()
      ..color = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04)
      ..strokeWidth = 2
      ..style = PaintingStyle.fill;

    const spacing = 32.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.2, dotPaint);
      }
    }
  }

  void _drawEdges(Canvas canvas) {
    final Map<String, DiagramNodeModel> nodeMap = {
      for (final n in diagram.nodes) n.id: n,
    };

    for (final edge in diagram.edges) {
      final from = nodeMap[edge.fromId];
      final to = nodeMap[edge.toId];
      if (from == null || to == null) continue;

      final p1 = Offset(from.x + from.width / 2, from.y + from.height / 2);
      final p2 = Offset(to.x + to.width / 2, to.y + to.height / 2);

      final isSelected = selectedNode != null &&
          (selectedNode!.id == from.id || selectedNode!.id == to.id);

      final edgePaint = Paint()
        ..color = isSelected
            ? AppColors.primary
            : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1))
        ..strokeWidth = isSelected ? 3.0 : 2.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      // Draw smooth Bezier curve between nodes
      final path = Path();
      path.moveTo(p1.dx, p1.dy);
      final controlPoint1 = Offset(p1.dx + (p2.dx - p1.dx) / 2, p1.dy);
      final controlPoint2 = Offset(p1.dx + (p2.dx - p1.dx) / 2, p2.dy);
      path.cubicTo(controlPoint1.dx, controlPoint1.dy, controlPoint2.dx, controlPoint2.dy, p2.dx, p2.dy);

      canvas.drawPath(path, edgePaint);

      // Edge label (if present)
      if (edge.label.isNotEmpty) {
        final mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
        final tp = TextPainter(
          text: TextSpan(
            text: edge.label,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(mid.dx - tp.width / 2, mid.dy - tp.height / 2));
      }
    }
  }

  void _drawNodes(Canvas canvas) {
    for (final node in diagram.nodes) {
      final rect = Rect.fromLTWH(node.x, node.y, node.width, node.height);
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(14));
      final isSelected = selectedNode?.id == node.id;

      Color nodeColor;
      try {
        nodeColor = Color(int.parse(node.colorHex.replaceFirst('#', '0xFF')));
      } catch (_) {
        nodeColor = node.isRoot ? AppColors.primary : AppColors.secondary;
      }

      // 1. Draw Shadow
      final shadowPaint = Paint()
        ..color = isSelected
            ? nodeColor.withValues(alpha: 0.4)
            : Colors.black.withValues(alpha: isDark ? 0.3 : 0.08)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, isSelected ? 12 : 6);
      canvas.drawRRect(rrect.shift(const Offset(0, 3)), shadowPaint);

      // 2. Draw Node Background Pill
      final fillPaint = Paint()..style = PaintingStyle.fill;
      if (node.isRoot) {
        fillPaint.color = nodeColor;
      } else if (node.isBranch) {
        fillPaint.color = isDark ? const Color(0xFF1E293B) : Colors.white;
      } else {
        fillPaint.color = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
      }
      canvas.drawRRect(rrect, fillPaint);

      // 3. Draw Border
      final borderPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 2.5 : (node.isRoot ? 1.0 : 1.8)
        ..color = isSelected
            ? AppColors.primary
            : (node.isRoot ? Colors.white.withValues(alpha: 0.4) : nodeColor);
      canvas.drawRRect(rrect, borderPaint);

      // 4. Draw Node Label Text
      final textColor = node.isRoot
          ? Colors.white
          : (isDark ? Colors.white : AppColors.textPrimary);

      final textSpan = TextSpan(
        text: node.label,
        style: TextStyle(
          color: textColor,
          fontSize: node.isRoot ? 14 : 12,
          fontWeight: node.isRoot ? FontWeight.bold : FontWeight.w600,
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        maxLines: 2,
        ellipsis: '...',
        textAlign: TextAlign.center,
      )..layout(maxWidth: node.width - 24);

      final textOffset = Offset(
        node.x + (node.width - textPainter.width) / 2,
        node.y + (node.height - textPainter.height) / 2,
      );
      textPainter.paint(canvas, textOffset);

      // 5. Draw formula badge if node contains math formulas
      if (node.formulas.isNotEmpty) {
        final badgePaint = Paint()
          ..color = AppColors.warning
          ..style = PaintingStyle.fill;
        final badgeOffset = Offset(node.x + node.width - 10, node.y + 6);
        canvas.drawCircle(badgeOffset, 4, badgePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant MindMapPainter oldDelegate) {
    return oldDelegate.diagram != diagram ||
        oldDelegate.selectedNode != selectedNode ||
        oldDelegate.isDark != isDark;
  }
}
