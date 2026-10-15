import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../models/diagram_model.dart';

class MindMapPainter extends CustomPainter {
  final DiagramModel diagram;
  final bool isDark;
  final DiagramNodeModel? selectedNode;
  final String searchQuery;

  MindMapPainter({
    required this.diagram,
    required this.isDark,
    this.selectedNode,
    this.searchQuery = '',
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

    final isSearching = searchQuery.isNotEmpty;

    for (final edge in diagram.edges) {
      final from = nodeMap[edge.fromId];
      final to = nodeMap[edge.toId];
      if (from == null || to == null) continue;
      // Skip if either endpoint is hidden (collapsed branch)
      if (!from.isVisible || !to.isVisible) continue;

      final p1 = Offset(from.x + from.width / 2, from.y + from.height / 2);
      final p2 = Offset(to.x + to.width / 2, to.y + to.height / 2);

      final isSelected = selectedNode != null &&
          (selectedNode!.id == from.id || selectedNode!.id == to.id);

      Color edgeColor;
      try {
        final hex = to.colorHex.isNotEmpty ? to.colorHex : from.colorHex;
        edgeColor = Color(int.parse(hex.replaceFirst('#', '0xFF')));
      } catch (_) {
        edgeColor = AppColors.primary;
      }

      double opacity = 1.0;
      if (isSearching) {
        final matchesFrom = from.label.toLowerCase().contains(searchQuery) ||
            from.description.toLowerCase().contains(searchQuery);
        final matchesTo = to.label.toLowerCase().contains(searchQuery) ||
            to.description.toLowerCase().contains(searchQuery);
        opacity = (matchesFrom || matchesTo) ? 1.0 : 0.12;
      }

      if (edge.isCrossLink) {
        // Semantic cross-branch link (e.g. Lomuto worst case -> Sorted array)
        final crossPaint = Paint()
          ..color = const Color(0xFFA855F7).withValues(alpha: (isSelected ? 1.0 : 0.65) * opacity)
          ..strokeWidth = isSelected ? 2.5 : 1.6
          ..style = PaintingStyle.stroke;
        _drawDashedCubicPath(canvas, p1, p2, crossPaint);
      } else {
        final strokeColor = isSelected
            ? AppColors.primary.withValues(alpha: opacity)
            : (from.isRoot
                ? edgeColor.withValues(alpha: (isDark ? 0.65 : 0.45) * opacity)
                : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)).withValues(alpha: opacity));

        final edgePaint = Paint()
          ..color = strokeColor
          ..strokeWidth = isSelected ? 3.5 : (from.isRoot ? 2.5 : 1.8)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

        // Draw smooth Bezier curve between nodes
        final path = Path();
        path.moveTo(p1.dx, p1.dy);
        final controlPoint1 = Offset(p1.dx + (p2.dx - p1.dx) * 0.5, p1.dy);
        final controlPoint2 = Offset(p1.dx + (p2.dx - p1.dx) * 0.5, p2.dy);
        path.cubicTo(controlPoint1.dx, controlPoint1.dy, controlPoint2.dx, controlPoint2.dy, p2.dx, p2.dy);

        canvas.drawPath(path, edgePaint);
      }

      // Edge label (if present and not dimmed)
      if (edge.label.isNotEmpty && opacity > 0.3) {
        final mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
        final tp = TextPainter(
          text: TextSpan(
            text: edge.label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w500,
              color: (edge.isCrossLink ? const Color(0xFFA855F7) : (isDark ? Colors.grey[400] : Colors.grey[600]))!
                  .withValues(alpha: opacity),
              backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(mid.dx - tp.width / 2, mid.dy - tp.height / 2));
      }
    }
  }

