import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/latex_sanitizer.dart';
import '../models/diagram_model.dart';

class MindMapPainter extends CustomPainter {
  final DiagramModel diagram;
  final bool isDark;
  final DiagramNodeModel? selectedNode;
  final DiagramNodeModel? draggedNode;
  final String searchQuery;
  final int repaintVersion;
  final bool isActiveRecallMode;
  final Set<String> revealedNodeIds;

  MindMapPainter({
    required this.diagram,
    required this.isDark,
    this.selectedNode,
    this.draggedNode,
    this.searchQuery = '',
    this.repaintVersion = 0,
    this.isActiveRecallMode = false,
    this.revealedNodeIds = const {},
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

      // Smart dynamic port docking: dock to perimeter boundaries
      Offset p1;
      Offset p2;
      if (from.x + from.width <= to.x) {
        p1 = Offset(from.x + from.width, from.y + from.height / 2);
        p2 = Offset(to.x, to.y + to.height / 2);
      } else if (to.x + to.width <= from.x) {
        p1 = Offset(from.x, from.y + from.height / 2);
        p2 = Offset(to.x + to.width, to.y + to.height / 2);
      } else if (from.y + from.height <= to.y) {
        p1 = Offset(from.x + from.width / 2, from.y + from.height);
        p2 = Offset(to.x + to.width / 2, to.y);
      } else if (to.y + to.height <= from.y) {
        p1 = Offset(from.x + from.width / 2, from.y);
        p2 = Offset(to.x + to.width / 2, to.y + to.height);
      } else {
        p1 = Offset(from.x + from.width / 2, from.y + from.height / 2);
        p2 = Offset(to.x + to.width / 2, to.y + to.height / 2);
      }

      final isSelected = selectedNode != null &&
          (selectedNode!.id == from.id || selectedNode!.id == to.id);
      final isDragged = draggedNode != null &&
          (draggedNode!.id == from.id || draggedNode!.id == to.id);

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
        // Semantic cross-branch link
        final crossPaint = Paint()
          ..color = const Color(0xFFA855F7).withValues(alpha: (isSelected || isDragged ? 1.0 : 0.65) * opacity)
          ..strokeWidth = (isSelected || isDragged) ? 2.8 : 1.6
          ..style = PaintingStyle.stroke;
        _drawDashedCubicPath(canvas, p1, p2, crossPaint);
      } else {
        final strokeColor = isDragged
            ? const Color(0xFF06B6D4)
            : (isSelected
                ? AppColors.primary.withValues(alpha: opacity)
                : (from.isRoot
                    ? edgeColor.withValues(alpha: (isDark ? 0.65 : 0.45) * opacity)
                    : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)).withValues(alpha: opacity)));

        final edgePaint = Paint()
          ..color = strokeColor
          ..strokeWidth = isDragged ? 3.5 : (isSelected ? 3.0 : (from.isRoot ? 2.5 : 1.8))
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

        // Draw smooth Bezier curve between nodes
        final path = Path();
        path.moveTo(p1.dx, p1.dy);
        final dx = p2.dx - p1.dx;
        final dy = p2.dy - p1.dy;
        final controlPoint1 = Offset(p1.dx + dx * 0.5, p1.dy + (dx.abs() > dy.abs() ? 0 : dy * 0.3));
        final controlPoint2 = Offset(p1.dx + dx * 0.5, p2.dy - (dx.abs() > dy.abs() ? 0 : dy * 0.3));
        path.cubicTo(controlPoint1.dx, controlPoint1.dy, controlPoint2.dx, controlPoint2.dy, p2.dx, p2.dy);