  void _drawDashedCubicPath(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    final path = Path();
    path.moveTo(p1.dx, p1.dy);
    final controlPoint1 = Offset(p1.dx + (p2.dx - p1.dx) * 0.5, p1.dy);
    final controlPoint2 = Offset(p1.dx + (p2.dx - p1.dx) * 0.5, p2.dy);
    path.cubicTo(controlPoint1.dx, controlPoint1.dy, controlPoint2.dx, controlPoint2.dy, p2.dx, p2.dy);

    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      const dashWidth = 6.0;
      const dashSpace = 4.0;
      while (distance < metric.length) {
        final len = (distance + dashWidth < metric.length) ? dashWidth : metric.length - distance;
        final extract = metric.extractPath(distance, distance + len);
        canvas.drawPath(extract, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  void _drawNodes(Canvas canvas) {
    final isSearching = searchQuery.isNotEmpty;

    for (final node in diagram.nodes) {
      if (!node.isVisible) continue;

      final rect = Rect.fromLTWH(node.x, node.y, node.width, node.height);
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));
      final isSelected = selectedNode?.id == node.id;

      // Check search match
      final isMatch = isSearching &&
          (node.label.toLowerCase().contains(searchQuery) ||
              node.description.toLowerCase().contains(searchQuery) ||
              node.examTrap.toLowerCase().contains(searchQuery) ||
              node.metrics.values.any((v) => v.toLowerCase().contains(searchQuery)));

      final nodeOpacity = (!isSearching || isMatch) ? 1.0 : 0.22;

      Color nodeColor;
      try {
        nodeColor = Color(int.parse(node.colorHex.replaceFirst('#', '0xFF')));
      } catch (_) {
        nodeColor = node.isRoot ? AppColors.primary : AppColors.secondary;
      }

      // 1. Draw Selected or Search Match Halo Ring
      if (isSelected || isMatch) {
        final haloPaint = Paint()
          ..color = (isMatch ? const Color(0xFFF59E0B) : AppColors.primary)
              .withValues(alpha: 0.35 * nodeOpacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = isMatch ? 4.0 : 5.0;
        final haloRRect = RRect.fromRectAndRadius(
          rect.inflate(isMatch ? 5 : 4),
          const Radius.circular(16),
        );
        canvas.drawRRect(haloRRect, haloPaint);
      }

      // 2. Draw Soft Shadow
      final shadowPaint = Paint()
        ..color = isSelected
            ? nodeColor.withValues(alpha: 0.45 * nodeOpacity)
            : Colors.black.withValues(alpha: (isDark ? 0.35 : 0.08) * nodeOpacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, isSelected ? 14 : 6);
      canvas.drawRRect(rrect.shift(const Offset(0, 3)), shadowPaint);

      // 3. Draw Node Card Background
      final fillPaint = Paint()..style = PaintingStyle.fill;
      if (node.isRoot) {
        fillPaint.color = nodeColor.withValues(alpha: nodeOpacity);
      } else if (node.isBranch) {
        fillPaint.color = (isDark ? const Color(0xFF1E293B) : Colors.white)
            .withValues(alpha: nodeOpacity);
      } else {
        fillPaint.color = (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC))
            .withValues(alpha: nodeOpacity);
      }
      canvas.drawRRect(rrect, fillPaint);

      // 4. Draw Left Accent Stripe for Branch & Leaf nodes
      if (!node.isRoot) {
        final accentRect = RRect.fromRectAndCorners(
          Rect.fromLTWH(node.x, node.y, 5, node.height),
          topLeft: const Radius.circular(12),
          bottomLeft: const Radius.circular(12),
        );
        final accentPaint = Paint()
          ..color = nodeColor.withValues(alpha: nodeOpacity)
          ..style = PaintingStyle.fill;
        canvas.drawRRect(accentRect, accentPaint);
      }

      // 5. Draw Card Border
      final borderPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 2.5 : (node.isRoot ? 1.0 : 1.2)
        ..color = isSelected
            ? AppColors.primary.withValues(alpha: nodeOpacity)
            : (node.isRoot
                ? Colors.white.withValues(alpha: 0.4 * nodeOpacity)
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)).withValues(alpha: nodeOpacity));
      canvas.drawRRect(rrect, borderPaint);

      // 6. Draw Node Label Text
      final textColor = node.isRoot
          ? Colors.white.withValues(alpha: nodeOpacity)
          : (isDark ? Colors.white : AppColors.textPrimary).withValues(alpha: nodeOpacity);

      final hasMetricPill = node.metrics.isNotEmpty && !node.isRoot;

      final textSpan = TextSpan(
        text: node.label,
        style: TextStyle(
          color: textColor,
          fontSize: node.isRoot ? 13.5 : (node.isBranch ? 12.0 : 11.2),
          fontWeight: node.isRoot ? FontWeight.bold : FontWeight.w600,
          letterSpacing: 0.1,
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        maxLines: hasMetricPill ? 1 : 2,
        ellipsis: '...',
        textAlign: TextAlign.center,
      )..layout(maxWidth: node.width - (node.isRoot ? 24 : 32));

      final textOffsetY = hasMetricPill
          ? node.y + (node.height - textPainter.height) / 2 - 6
          : node.y + (node.height - textPainter.height) / 2;

      final textOffset = Offset(
        node.x + (node.isRoot ? (node.width - textPainter.width) / 2 : 12 + (node.width - 24 - textPainter.width) / 2),
        textOffsetY,
      );
      textPainter.paint(canvas, textOffset);

      // 7. On-Card Concrete Metric Pill (e.g. Best: O(N log N) / Worst: O(N²))
      if (hasMetricPill) {
        String metricText = '';
        if (node.metrics.containsKey('Complexity')) {
          metricText = node.metrics['Complexity']!;
        } else if (node.metrics.containsKey('Worst Case')) {
          metricText = 'Worst: ${node.metrics['Worst Case']!}';
        } else if (node.metrics.containsKey('Best Case')) {
          metricText = node.metrics['Best Case']!;
        } else {
          final first = node.metrics.entries.first;
          metricText = '${first.key}: ${first.value}';
        }
        if (metricText.length > 22) {
          metricText = '${metricText.substring(0, 21)}…';
        }

        final metricSpan = TextSpan(
          text: metricText,
          style: TextStyle(
            color: nodeColor.withValues(alpha: 0.95 * nodeOpacity),
            fontSize: 9.0,
            fontWeight: FontWeight.bold,
          ),
        );
        final metricPainter = TextPainter(
          text: metricSpan,
          textDirection: TextDirection.ltr,
        )..layout();

        final pillRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            node.x + (node.width - metricPainter.width - 8) / 2,
            node.y + node.height - 15,
            metricPainter.width + 8,
            11,
          ),
          const Radius.circular(3),
        );
        final pillPaint = Paint()
          ..color = nodeColor.withValues(alpha: (isDark ? 0.22 : 0.12) * nodeOpacity)
          ..style = PaintingStyle.fill;
        canvas.drawRRect(pillRect, pillPaint);
        metricPainter.paint(
          canvas,
          Offset(node.x + (node.width - metricPainter.width) / 2, node.y + node.height - 15),
        );
      }

      // 8. Badges & Indicators
      // Branch Fold/Expand Indicator pill
      if (node.isBranch) {
        final foldPaint = Paint()
          ..color = (node.isCollapsed ? const Color(0xFFEF4444) : nodeColor)
              .withValues(alpha: 0.9 * nodeOpacity)
          ..style = PaintingStyle.fill;
        final foldOffset = Offset(node.x + node.width - 8, node.y + node.height / 2);
        canvas.drawCircle(foldOffset, 5.0, foldPaint);

        // Mini +/- sign
        final foldSymbol = node.isCollapsed ? '+' : '–';
        final foldTextPainter = TextPainter(
          text: TextSpan(
            text: foldSymbol,
            style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        foldTextPainter.paint(
          canvas,
          Offset(foldOffset.dx - foldTextPainter.width / 2, foldOffset.dy - foldTextPainter.height / 2),
        );
      }

      // Exam Trap Warning Dot (Amber/Red)
      if (node.examTrap.isNotEmpty && !node.isRoot) {
        final trapPaint = Paint()
          ..color = const Color(0xFFF59E0B).withValues(alpha: 0.9 * nodeOpacity)
          ..style = PaintingStyle.fill;
        final trapOffset = Offset(node.x + node.width - 12, node.y + 7);
        canvas.drawCircle(trapOffset, 3.5, trapPaint);
      }

      // Math Formulas Indicator Dot (Cyan)
      if (node.formulas.isNotEmpty) {
        final mathPaint = Paint()
          ..color = const Color(0xFF06B6D4).withValues(alpha: 0.9 * nodeOpacity)
          ..style = PaintingStyle.fill;
        final mathOffset = Offset(node.x + (node.examTrap.isNotEmpty ? node.width - 22 : node.width - 12), node.y + 7);
        canvas.drawCircle(mathOffset, 3.5, mathPaint);
      }

      // Code Snippet Indicator Dot (Violet)
      if (node.codeSnippet.isNotEmpty && !node.isRoot) {
        final codePaint = Paint()
          ..color = const Color(0xFF8B5CF6).withValues(alpha: 0.9 * nodeOpacity)
          ..style = PaintingStyle.fill;
        final codeOffset = Offset(
          node.x + (node.formulas.isNotEmpty ? node.width - 32 : (node.examTrap.isNotEmpty ? node.width - 22 : node.width - 12)),
          node.y + 7,
        );
        canvas.drawCircle(codeOffset, 3.5, codePaint);
      }

      // Importance Star for High Yield (5/5)
      if (node.importance >= 4 && !node.isRoot) {
        final impPaint = Paint()
          ..color = const Color(0xFF10B981).withValues(alpha: 0.9 * nodeOpacity)
          ..style = PaintingStyle.fill;
        final impOffset = Offset(node.x + 12, node.y + 7);
        canvas.drawCircle(impOffset, 3.0, impPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant MindMapPainter oldDelegate) {
    return oldDelegate.diagram != diagram ||
        oldDelegate.selectedNode != selectedNode ||
        oldDelegate.isDark != isDark ||
        oldDelegate.searchQuery != searchQuery;
  }
}