        canvas.drawPath(path, edgePaint);
      }

      // Edge label (if present and not dimmed, with padded rounded pill to avoid cutting through)
      if (edge.label.isNotEmpty && opacity > 0.3) {
        final mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
        final distP1 = (mid - p1).distance;
        final distP2 = (mid - p2).distance;

        // Skip label if edge is too short (< 65px) to prevent overlapping node boxes
        if (distP1 > 32.0 && distP2 > 32.0) {
          final tp = TextPainter(
            text: TextSpan(
              text: edge.label,
              style: TextStyle(
                fontSize: 9.2,
                fontWeight: FontWeight.w600,
                color: (edge.isCrossLink ? const Color(0xFFA855F7) : (isDark ? Colors.grey[300] : Colors.grey[700]))!
                    .withValues(alpha: opacity),
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();

          final labelRect = RRect.fromRectAndRadius(
            Rect.fromLTWH(mid.dx - tp.width / 2 - 5, mid.dy - tp.height / 2 - 2, tp.width + 10, tp.height + 4),
            const Radius.circular(5),
          );
          final labelBgPaint = Paint()
            ..color = isDark ? const Color(0xFF0F172A) : Colors.white
            ..style = PaintingStyle.fill;
          canvas.drawRRect(labelRect, labelBgPaint);

          final labelBorderPaint = Paint()
            ..color = (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)).withValues(alpha: opacity)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8;
          canvas.drawRRect(labelRect, labelBorderPaint);

          tp.paint(canvas, Offset(mid.dx - tp.width / 2, mid.dy - tp.height / 2));
        }
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
      final isDragged = draggedNode?.id == node.id;

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

      // 1. Draw Dragged, Selected or Search Match Halo Ring
      if (isDragged) {
        final dragHaloPaint = Paint()
          ..color = const Color(0xFF06B6D4).withValues(alpha: 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5;
        final dragHaloRRect = RRect.fromRectAndRadius(
          rect.inflate(6),
          const Radius.circular(18),
        );
        canvas.drawRRect(dragHaloRRect, dragHaloPaint);
      } else if (isSelected || isMatch) {
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

      // 2. Draw Soft Shadow (elevated when dragged)
      final shadowPaint = Paint()
        ..color = isDragged
            ? const Color(0xFF06B6D4).withValues(alpha: 0.5)
            : (isSelected
                ? nodeColor.withValues(alpha: 0.45 * nodeOpacity)
                : Colors.black.withValues(alpha: (isDark ? 0.35 : 0.08) * nodeOpacity))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, isDragged ? 24 : (isSelected ? 14 : 6));
      canvas.drawRRect(rrect.shift(Offset(0, isDragged ? 8 : 3)), shadowPaint);

      final isMaskedForRecall = isActiveRecallMode && !node.isRoot && !revealedNodeIds.contains(node.id);
      final isRevealedInRecall = isActiveRecallMode && !node.isRoot && revealedNodeIds.contains(node.id);

      // 3. Draw Node Card Background
      final fillPaint = Paint()..style = PaintingStyle.fill;
      if (isMaskedForRecall) {
        fillPaint.color = (isDark ? const Color(0xFF1E1B4B) : const Color(0xFFEEF2FF))
            .withValues(alpha: nodeOpacity);
      } else if (node.isRoot) {
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
          ..color = (isMaskedForRecall
                  ? const Color(0xFF6366F1)
                  : (isRevealedInRecall ? const Color(0xFF10B981) : nodeColor))
              .withValues(alpha: nodeOpacity)
          ..style = PaintingStyle.fill;
        canvas.drawRRect(accentRect, accentPaint);
      }

      // 5. Draw Card Border
      final borderPaint = Paint()
        ..style = PaintingStyle.stroke;
      if (isMaskedForRecall) {
        borderPaint.strokeWidth = 1.6;
        borderPaint.color = const Color(0xFF818CF8).withValues(alpha: 0.9 * nodeOpacity);
      } else if (isRevealedInRecall) {
        borderPaint.strokeWidth = 1.8;
        borderPaint.color = const Color(0xFF10B981).withValues(alpha: 0.95 * nodeOpacity);
      } else {
        borderPaint.strokeWidth = isSelected ? 2.5 : (node.isRoot ? 1.0 : 1.2);
        borderPaint.color = isSelected
            ? AppColors.primary.withValues(alpha: nodeOpacity)
            : (node.isRoot
                ? Colors.white.withValues(alpha: 0.4 * nodeOpacity)
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)).withValues(alpha: nodeOpacity));
      }
      canvas.drawRRect(rrect, borderPaint);

      // 6. Draw Node Label Text (or Masked Recall Prompt)
      if (isMaskedForRecall) {
        final maskSpan = TextSpan(
          text: '🧠 Tap to Reveal',
          style: TextStyle(
            color: const Color(0xFF818CF8).withValues(alpha: nodeOpacity),
            fontSize: 11.8,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.2,
          ),
        );
        final maskPainter = TextPainter(
          text: maskSpan,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
        )..layout(maxWidth: node.width - 24);
        final maskOffset = Offset(
          node.x + (node.width - maskPainter.width) / 2,
          node.y + (node.height - maskPainter.height) / 2,
        );
        maskPainter.paint(canvas, maskOffset);
        continue; // Skip details, indicator pills, and metrics until tapped
      }

      if (isRevealedInRecall) {
        final checkSpan = TextSpan(
          text: '✓',
          style: TextStyle(
            color: const Color(0xFF10B981).withValues(alpha: nodeOpacity),
            fontSize: 11.0,
            fontWeight: FontWeight.bold,
          ),
        );
        final checkPainter = TextPainter(
          text: checkSpan,
          textDirection: TextDirection.ltr,
        )..layout();
        checkPainter.paint(canvas, Offset(node.x + node.width - 16, node.y + 4));
      }

      final textColor = node.isRoot
          ? Colors.white.withValues(alpha: nodeOpacity)
          : (isDark ? Colors.white : AppColors.textPrimary).withValues(alpha: nodeOpacity);

      final hasMetricPill = node.metrics.isNotEmpty && !node.isRoot;
      final hasTopIndicators = (node.examTrap.isNotEmpty || node.formulas.isNotEmpty || node.codeSnippet.isNotEmpty);

      final textSpan = TextSpan(
        text: LatexSanitizer.clean(node.label),
        style: TextStyle(
          color: textColor,
          fontSize: node.isRoot ? 13.5 : (node.isBranch ? 12.0 : 11.2),
          fontWeight: node.isRoot ? FontWeight.bold : FontWeight.w600,
          letterSpacing: 0.1,
        ),
      );

      final double textPaddingRight = node.isRoot ? 20.0 : (hasTopIndicators ? 42.0 : 24.0);
      final double textPaddingLeft = node.isRoot ? 20.0 : 20.0;
      final double maxTextWidth = (node.width - textPaddingLeft - textPaddingRight).clamp(50.0, 300.0);

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        maxLines: hasMetricPill ? 1 : 2,
        ellipsis: '...',
        textAlign: TextAlign.center,
      )..layout(maxWidth: maxTextWidth);

      // Separate vertical zones: Top indicator zone (0-11px), Text zone (11px to height-18px), Metric pill zone (height-16px to height-3px)
      final textOffsetY = hasMetricPill
          ? node.y + 11.0 + ((node.height - 28.0) - textPainter.height) / 2
          : node.y + (node.height - textPainter.height) / 2;

      final textOffset = Offset(
        node.x + textPaddingLeft + (maxTextWidth - textPainter.width) / 2,
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
            node.x + (node.width - metricPainter.width - 10) / 2,
            node.y + node.height - 16,
            metricPainter.width + 10,
            12,
          ),
          const Radius.circular(3),
        );
        final pillPaint = Paint()
          ..color = nodeColor.withValues(alpha: (isDark ? 0.22 : 0.12) * nodeOpacity)
          ..style = PaintingStyle.fill;
        canvas.drawRRect(pillRect, pillPaint);
        metricPainter.paint(
          canvas,
          Offset(node.x + (node.width - metricPainter.width) / 2, node.y + node.height - 16),
        );
      }

      // 8. Badges & Indicators
      // Universal Card Fold/Expand (Wrap/Unwrap) Indicator pill
      final hasSubNodes = diagram.hasChildren(node.id);
      if ((hasSubNodes || node.isCollapsed) && !node.isRoot) {
        final foldPaint = Paint()
          ..color = (node.isCollapsed ? const Color(0xFFEF4444) : nodeColor)
              .withValues(alpha: 0.95 * nodeOpacity)
          ..style = PaintingStyle.fill;
        final foldOffset = Offset(node.x + node.width - 8, node.y + node.height / 2);
        canvas.drawCircle(foldOffset, 5.5, foldPaint);

        // Mini +/- sign
        final foldSymbol = node.isCollapsed ? '+' : '–';
        final foldTextPainter = TextPainter(
          text: TextSpan(
            text: foldSymbol,
            style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
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
  bool shouldRepaint(covariant MindMapPainter oldDelegate) => true;
}
