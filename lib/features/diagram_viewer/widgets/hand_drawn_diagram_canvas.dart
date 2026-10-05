import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'interactive_visual_diagram.dart';

/// Random offset helper returning a value in [-maxOffset, +maxOffset] (default -2px to +2px)
/// Provides authentic human hand-drawn jitter without robotic grid alignment.
double randomOffset([double maxOffset = 2.0, Random? rand]) {
  final r = rand ?? Random();
  return (r.nextDouble() - 0.5) * (maxOffset * 2);
}

/// Data model for a node in the hand-drawn scratch notebook diagram
class HandDrawnNode {
  final String id;
  final String label;
  final String? subtitle;
  final String shape; // 'circle', 'ellipse', 'box', 'triangle', 'capsule'
  final Color color;
  final IconData? icon;
  final int stepIndex;

  const HandDrawnNode({
    required this.id,
    required this.label,
    this.subtitle,
    String? shape,
    String type = 'box',
    required this.color,
    this.icon,
    this.stepIndex = 1,
  }) : shape = shape ?? type;

  String get type => shape;
  bool get isCircle => shape == 'circle' || shape == 'ellipse';
  bool get isTriangle => shape == 'triangle';
  bool get isBox => shape == 'box' || shape == 'rectangle';
  bool get isCapsule =>
      shape == 'capsule' || shape == 'pill' || shape == 'start' || shape == 'output';

  bool get isStart => type == 'capsule' || type == 'start' || type == 'pill';
  bool get isDecision => type == 'diamond' || type == 'decision';
  bool get isOutput => type == 'output' || type == 'end';
}

/// Data model for a connecting edge/arrow in the hand-drawn diagram
class HandDrawnEdge {
  final String fromId;
  final String toId;
  final String? label; // e.g. "blood flow", "oxygenation", "F1 = -F2"
  final String style; // 'solid', 'dashed', 'wavy'
  final Color? color;

  const HandDrawnEdge({
    required this.fromId,
    required this.toId,
    this.label,
    this.style = 'solid',
    this.color,
  });
}

enum SketchCategory { biology, database, physics, chemistry, flowchart }

extension SketchCategoryExt on HandDrawnGraphData {
  SketchCategory get category {
    final t = title.toLowerCase();
    if (t.contains('dog') ||
        t.contains('cat') ||
        t.contains('animal') ||
        t.contains('cell') ||
        t.contains('heart') ||
        t.contains('anatomy') ||
        t.contains('organ') ||
        t.contains('biology') ||
        t.contains('blood')) {
      return SketchCategory.biology;
    }
    if (t.contains('database') ||
        t.contains('sql') ||
        t.contains('server') ||
        t.contains('cloud') ||
        t.contains('architecture') ||
        t.contains('backend')) {
      return SketchCategory.database;
    }
    if (t.contains('force') ||
        t.contains('physics') ||
        t.contains('vector') ||
        t.contains('mechanics') ||
        t.contains('velocity') ||
        t.contains('motion')) {
      return SketchCategory.physics;
    }
    if (t.contains('molecule') ||
        t.contains('atom') ||
        t.contains('chemistry') ||
        t.contains('bond')) {
      return SketchCategory.chemistry;
    }
    return SketchCategory.flowchart;
  }
}

/// Graph container holding the parsed conceptual diagram data
class HandDrawnGraphData {
  final String title;
  final String? conceptSummary;
  final List<HandDrawnNode> nodes;
  final List<HandDrawnEdge> edges;

  const HandDrawnGraphData({
    required this.title,
    this.conceptSummary,
    required this.nodes,
    required this.edges,
  });

  /// Factory to parse structured JSON from Gemini output
  factory HandDrawnGraphData.fromJson(Map<String, dynamic> json,
      {String defaultTitle = 'Conceptual Diagram', bool isDark = false}) {
    // Support nested "diagram" wrapper: { "explanation": "...", "diagram": { "nodes": [...], "edges": [...] } }
    final Map<String, dynamic> data = (json['diagram'] is Map<String, dynamic>)
        ? json['diagram'] as Map<String, dynamic>
        : json;

    final title = json['title'] as String? ?? data['title'] as String? ?? defaultTitle;
    final summary = json['explanation'] as String? ??
        json['conceptSummary'] as String? ??
        data['conceptSummary'] as String? ??
        json['summary'] as String?;

    final List<HandDrawnNode> parsedNodes = [];
    final rawNodes = data['nodes'] ?? json['nodes'];
    const palette = [
      Color(0xFF4F46E5), // Indigo
      Color(0xFF059669), // Emerald
      Color(0xFFD97706), // Amber
      Color(0xFFDC2626), // Crimson
      Color(0xFF7C3AED), // Violet
      Color(0xFF0284C7), // Sky
      Color(0xFFDB2777), // Pink
    ];

    if (rawNodes is List) {
      for (int i = 0; i < rawNodes.length; i++) {
        final item = rawNodes[i];
        if (item is Map<String, dynamic>) {
          final id = item['id']?.toString() ?? 'node_${i + 1}';
          final label = item['label']?.toString() ??
              item['title']?.toString() ??
              'Concept ${i + 1}';
          final subtitle =
              item['subtitle']?.toString() ?? item['description']?.toString();
          final rawShape = item['shape']?.toString().toLowerCase() ??
              item['type']?.toString().toLowerCase() ??
              'box';
          final shape = resolveSemanticShape(rawShape, label, subtitle: subtitle);

          Color color = palette[i % palette.length];
          if (item['color'] != null) {
            final colStr = item['color'].toString().replaceAll('#', '');
            if (colStr.length == 6) {
              color = Color(int.parse('0xFF$colStr'));
            }
          }

          parsedNodes.add(HandDrawnNode(
            id: id,
            label: label,
            subtitle: subtitle,
            shape: shape,
            color: color,
            stepIndex: i + 1,
          ));
        }
      }
    }

    final List<HandDrawnEdge> parsedEdges = [];
    final rawEdges = data['edges'] ??
        data['relations'] ??
        data['arrows'] ??
        json['edges'] ??
        json['relations'];

    if (rawEdges is List) {
      for (int i = 0; i < rawEdges.length; i++) {
        final e = rawEdges[i];
        if (e is Map<String, dynamic>) {
          Color? edgeColor;
          if (e['color'] != null) {
            final colStr = e['color'].toString().replaceAll('#', '');
            if (colStr.length == 6) {
              edgeColor = Color(int.parse('0xFF$colStr'));
            }
          }
          edgeColor ??= palette[i % palette.length];

          parsedEdges.add(HandDrawnEdge(
            fromId: e['from']?.toString() ?? '',
            toId: e['to']?.toString() ?? '',
            label: e['label']?.toString() ??
                e['condition']?.toString() ??
                e['relation']?.toString(),
            style: e['style']?.toString().toLowerCase() ?? 'solid',
            color: edgeColor,
          ));
        }
      }
    } else if (parsedNodes.length > 1) {
      // Auto-connect sequential nodes with distinct matching edge colors
      for (int i = 0; i < parsedNodes.length - 1; i++) {
        parsedEdges.add(HandDrawnEdge(
          fromId: parsedNodes[i].id,
          toId: parsedNodes[i + 1].id,
          color: parsedNodes[i].color,
        ));
      }
    }

    return HandDrawnGraphData(
      title: title,
      conceptSummary: summary,
      nodes: parsedNodes,
      edges: parsedEdges,
    );
  }

  /// Converts existing DiagramNodes into HandDrawnGraphData
  factory HandDrawnGraphData.fromDiagramNodes(
      List<DiagramNode> diagramNodes, String title) {
    final List<HandDrawnNode> nodes = [];
    final List<HandDrawnEdge> edges = [];

    for (int i = 0; i < diagramNodes.length; i++) {
      final dn = diagramNodes[i];
      String rawShape = 'box';
      if (dn.isStart || dn.isOutput) {
        rawShape = 'capsule';
      } else if (dn.isDecision) {
        rawShape = 'triangle';
      } else {
        rawShape = 'box';
      }
      final shape = resolveSemanticShape(rawShape, dn.title, subtitle: dn.subtitle);

      nodes.add(HandDrawnNode(
        id: dn.id,
        label: dn.title,
        subtitle: dn.subtitle,
        shape: shape,
        color: dn.color,
        icon: dn.icon,
        stepIndex: i + 1,
      ));

      if (i < diagramNodes.length - 1) {
        edges.add(HandDrawnEdge(
          fromId: dn.id,
          toId: diagramNodes[i + 1].id,
          label: diagramNodes[i + 1].branchCondition,
          color: dn.color,
        ));
      }
    }

    return HandDrawnGraphData(
      title: title,
      nodes: nodes,
      edges: edges,
    );
  }

  /// Intelligent Semantic Shape Resolver mapping concepts to standard system containers
  static String resolveSemanticShape(String rawShape, String label, {String? subtitle}) {
    final lowerShape = rawShape.toLowerCase().trim();
    final combined = '$label ${subtitle ?? ''}'.toLowerCase();

    // 1. Storage / Database / Memory / Disk / RAM / Registers -> Cylinder
    if (lowerShape == 'cylinder' || lowerShape == 'database' ||
        combined.contains('database') || combined.contains('disk') || combined.contains('storage')) {
      return 'cylinder';
    }

    // 2. Computers, Devices, CPU, Hardware, System, Servers, Microprocessors -> Compact Box
    if (combined.contains('computer') || combined.contains('cpu') || combined.contains('server') ||
        combined.contains('system') || combined.contains('hardware') || combined.contains('processor') ||
        combined.contains('alu') || combined.contains('register') || combined.contains('unit')) {
      return 'box';
    }

    // 3. Start / End / Terminator / Goal -> Capsule (Pill)
    if (lowerShape == 'terminator' || lowerShape == 'pill' || lowerShape == 'capsule' || lowerShape == 'start' || lowerShape == 'end' ||
        combined.startsWith('start') || combined.startsWith('end') || combined.contains('finish')) {
      return 'capsule';
    }

    // 4. Decision / Condition / Branch -> Diamond/Triangle
    if (lowerShape == 'decision' || lowerShape == 'diamond' || lowerShape == 'condition' ||
        combined.contains('is ') || combined.contains('if ') || combined.endsWith('?')) {
      return 'triangle';
    }

    // 5. If rawShape is explicitly box, capsule, cylinder, or circle, respect it
    if (['box', 'capsule', 'cylinder', 'circle'].contains(lowerShape)) {
      return lowerShape;
    }

    // Default for general concepts: Compact Box (never a random Triangle!)
    return 'box';
  }

  /// Attempts to parse raw text (JSON or markdown fence) into HandDrawnGraphData
  static HandDrawnGraphData? tryParse(String rawText, String title,
      {bool isDark = false}) {
    final jsonStr = findOuterJsonBlock(rawText);
    if (jsonStr != null) {
      try {
        final decoded = jsonDecode(jsonStr);
        if (decoded is Map<String, dynamic> &&
            (decoded.containsKey('nodes') || decoded.containsKey('diagram') || decoded.containsKey('edges'))) {
          return HandDrawnGraphData.fromJson(decoded,
              defaultTitle: title, isDark: isDark);
        }
      } catch (_) {}
    }

    return null;
  }

  /// Robust JSON block extractor finding outer braces
  static String? findOuterJsonBlock(String text) {
    final firstBrace = text.indexOf('{');
    final lastBrace = text.lastIndexOf('}');
    if (firstBrace != -1 && lastBrace > firstBrace) {
      return text.substring(firstBrace, lastBrace + 1).trim();
    }
    return null;
  }
}

/// Layout calculation result for authentic notebook canvas
class _HandDrawnCanvasLayout {
  final Map<String, Rect> nodeRects;
  final double totalWidth;
  final double totalHeight;

  const _HandDrawnCanvasLayout({
    required this.nodeRects,
    required this.totalWidth,
    required this.totalHeight,
  });
}

/// Flutter CustomPainter widget rendering authentic Hand-Drawn Notebook Sketches.
/// Eliminates rigid flowchart pipelines in favor of organic 2D graph placement,
/// ±2px jittered shape perimeters, segmented shaky edge lines, unequal arrowheads,
/// variable stroke pressure (1.5px–2.5px), and handwritten typography.
class HandDrawnDiagramCanvas extends StatelessWidget {
  final HandDrawnGraphData graphData;
  final bool isDark;
  final double baseFontSize;

  const HandDrawnDiagramCanvas({
    super.key,
    required this.graphData,
    required this.isDark,
    this.baseFontSize = 13.5,
  });

  /// Dynamically computes organic 2D node placement with ±random jitter
  /// preventing rigid grids or flowchart column pipelines.
  static _HandDrawnCanvasLayout _computeLayout(
    List<HandDrawnNode> nodes,
    List<HandDrawnEdge> edges,
    double canvasWidth,
    double baseFontSize,
  ) {
    if (nodes.isEmpty) {
      return const _HandDrawnCanvasLayout(nodeRects: {}, totalWidth: 0, totalHeight: 0);
    }

    final double leftMargin = 52.0;
    final double rightMargin = 22.0;
    final double usableWidth = max(220.0, canvasWidth - leftMargin - rightMargin);
    final double centerX = leftMargin + usableWidth / 2;
    const double topMargin = 20.0;

    // 1. Measure text dimensions and calculate shape bounding box sizes
    final Map<String, Size> nodeSizes = {};
    for (int i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      final titlePainter = TextPainter(
        text: TextSpan(
          text: node.label,
          style: GoogleFonts.patrickHand(
            fontSize: baseFontSize + 1,
            fontWeight: FontWeight.bold,
            height: 1.15,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        maxLines: 3,
      )..layout(maxWidth: min(180.0, usableWidth * 0.45));

      double textTotalHeight = titlePainter.height;
      double textTotalWidth = titlePainter.width;

      if (node.subtitle != null && node.subtitle!.isNotEmpty) {
        final subPainter = TextPainter(
          text: TextSpan(
            text: node.subtitle!,
            style: GoogleFonts.indieFlower(
              fontSize: baseFontSize - 0.5,
              fontWeight: FontWeight.w600,
              height: 1.15,
            ),
          ),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
          maxLines: 2,
        )..layout(maxWidth: min(180.0, usableWidth * 0.45));

        textTotalHeight += subPainter.height + 3.0;
        textTotalWidth = max(textTotalWidth, subPainter.width);
      }

      double w, h;
      if (node.isCircle) {
        final r = max(28.0, max(textTotalWidth / 2 + 14.0, textTotalHeight / 2 + 12.0));
        w = r * 2;
        h = r * 2;
      } else if (node.isTriangle) {
        w = max(60.0, textTotalWidth + 28.0);
        h = max(44.0, textTotalHeight + 20.0);
      } else {
        // Compact Systemic Box / Rectangle with safety margins
        w = max(64.0, textTotalWidth + 28.0);
        h = max(36.0, textTotalHeight + 18.0);
      }
      nodeSizes[node.id] = Size(w, h);
    }

    final Map<String, Offset> nodePositions = {};
    double calculatedTotalHeight = 220.0;

    // Detect if this graph represents a true closed circulation cycle (e.g. Krebs cycle, Water cycle)
    final inDegree = <String, int>{for (var n in nodes) n.id: 0};
    final outDegree = <String, int>{for (var n in nodes) n.id: 0};
    for (final e in edges) {
      inDegree[e.toId] = (inDegree[e.toId] ?? 0) + 1;
      outDegree[e.fromId] = (outDegree[e.fromId] ?? 0) + 1;
    }
    final hasSource = nodes.any((n) => (inDegree[n.id] ?? 0) == 0);
    final hasSink = nodes.any((n) => (outDegree[n.id] ?? 0) == 0);
    final hasBackEdge = edges.any((e) {
      final fromIdx = nodes.indexWhere((n) => n.id == e.fromId);
      final toIdx = nodes.indexWhere((n) => n.id == e.toId);
      return fromIdx != -1 && toIdx != -1 && toIdx <= fromIdx;
    });

    // If there's an open start and open end, it is a linear/branching flowchart, NOT a cycle!
    final bool isCycle = nodes.length >= 3 && hasBackEdge && (!hasSource || !hasSink);

    if (nodes.length == 1) {
      nodePositions[nodes[0].id] = Offset(centerX, topMargin + 50.0);
      calculatedTotalHeight = topMargin + 120.0;
    } else if (isCycle && usableWidth >= 380.0 && nodes.length <= 5) {
      // ⟳ RADIAL CLOSED CYCLE (only if wide canvas and few nodes)
      final double radiusX = min(usableWidth * 0.38, 150.0);
      final double radiusY = max(80.0, min(radiusX * 0.80, 115.0));
      final Offset loopCenter = Offset(centerX, topMargin + radiusY + 30.0);

      for (int i = 0; i < nodes.length; i++) {
        final node = nodes[i];
        final angle = -pi / 2 + (2 * pi * i) / nodes.length;
        final x = loopCenter.dx + radiusX * cos(angle);
        final y = loopCenter.dy + radiusY * sin(angle);
        nodePositions[node.id] = Offset(x, y);
      }
      calculatedTotalHeight = loopCenter.dy + radiusY + 80.0;
    } else {
      // 🚀 SMART 2D TOPOLOGICAL TREE & BRANCHING LAYOUT ENGINE (Sugiyama / BFS Tiers)
      final Map<String, List<String>> childrenMap = {};
      final Map<String, int> inDegree = {for (var n in nodes) n.id: 0};
      for (final e in edges) {
        childrenMap.putIfAbsent(e.fromId, () => []).add(e.toId);
        inDegree[e.toId] = (inDegree[e.toId] ?? 0) + 1;
      }

      final Map<String, int> nodeLevels = {};
      final List<String> roots = nodes.where((n) => (inDegree[n.id] ?? 0) == 0).map((n) => n.id).toList();
      if (roots.isEmpty && nodes.isNotEmpty) {
        roots.add(nodes[0].id);
      }

      final List<String> queue = List.from(roots);
      for (final r in roots) {
        nodeLevels[r] = 0;
      }

      while (queue.isNotEmpty) {
        final currentId = queue.removeAt(0);
        final currentLevel = nodeLevels[currentId] ?? 0;
        final children = childrenMap[currentId] ?? [];
        for (final childId in children) {
          if (!nodeLevels.containsKey(childId) || nodeLevels[childId]! < currentLevel + 1) {
            nodeLevels[childId] = currentLevel + 1;
            queue.add(childId);
          }
        }
      }

      for (int i = 0; i < nodes.length; i++) {
        final n = nodes[i];
        if (!nodeLevels.containsKey(n.id)) {
          nodeLevels[n.id] = i;
        }
      }

      final Map<int, List<HandDrawnNode>> levelGroups = {};
      for (final n in nodes) {
        final lvl = nodeLevels[n.id] ?? 0;
        levelGroups.putIfAbsent(lvl, () => []).add(n);
      }

      final sortedLevels = levelGroups.keys.toList()..sort();

      double curY = topMargin + 16.0;
      for (final lvl in sortedLevels) {
        final group = levelGroups[lvl]!;
        final int count = group.length;
        double maxLevelH = 0.0;
        final double slotWidth = count > 1 ? max(140.0, usableWidth / count) : usableWidth;

        for (int i = 0; i < count; i++) {
          final node = group[i];
          final size = nodeSizes[node.id]!;
          maxLevelH = max(maxLevelH, size.height);

          double x;
          if (count == 1) {
            x = centerX;
          } else {
            x = leftMargin + (i + 0.5) * slotWidth;
          }

          nodePositions[node.id] = Offset(x, curY + size.height / 2);
        }

        curY += maxLevelH + 46.0;
      }
      calculatedTotalHeight = curY + 20.0;
    }

    // (a) Position में ±random jitter
    final Map<String, Rect> finalRects = {};
    for (int i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      final size = nodeSizes[node.id]!;
      final rand = Random(node.id.hashCode ^ (i * 3571));
      final pos = nodePositions[node.id] ?? Offset(centerX, topMargin + 60.0 * i);

      final jitterX = randomOffset(2.0, rand);
      final jitterY = randomOffset(2.0, rand);

      final halfW = size.width / 2;
      final clampedX = max(
        leftMargin + halfW + 4,
        pos.dx + jitterX,
      );
      final clampedY = pos.dy + jitterY;

      finalRects[node.id] = Rect.fromCenter(
        center: Offset(clampedX, clampedY),
        width: size.width,
        height: size.height,
      );
    }

    // (b) 🛡️ 10-ITERATION SMART 2D COLLISION SOLVER (Horizontal Level Shift + Vertical Tier Separation)
    // Guarantees bounding box isolation and zero shape/label overlap
    for (int iteration = 0; iteration < 10; iteration++) {
      for (int i = 0; i < nodes.length; i++) {
        final nodeA = nodes[i];
        final rectA = finalRects[nodeA.id];
        if (rectA == null) continue;

        for (int j = i + 1; j < nodes.length; j++) {
          final nodeB = nodes[j];
          final rectB = finalRects[nodeB.id];
          if (rectB == null) continue;

          final double minSpanX = (rectA.width + rectB.width) / 2 + 24.0;
          final double minSpanY = (rectA.height + rectB.height) / 2 + 36.0;

          final double deltaX = rectB.center.dx - rectA.center.dx;
          final double deltaY = rectB.center.dy - rectA.center.dy;

          if (deltaX.abs() < minSpanX && deltaY.abs() < minSpanY) {
            final double overlapX = minSpanX - deltaX.abs();
            final double overlapY = minSpanY - deltaY.abs();

            if (deltaY.abs() < 28.0) {
              // Same horizontal level tier -> Shift horizontally!
              final double shiftX = (deltaX >= 0 ? 1 : -1) * (overlapX + 10.0);
              finalRects[nodeB.id] = rectB.translate(shiftX, 0);
            } else {
              // Different vertical depth levels -> Shift vertically!
              final double shiftY = (deltaY >= 0 ? 1 : -1) * (overlapY + 10.0);
              finalRects[nodeB.id] = rectB.translate(0, shiftY);
            }
          }
        }
      }
    }

    // Recompute total width and height based on outer-most node bounds
    double maxX = canvasWidth;
    double maxY = 160.0;
    for (final rect in finalRects.values) {
      if (rect.right + rightMargin + 24.0 > maxX) {
        maxX = rect.right + rightMargin + 24.0;
      }
      if (rect.bottom + 20.0 > maxY) {
        maxY = rect.bottom + 20.0;
      }
    }

    return _HandDrawnCanvasLayout(
      nodeRects: finalRects,
      totalWidth: max(canvasWidth, maxX),
      totalHeight: max(calculatedTotalHeight, maxY),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (graphData.nodes.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double screenWidth = MediaQuery.sizeOf(context).width - 32.0;
        final double canvasWidth = (constraints.maxWidth.isFinite && constraints.maxWidth > 0)
            ? constraints.maxWidth
            : max(340.0, screenWidth);

        final layout = _computeLayout(
          graphData.nodes,
          graphData.edges,
          canvasWidth,
          baseFontSize,
        );

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: SizedBox(
            width: layout.totalWidth,
            height: layout.totalHeight,
            child: CustomPaint(
              size: Size(layout.totalWidth, layout.totalHeight),
              painter: _RoughNotebookPainter(
                graphData: graphData,
                isDark: isDark,
                baseFontSize: baseFontSize,
                layout: layout,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The Human Scratch-Style CustomPainter implementing:
/// 1. Student ruled notebook paper (margin, horizontal lines, punch holes)
/// 2. Imperfect circle/ellipse with ±2px radius variation
/// 3. Box with 4 separate sides and random offset
/// 4. Triangle with 3 jittered vertices
/// 5. Segmented shaky lines with ±2px random offset
/// 6. Unequal arrowheads with random tilt
/// 7. Stroke pressure variation (1.5px–2.5px)
/// 8. Handwritten Google Fonts (Patrick Hand, Indie Flower) with uneven alignment
class _RoughNotebookPainter extends CustomPainter {
  final HandDrawnGraphData graphData;
  final bool isDark;
  final double baseFontSize;
  final _HandDrawnCanvasLayout layout;

  _RoughNotebookPainter({
    required this.graphData,
    required this.isDark,
    required this.baseFontSize,
    required this.layout,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Notebook Scratch Paper Texture
    _drawNotebookPaper(canvas, size);

    final nodeRects = layout.nodeRects;
    final nodeMap = {for (var n in graphData.nodes) n.id: n};
    final List<Rect> placedLabelRects = [];

    // 2. Draw Connecting Hand-Drawn Edges (Clean Direct Lines + Side Routing for Non-Adjacent)
    for (int i = 0; i < graphData.edges.length; i++) {
      final edge = graphData.edges[i];
      final fromRect = nodeRects[edge.fromId];
      final toRect = nodeRects[edge.toId];
      final fromNode = nodeMap[edge.fromId];
      final toNode = nodeMap[edge.toId];

      if (fromRect != null && toRect != null && fromNode != null && toNode != null) {
        final fromIdx = graphData.nodes.indexOf(fromNode);
        final toIdx = graphData.nodes.indexOf(toNode);
        final isAdjacent = (fromIdx != -1 && toIdx != -1 && (toIdx - fromIdx).abs() <= 1);

        Offset start;
        Offset end;
        Offset controlPoint;

        if (isAdjacent) {
          start = _boundaryPoint(fromRect, fromNode.shape, toRect.center);
          end = _boundaryPoint(toRect, toNode.shape, fromRect.center);
          // Clean, reliable direct connection without wild 22px balloon swings
          final double curvature = 0.0;
          controlPoint = _calculateControlPoint(start, end, curvature);
        } else {
          // Route non-adjacent edges around the outer side to avoid overlapping intermediate nodes
          final isRightLane = (i % 2 == 0);
          if (isRightLane) {
            final double maxRight = max(fromRect.right, toRect.right) + 32.0 + (i * 10.0);
            start = Offset(fromRect.right + 2.0, fromRect.center.dy);
            end = Offset(toRect.right + 2.0, toRect.center.dy);
            controlPoint = Offset(maxRight, (start.dy + end.dy) / 2);
          } else {
            final double minLeft = min(fromRect.left, toRect.left) - 32.0 - (i * 10.0);
            start = Offset(fromRect.left - 2.0, fromRect.center.dy);
            end = Offset(toRect.left - 2.0, toRect.center.dy);
            controlPoint = Offset(max(44.0, minLeft), (start.dy + end.dy) / 2);
          }
        }

        final rand = Random(edge.fromId.hashCode ^ (edge.toId.hashCode << 4) ^ (i * 1013));
        final edgeColor = edge.color ?? fromNode.color;

        final edgePaint = Paint()
          ..color = edgeColor
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

        _drawCurvedShakyArc(canvas, start, end, controlPoint, edgePaint, rand, style: edge.style);

        // Arrowhead at end using tangent angle from control point
        final angle = atan2(end.dy - controlPoint.dy, end.dx - controlPoint.dx);
        _drawHandDrawnArrowhead(canvas, end, angle, edgePaint, rand);

        // 🛡️ Collision-Free Edge Label Placement Engine (Guarantees zero overlap with nodes or other labels)
        if (edge.label != null && edge.label!.trim().isNotEmpty) {
          final labelText = edge.label!.trim();
          final placed = _drawCollisionFreeEdgeLabel(
            canvas,
            start,
            controlPoint,
            end,
            labelText,
            edgeColor,
            rand,
            nodeRects.values.toList(),
            placedLabelRects,
            size,
          );
          placedLabelRects.add(placed);
        }
      }
    }

    // 3. Draw Hand-Drawn Nodes (Imperfect Shapes & Handwritten Typography)
    for (int i = 0; i < graphData.nodes.length; i++) {
      final node = graphData.nodes[i];
      final rect = nodeRects[node.id];
      if (rect == null) continue;

      final rand = Random(node.id.hashCode ^ (i * 7919));

      final strokeColor = node.color;
      final fillColor = isDark
          ? const Color(0xFF1E293B).withValues(alpha: 0.92)
          : Colors.white.withValues(alpha: 0.94);

      final fillPaint = Paint()
        ..color = fillColor
        ..style = PaintingStyle.fill;

      final borderPaint = Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      // Draw pencil hatching shadow under node shape
      _drawPencilHatching(canvas, rect, rand);

      final lowerShape = node.shape.toLowerCase();

      final isHeart = lowerShape == 'heart';
      final isDatabase = lowerShape == 'cylinder' || lowerShape == 'database';
      final isAnimal = lowerShape == 'animal';
      final isAtom = lowerShape == 'atom';
      final isCircuit = lowerShape == 'circuit';
      final isLeaf = lowerShape == 'leaf';
      final isSolar = lowerShape == 'solar';
      final isBus = lowerShape == 'line' || lowerShape == 'bar' || lowerShape == 'bus';

      if (isHeart) {
        _drawRealAnatomicalHeart(canvas, rect, borderPaint, fillPaint, rand);
      } else if (isDatabase) {
        _drawRealDatabaseCylinder(canvas, rect, borderPaint, fillPaint, rand);
      } else if (lowerShape == 'cylinder') {
        _drawImperfectCylinder(canvas, rect, borderPaint, fillPaint, rand);
      } else if (isAnimal) {
        _drawRealAnimalFigure(canvas, rect, borderPaint, fillPaint, rand);
      } else if (isAtom) {
        _drawRealAtomicOrbital(canvas, rect, borderPaint, fillPaint, rand);
      } else if (isCircuit) {
        _drawRealElectricCircuit(canvas, rect, borderPaint, fillPaint, rand);
      } else if (isLeaf) {
        _drawRealLeafFigure(canvas, rect, borderPaint, fillPaint, rand);
      } else if (isSolar) {
        _drawRealSolarSystem(canvas, rect, borderPaint, fillPaint, rand);
      } else if (isBus) {
        _drawImperfectBusBar(canvas, rect, borderPaint, fillPaint, rand);
      } else if (node.isCircle) {
        _drawImperfectEllipse(canvas, rect.center, rect.width / 2, rect.height / 2, borderPaint, fillPaint, rand);
      } else if (node.isTriangle) {
        _drawImperfectTriangle(canvas, rect, borderPaint, fillPaint, rand);
      } else if (node.isCapsule) {
        _drawImperfectCapsule(canvas, rect, borderPaint, fillPaint, rand);
      } else {
        _drawImperfectBox(canvas, rect, borderPaint, fillPaint, rand);
      }

      // (f) Text Labels: Handwritten typography with subtle uneven alignment
      _drawNodeText(canvas, rect, node, rand);
    }
  }

  // ===========================================================================
  // 📝 NOTEBOOK PAPER BACKGROUND
  // ===========================================================================
  void _drawNotebookPaper(Canvas canvas, Size size) {
    // Paper Fill
    final paperPaint = Paint()
      ..color = isDark ? const Color(0xFF0F172A) : const Color(0xFFFDFBF7)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paperPaint);

    // Subtle Ruled Horizontal Notebook Lines
    final linePaint = Paint()
      ..color = isDark
          ? const Color(0xFF1E293B).withValues(alpha: 0.8)
          : const Color(0xFFE2E8F0).withValues(alpha: 0.7)
      ..strokeWidth = 0.9;

    const double lineSpacing = 26.0;
    for (double y = lineSpacing; y < size.height; y += lineSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // Red Student Notebook Margin Line (Left Vertical Line)
    final marginPaint = Paint()
      ..color = isDark
          ? const Color(0xFFEF4444).withValues(alpha: 0.35)
          : const Color(0xFFF87171).withValues(alpha: 0.45)
      ..strokeWidth = 1.3;
    canvas.drawLine(const Offset(38, 0), Offset(38, size.height), marginPaint);

    // Left Spiral Binding Punch Holes
    final holePaint = Paint()
      ..color = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)
      ..style = PaintingStyle.fill;
    final holeBorder = Paint()
      ..color = isDark ? const Color(0xFF1E293B) : const Color(0xFF94A3B8)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    for (double y = 20; y < size.height; y += 40) {
      canvas.drawCircle(Offset(14, y), 3.5, holePaint);
      canvas.drawCircle(Offset(14, y), 3.5, holeBorder);
    }

    // Bottom Notebook Footer Hint
    final footerPainter = TextPainter(
      text: TextSpan(
        text: '✏️ Scratch Notebook • Tap any concept box to inspect details',
        style: GoogleFonts.indieFlower(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    footerPainter.paint(
      canvas,
      Offset(max(42.0, size.width - footerPainter.width - 12.0), max(10.0, size.height - 18.0)),
    );
  }

  // ===========================================================================
  // 🎨 IMPERFECT SHAPE DRAWING ALGORITHMS
  // ===========================================================================

  /// (b) Circle/Ellipse: Imperfect ellipse with ±2px radius variation
  void _drawImperfectEllipse(
    Canvas canvas,
    Offset center,
    double rx,
    double ry,
    Paint strokePaint,
    Paint fillPaint,
    Random rand,
  ) {
    // 1. Soft Fill
    canvas.drawOval(
        Rect.fromCenter(center: center, width: rx * 2, height: ry * 2), fillPaint);

    // 2. Dual sketch stroke with ±2px radius variation
    for (int pass = 0; pass < 2; pass++) {
      final path = Path();
      const int segments = 24;
      for (int i = 0; i <= segments; i++) {
        final angle = (i * 2 * pi) / segments;
        // ±2px variation in radius
        final jitterX = randomOffset(2.0, rand) + (pass == 1 ? 0.5 : 0.0);
        final jitterY = randomOffset(2.0, rand) + (pass == 1 ? -0.5 : 0.0);
        final curRx = rx + jitterX;
        final curRy = ry + jitterY;
        final x = center.dx + curRx * cos(angle);
        final y = center.dy + curRy * sin(angle);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      // (e) Stroke variation (1.5px - 2.5px) simulating pen pressure
      strokePaint.strokeWidth = 1.6 + randomOffset(0.4, rand) + (pass * 0.2);
      canvas.drawPath(path, strokePaint);
    }
  }

  /// (b) Box: Four separate sides with random offset and corner overshoots
  void _drawImperfectBox(
    Canvas canvas,
    Rect rect,
    Paint strokePaint,
    Paint fillPaint,
    Random rand,
  ) {
    // 1. Fill
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)), fillPaint);

    // 2. Four sides drawn with random offset
    final p1 = rect.topLeft;
    final p2 = rect.topRight;
    final p3 = rect.bottomRight;
    final p4 = rect.bottomLeft;

    _drawShakyLine(canvas, p1, p2, strokePaint, rand);
    _drawShakyLine(canvas, p2, p3, strokePaint, rand);
    _drawShakyLine(canvas, p3, p4, strokePaint, rand);
    _drawShakyLine(canvas, p4, p1, strokePaint, rand);
  }

  /// (b) Triangle: Three points with random jitter
  void _drawImperfectTriangle(
    Canvas canvas,
    Rect rect,
    Paint strokePaint,
    Paint fillPaint,
    Random rand,
  ) {
    // Three points with random jitter
    final p1 = Offset(
        rect.center.dx + randomOffset(2.0, rand), rect.top + randomOffset(2.0, rand));
    final p2 = Offset(rect.right + randomOffset(2.0, rand),
        rect.bottom + randomOffset(2.0, rand));
    final p3 = Offset(rect.left + randomOffset(2.0, rand),
        rect.bottom + randomOffset(2.0, rand));

    final fillPath = Path()
      ..moveTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(p3.dx, p3.dy)
      ..close();
    canvas.drawPath(fillPath, fillPaint);

    _drawShakyLine(canvas, p1, p2, strokePaint, rand);
    _drawShakyLine(canvas, p2, p3, strokePaint, rand);
    _drawShakyLine(canvas, p3, p1, strokePaint, rand);
  }

  /// Capsule / Pill shape with rounded sketch ends
  void _drawImperfectCapsule(
    Canvas canvas,
    Rect rect,
    Paint strokePaint,
    Paint fillPaint,
    Random rand,
  ) {
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2));
    canvas.drawRRect(rrect, fillPaint);

    for (int pass = 0; pass < 2; pass++) {
      final path = Path();
      final r = rect.height / 2;
      final off = (pass == 0 ? 0.0 : 0.8) + randomOffset(0.5, rand);

      path.moveTo(rect.left + r - off, rect.top + (pass * 0.5));
      path.lineTo(rect.right - r + off, rect.top - (pass * 0.5));
      path.arcToPoint(
        Offset(rect.right - r + off, rect.bottom + (pass * 0.5)),
        radius: Radius.circular(r),
        clockwise: true,
      );
      path.lineTo(rect.left + r - off, rect.bottom - (pass * 0.5));
      path.arcToPoint(
        Offset(rect.left + r - off, rect.top + (pass * 0.5)),
        radius: Radius.circular(r),
        clockwise: true,
      );
      strokePaint.strokeWidth = 1.6 + randomOffset(0.4, rand) + (pass * 0.2);
      canvas.drawPath(path, strokePaint);
    }
  }

  /// 1. 🫀 REAL ANATOMICAL HEART FIGURE
  void _drawRealAnatomicalHeart(
    Canvas canvas,
    Rect rect,
    Paint strokePaint,
    Paint fillPaint,
    Random rand,
  ) {
    final center = rect.center;
    final rx = rect.width / 2;
    final ry = rect.height / 2;

    final path = Path();
    path.moveTo(center.dx, center.dy + ry * 0.85);
    path.cubicTo(
      center.dx - rx * 1.1, center.dy + ry * 0.3,
      center.dx - rx * 1.1, center.dy - ry * 0.4,
      center.dx - rx * 0.4, center.dy - ry * 0.6,
    );
    path.quadraticBezierTo(center.dx, center.dy - ry * 0.95, center.dx + rx * 0.4, center.dy - ry * 0.6);
    path.cubicTo(
      center.dx + rx * 1.1, center.dy - ry * 0.4,
      center.dx + rx * 1.1, center.dy + ry * 0.3,
      center.dx, center.dy + ry * 0.85,
    );

    canvas.drawPath(path, fillPaint);
    for (int pass = 0; pass < 2; pass++) {
      strokePaint.strokeWidth = 1.6 + randomOffset(0.3, rand) + (pass * 0.2);
      canvas.drawPath(path, strokePaint);
    }

    _drawShakyLine(canvas, Offset(center.dx - 12, center.dy - ry * 0.6), Offset(center.dx - 12, center.dy - ry * 0.95), strokePaint, rand);
    _drawShakyLine(canvas, Offset(center.dx + 12, center.dy - ry * 0.6), Offset(center.dx + 12, center.dy - ry * 0.95), strokePaint, rand);
    _drawPencilHatching(canvas, Rect.fromCenter(center: Offset(center.dx + 10, center.dy + 10), width: rx * 0.8, height: ry * 0.8), rand);
  }

  /// 2. 🗄️ REAL 3D STACKED DATABASE CYLINDER
  void _drawRealDatabaseCylinder(
    Canvas canvas,
    Rect rect,
    Paint strokePaint,
    Paint fillPaint,
    Random rand,
  ) {
    final double rx = rect.width / 2;
    final double ry = min(14.0, rect.height * 0.22);
    final Offset topCenter = Offset(rect.center.dx, rect.top + ry);
    final Offset bottomCenter = Offset(rect.center.dx, rect.bottom - ry);

    final bodyPath = Path()
      ..addOval(Rect.fromCenter(center: topCenter, width: rx * 2, height: ry * 2))
      ..addRect(Rect.fromLTRB(rect.left, topCenter.dy, rect.right, bottomCenter.dy))
      ..addOval(Rect.fromCenter(center: bottomCenter, width: rx * 2, height: ry * 2));
    canvas.drawPath(bodyPath, fillPaint);

    _drawPencilHatching(canvas, rect, rand);
    _drawImperfectEllipse(canvas, topCenter, rx, ry, strokePaint, fillPaint, rand);
    _drawShakyLine(canvas, Offset(rect.left, topCenter.dy), Offset(rect.left, bottomCenter.dy), strokePaint, rand);
    _drawShakyLine(canvas, Offset(rect.right, topCenter.dy), Offset(rect.right, bottomCenter.dy), strokePaint, rand);

    final double hStep = (bottomCenter.dy - topCenter.dy) / 3;
    for (int d = 1; d <= 2; d++) {
      final diskY = topCenter.dy + d * hStep;
      final diskArcPath = Path();
      const int steps = 14;
      for (int i = 0; i <= steps; i++) {
        final angle = (i * pi) / steps;
        final x = rect.center.dx + rx * cos(angle);
        final y = diskY + ry * sin(angle);
        if (i == 0) {
          diskArcPath.moveTo(x, y);
        } else {
          diskArcPath.lineTo(x, y);
        }
      }
      strokePaint.strokeWidth = 1.4 + randomOffset(0.3, rand);
      canvas.drawPath(diskArcPath, strokePaint);
    }

    final bottomArcPath = Path();
    const int steps = 14;
    for (int i = 0; i <= steps; i++) {
      final angle = (i * pi) / steps;
      final x = bottomCenter.dx + rx * cos(angle);
      final y = bottomCenter.dy + ry * sin(angle);
      if (i == 0) {
        bottomArcPath.moveTo(x, y);
      } else {
        bottomArcPath.lineTo(x, y);
      }
    }
    strokePaint.strokeWidth = 1.6 + randomOffset(0.4, rand);
    canvas.drawPath(bottomArcPath, strokePaint);
  }

  /// 3. 🐕 REAL CANINE / ANIMAL FIGURE
  void _drawRealAnimalFigure(
    Canvas canvas,
    Rect rect,
    Paint strokePaint,
    Paint fillPaint,
    Random rand,
  ) {
    final center = rect.center;
    final rx = rect.width / 2;
    final ry = rect.height / 2;

    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)), fillPaint);

    final path = Path();
    path.moveTo(center.dx - rx * 0.6, center.dy - ry * 0.3);
    path.lineTo(center.dx - rx * 0.9, center.dy - ry * 0.2);
    path.lineTo(center.dx - rx * 0.8, center.dy + ry * 0.1);
    path.lineTo(center.dx - rx * 0.5, center.dy - ry * 0.8);
    path.lineTo(center.dx - rx * 0.2, center.dy - ry * 0.4);
    path.quadraticBezierTo(center.dx + rx * 0.4, center.dy - ry * 0.5, center.dx + rx * 0.8, center.dy - ry * 0.2);
    path.lineTo(center.dx + rx * 0.95, center.dy - ry * 0.7);
    path.lineTo(center.dx + rx * 0.7, center.dy + ry * 0.8);
    path.lineTo(center.dx + rx * 0.5, center.dy + ry * 0.8);
    path.lineTo(center.dx - rx * 0.3, center.dy + ry * 0.8);
    path.lineTo(center.dx - rx * 0.5, center.dy + ry * 0.8);
    path.close();

    _drawPencilHatching(canvas, rect, rand);

    for (int pass = 0; pass < 2; pass++) {
      strokePaint.strokeWidth = 1.5 + randomOffset(0.3, rand);
      canvas.drawPath(path, strokePaint);
    }
  }

  /// 4. ⚛️ REAL ATOMIC ORBITAL FIGURE
  void _drawRealAtomicOrbital(
    Canvas canvas,
    Rect rect,
    Paint strokePaint,
    Paint fillPaint,
    Random rand,
  ) {
    final center = rect.center;
    final rx = rect.width / 2 - 6.0;
    final ry = min(22.0, rect.height / 2 - 6.0);

    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)), fillPaint);
    _drawPencilHatching(canvas, rect, rand);

    canvas.drawCircle(Offset(center.dx - 3, center.dy - 3), 4.5, strokePaint);
    canvas.drawCircle(Offset(center.dx + 3, center.dy - 2), 4.5, strokePaint);
    canvas.drawCircle(Offset(center.dx, center.dy + 3), 4.5, strokePaint);

    _drawImperfectEllipse(canvas, center, rx, ry, strokePaint, fillPaint, rand);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(pi / 3);
    canvas.translate(-center.dx, -center.dy);
    _drawImperfectEllipse(canvas, center, rx, ry, strokePaint, fillPaint, rand);
    canvas.restore();
  }

  /// 5. ⚡ REAL ELECTRIC CIRCUIT LOOP
  void _drawRealElectricCircuit(
    Canvas canvas,
    Rect rect,
    Paint strokePaint,
    Paint fillPaint,
    Random rand,
  ) {
    final innerRect = rect.deflate(10.0);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(10)), fillPaint);
    _drawPencilHatching(canvas, rect, rand);

    _drawImperfectBox(canvas, innerRect, strokePaint, fillPaint, rand);

    final batY = innerRect.center.dy;
    _drawShakyLine(canvas, Offset(innerRect.left - 6, batY - 10), Offset(innerRect.left + 6, batY - 10), strokePaint, rand);
    _drawShakyLine(canvas, Offset(innerRect.left - 12, batY + 10), Offset(innerRect.left + 12, batY + 10), strokePaint, rand);

    final resX = innerRect.center.dx;
    final resY = innerRect.top;
    final zigPath = Path()
      ..moveTo(resX - 20, resY)
      ..lineTo(resX - 12, resY - 6)
      ..lineTo(resX - 4, resY + 6)
      ..lineTo(resX + 4, resY - 6)
      ..lineTo(resX + 12, resY + 6)
      ..lineTo(resX + 20, resY);
    canvas.drawPath(zigPath, strokePaint);
  }

  /// 6. 🍃 REAL PHOTOSYNTHESIS LEAF FIGURE
  void _drawRealLeafFigure(
    Canvas canvas,
    Rect rect,
    Paint strokePaint,
    Paint fillPaint,
    Random rand,
  ) {
    final center = rect.center;
    final rx = rect.width / 2 - 8.0;
    final ry = rect.height / 2 - 8.0;

    final leafPath = Path();
    leafPath.moveTo(center.dx - rx, center.dy);
    leafPath.quadraticBezierTo(center.dx - rx * 0.3, center.dy - ry * 1.2, center.dx + rx, center.dy);
    leafPath.quadraticBezierTo(center.dx - rx * 0.3, center.dy + ry * 1.2, center.dx - rx, center.dy);

    canvas.drawPath(leafPath, fillPaint);
    _drawPencilHatching(canvas, rect, rand);

    for (int pass = 0; pass < 2; pass++) {
      strokePaint.strokeWidth = 1.6 + randomOffset(0.3, rand);
      canvas.drawPath(leafPath, strokePaint);
    }

    _drawShakyLine(canvas, Offset(center.dx - rx, center.dy), Offset(center.dx + rx, center.dy), strokePaint, rand);
  }

  /// 7. 🪐 REAL SOLAR SYSTEM PLANET FIGURE
  void _drawRealSolarSystem(
    Canvas canvas,
    Rect rect,
    Paint strokePaint,
    Paint fillPaint,
    Random rand,
  ) {
    final center = rect.center;
    final r = min(rect.width, rect.height) * 0.32;

    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)), fillPaint);
    _drawPencilHatching(canvas, rect, rand);

    canvas.drawCircle(center, r, fillPaint);
    canvas.drawCircle(center, r, strokePaint);

    final ringRect = Rect.fromCenter(center: center, width: r * 2.8, height: r * 0.85);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.3);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawOval(ringRect, strokePaint);
    canvas.restore();
  }

  /// 3D Cylinder Shape for Storage / Disk Nodes
  void _drawImperfectCylinder(
    Canvas canvas,
    Rect rect,
    Paint strokePaint,
    Paint fillPaint,
    Random rand,
  ) {
    final double rx = rect.width / 2;
    final double ry = min(14.0, rect.height * 0.25);
    final Offset topCenter = Offset(rect.center.dx, rect.top + ry);
    final Offset bottomCenter = Offset(rect.center.dx, rect.bottom - ry);

    // Fill body
    final bodyPath = Path()
      ..addOval(Rect.fromCenter(center: topCenter, width: rx * 2, height: ry * 2))
      ..addRect(Rect.fromLTRB(rect.left, topCenter.dy, rect.right, bottomCenter.dy))
      ..addOval(Rect.fromCenter(center: bottomCenter, width: rx * 2, height: ry * 2));
    canvas.drawPath(bodyPath, fillPaint);

    // Top Ellipse
    _drawImperfectEllipse(canvas, topCenter, rx, ry, strokePaint, fillPaint, rand);

    // Side Verticals
    _drawShakyLine(canvas, Offset(rect.left, topCenter.dy), Offset(rect.left, bottomCenter.dy), strokePaint, rand);
    _drawShakyLine(canvas, Offset(rect.right, topCenter.dy), Offset(rect.right, bottomCenter.dy), strokePaint, rand);

    // Bottom Curved Arc
    final bottomArcPath = Path();
    const int steps = 14;
    for (int i = 0; i <= steps; i++) {
      final angle = (i * pi) / steps;
      final x = bottomCenter.dx + rx * cos(angle);
      final y = bottomCenter.dy + ry * sin(angle);
      if (i == 0) {
        bottomArcPath.moveTo(x, y);
      } else {
        bottomArcPath.lineTo(x, y);
      }
    }
    strokePaint.strokeWidth = 1.6 + randomOffset(0.4, rand);
    canvas.drawPath(bottomArcPath, strokePaint);
  }

  /// Double-Contoured Bus Bar with Inner Hatching
  void _drawImperfectBusBar(
    Canvas canvas,
    Rect rect,
    Paint strokePaint,
    Paint fillPaint,
    Random rand,
  ) {
    canvas.drawRect(rect, fillPaint);
    _drawImperfectBox(canvas, rect, strokePaint, fillPaint, rand);
    _drawPencilHatching(canvas, rect, rand);
  }

  /// Diagonal Pencil Hatching Shadow under Nodes
  void _drawPencilHatching(
    Canvas canvas,
    Rect rect,
    Random rand,
  ) {
    final hatchPaint = Paint()
      ..color = isDark
          ? const Color(0xFF64748B).withValues(alpha: 0.20)
          : const Color(0xFF94A3B8).withValues(alpha: 0.30)
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;

    const double spacing = 6.0;
    final shadowOffset = const Offset(5.0, 5.0);
    final shadowRect = rect.shift(shadowOffset);

    canvas.save();
    canvas.clipRect(shadowRect);

    int idx = 0;
    for (double x = shadowRect.left - shadowRect.height; x < shadowRect.right; x += spacing) {
      idx++;
      final lineRand = Random(rand.nextInt(10000) ^ (idx * 31));
      final jitter1 = randomOffset(0.8, lineRand);
      final jitter2 = randomOffset(0.8, lineRand);

      canvas.drawLine(
        Offset(x + jitter1, shadowRect.bottom + jitter2),
        Offset(x + shadowRect.height - jitter1, shadowRect.top - jitter2),
        hatchPaint,
      );
    }
    canvas.restore();
  }

  /// Calculates quadratic Bezier control point for curved arc connectors
  Offset _calculateControlPoint(Offset start, Offset end, double curvature) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final dist = sqrt(dx * dx + dy * dy);
    if (dist < 1.0) return Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);

    final normX = dx / dist;
    final normY = dy / dist;
    final perpX = -normY;
    final perpY = normX;

    final midX = (start.dx + end.dx) / 2 + perpX * curvature;
    final midY = (start.dy + end.dy) / 2 + perpY * curvature;
    return Offset(midX, midY);
  }

  /// Draws smooth curved arc connectors with shaky double strokes and style support
  void _drawCurvedShakyArc(
    Canvas canvas,
    Offset start,
    Offset end,
    Offset controlPoint,
    Paint strokePaint,
    Random rand, {
    String style = 'solid',
  }) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final dist = sqrt(dx * dx + dy * dy);
    if (dist < 2.0) return;

    final isDashed = style == 'dashed';
    final isWavy = style == 'wavy';

    for (int pass = 0; pass < (isDashed ? 1 : 2); pass++) {
      final path = Path();
      path.moveTo(start.dx, start.dy);

      const int steps = 24;
      bool isDrawingDash = true;
      int dashSegmentCounter = 0;

      for (int i = 1; i <= steps; i++) {
        final t = i / steps;
        var bx = (1 - t) * (1 - t) * start.dx + 2 * (1 - t) * t * controlPoint.dx + t * t * end.dx;
        var by = (1 - t) * (1 - t) * start.dy + 2 * (1 - t) * t * controlPoint.dy + t * t * end.dy;

        if (isWavy) {
          final tangentX = 2 * (1 - t) * (controlPoint.dx - start.dx) + 2 * t * (end.dx - controlPoint.dx);
          final tangentY = 2 * (1 - t) * (controlPoint.dy - start.dy) + 2 * t * (end.dy - controlPoint.dy);
          final tLen = sqrt(tangentX * tangentX + tangentY * tangentY);
          if (tLen > 0.01) {
            final normX = -tangentY / tLen;
            final normY = tangentX / tLen;
            final waveOffset = sin(t * 6 * pi) * 3.5;
            bx += normX * waveOffset;
            by += normY * waveOffset;
          }
        }

        final jitterX = randomOffset(1.5, rand) + (pass == 1 ? 0.4 : 0.0);
        final jitterY = randomOffset(1.5, rand) + (pass == 1 ? -0.4 : 0.0);

        if (isDashed) {
          dashSegmentCounter++;
          if (dashSegmentCounter % 3 == 0) {
            isDrawingDash = !isDrawingDash;
          }
          if (isDrawingDash) {
            path.lineTo(bx + jitterX, by + jitterY);
          } else {
            path.moveTo(bx + jitterX, by + jitterY);
          }
        } else {
          path.lineTo(bx + jitterX, by + jitterY);
        }
      }

      strokePaint.strokeWidth = 1.6 + randomOffset(0.4, rand) + (pass * 0.2);
      canvas.drawPath(path, strokePaint);
    }
  }

  // ===========================================================================
  // 📏 (c) SHAKY LINE & (d) ARROWHEAD DRAWING ALGORITHMS
  // ===========================================================================

  /// (c) Line Drawing: Divides line into small segments with ±2px random offset
  /// and (e) variable stroke width (1.5px–2.5px) for natural pen pressure.
  void _drawShakyLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint strokePaint,
    Random rand, {
    double overshoot = 2.0,
  }) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final dist = sqrt(dx * dx + dy * dy);
    if (dist < 1.0) return;

    final normX = dx / dist;
    final normY = dy / dist;
    final perpX = -normY;
    final perpY = normX;

    // Dual-pass sketching stroke
    for (int pass = 0; pass < 2; pass++) {
      final path = Path();
      final pStart = Offset(
        start.dx - normX * (overshoot + randomOffset(0.8, rand)),
        start.dy - normY * (overshoot + randomOffset(0.8, rand)),
      );
      final pEnd = Offset(
        end.dx + normX * (overshoot + randomOffset(0.8, rand)),
        end.dy + normY * (overshoot + randomOffset(0.8, rand)),
      );

      path.moveTo(pStart.dx, pStart.dy);

      // Divide line into small segments (~12-16px per step)
      final int steps = max(3, (dist / 14.0).round());
      for (int i = 1; i < steps; i++) {
        final t = i / steps;
        final base = Offset(start.dx + dx * t, start.dy + dy * t);
        // ±2px random offset perpendicular to segment
        final jitter = randomOffset(2.0, rand);
        path.lineTo(base.dx + perpX * jitter, base.dy + perpY * jitter);
      }
      path.lineTo(pEnd.dx, pEnd.dy);

      // (e) Stroke variation (1.5px - 2.5px)
      strokePaint.strokeWidth = 1.6 + randomOffset(0.4, rand) + (pass * 0.2);
      canvas.drawPath(path, strokePaint);
    }
  }

  /// (d) Arrowheads: Unequal sides, random tilt angle, and soft inner tint fill
  void _drawHandDrawnArrowhead(
    Canvas canvas,
    Offset tip,
    double angle,
    Paint paint,
    Random rand,
  ) {
    // Random tilt angle (±0.12 radians)
    final randomTilt = randomOffset(0.12, rand);
    final effectiveAngle = angle + randomTilt;

    // Unequal wings (e.g. wing1 ~ 11px, wing2 ~ 8.5px + jitter)
    final wing1Len = 11.0 + randomOffset(1.5, rand);
    final wing2Len = 8.5 + randomOffset(1.5, rand);

    final wing1Angle = effectiveAngle - (pi - 0.40);
    final wing2Angle = effectiveAngle + (pi - 0.46);

    final wing1 = Offset(
      tip.dx + wing1Len * cos(wing1Angle),
      tip.dy + wing1Len * sin(wing1Angle),
    );
    final wing2 = Offset(
      tip.dx + wing2Len * cos(wing2Angle),
      tip.dy + wing2Len * sin(wing2Angle),
    );

    // Soft inner arrowhead wedge tint fill
    final arrowFillPath = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(wing1.dx, wing1.dy)
      ..lineTo(wing2.dx, wing2.dy)
      ..close();
    final arrowFillPaint = Paint()
      ..color = paint.color.withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;
    canvas.drawPath(arrowFillPath, arrowFillPaint);

    _drawShakyLine(canvas, tip, wing1, paint, rand, overshoot: 0.5);
    _drawShakyLine(canvas, tip, wing2, paint, rand, overshoot: 0.5);
  }

  /// (f) Text Labels: Handwritten typography with subtle uneven alignment
  void _drawNodeText(
    Canvas canvas,
    Rect rect,
    HandDrawnNode node,
    Random rand,
  ) {
    final labelStyle = GoogleFonts.patrickHand(
      fontSize: baseFontSize + 1,
      fontWeight: FontWeight.bold,
      color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
      height: 1.15,
    );

    final maxTextWidth = max(10.0, rect.width - 12.0);

    final titlePainter = TextPainter(
      text: TextSpan(text: node.label, style: labelStyle),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 3,
      ellipsis: '...',
    )..layout(maxWidth: maxTextWidth);

    TextPainter? subPainter;
    double totalH = titlePainter.height;

    if (node.subtitle != null && node.subtitle!.isNotEmpty) {
      final subStyle = GoogleFonts.indieFlower(
        fontSize: baseFontSize - 0.5,
        fontWeight: FontWeight.w600,
        color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0369A1),
        height: 1.15,
      );
      subPainter = TextPainter(
        text: TextSpan(text: node.subtitle!, style: subStyle),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        maxLines: 2,
        ellipsis: '...',
      )..layout(maxWidth: maxTextWidth);
      totalH += subPainter.height + 5.0;
    }

    // Subtle uneven alignment (±1.2px offset and ±0.02 rad tilt)
    final offsetX =
        rect.center.dx - titlePainter.width / 2 + randomOffset(1.2, rand);
    final startY = rect.center.dy - totalH / 2 + randomOffset(1.2, rand);
    final tiltAngle = randomOffset(0.02, rand);

    canvas.save();
    canvas.translate(rect.center.dx, rect.center.dy);
    canvas.rotate(tiltAngle);
    canvas.translate(-rect.center.dx, -rect.center.dy);

    titlePainter.paint(canvas, Offset(offsetX, startY));
    if (subPainter != null) {
      final subOffsetX =
          rect.center.dx - subPainter.width / 2 + randomOffset(1.0, rand);
      final subY = startY + titlePainter.height + 4.0;

      final subPillRect = Rect.fromLTWH(
        subOffsetX - 4,
        subY - 1,
        subPainter.width + 8,
        subPainter.height + 2,
      );
      final subPillPaint = Paint()
        ..color = isDark
            ? const Color(0xFF38BDF8).withValues(alpha: 0.14)
            : const Color(0xFFE0F2FE)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
          RRect.fromRectAndRadius(subPillRect, const Radius.circular(5)),
          subPillPaint);

      subPainter.paint(canvas, Offset(subOffsetX, subY));
    }

    canvas.restore();

    // Draw step number badge (e.g. ❶, ❷, ❸) as a floating pin badge at top-left corner
    if (node.stepIndex > 0) {
      final stepStr = _getStepCircleSymbol(node.stepIndex);
      final stepPainter = TextPainter(
        text: TextSpan(
          text: stepStr,
          style: GoogleFonts.outfit(
            fontSize: 11.0,
            fontWeight: FontWeight.bold,
            color: node.color,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final stepBadgeRect = Rect.fromLTWH(
        rect.left - 8,
        rect.top - 8,
        stepPainter.width + 6,
        stepPainter.height + 2,
      );

      final backdrop = Paint()
        ..color = isDark ? const Color(0xFF0F172A) : const Color(0xFFFDFBF7)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(RRect.fromRectAndRadius(stepBadgeRect, const Radius.circular(5)), backdrop);

      stepPainter.paint(canvas, Offset(stepBadgeRect.left + 3, stepBadgeRect.top + 1));
    }
  }

  static String _getStepCircleSymbol(int index) {
    const symbols = ['❶', '❷', '❸', '❹', '❺', '❻', '❼', '❽', '❾', '❿'];
    if (index >= 1 && index <= 10) {
      return symbols[index - 1];
    }
    return '[$index]';
  }

  /// Collision-Free Edge Label Placement Engine probing curve candidate points
  Rect _drawCollisionFreeEdgeLabel(
    Canvas canvas,
    Offset start,
    Offset control,
    Offset end,
    String label,
    Color edgeColor,
    Random rand,
    List<Rect> nodeRects,
    List<Rect> placedLabelRects,
    Size canvasSize,
  ) {
    final labelStyle = GoogleFonts.indieFlower(
      fontSize: baseFontSize - 1.5,
      fontWeight: FontWeight.bold,
      color: edgeColor,
    );

    final textPainter = TextPainter(
      text: TextSpan(text: label, style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    final badgeWidth = textPainter.width + 16.0;
    final badgeHeight = textPainter.height + 8.0;

    bool hasCollision(Rect candidate) {
      for (final nodeRect in nodeRects) {
        if (candidate.overlaps(nodeRect.inflate(6.0))) return true;
      }
      for (final placed in placedLabelRects) {
        if (candidate.overlaps(placed.inflate(8.0))) return true;
      }
      return false;
    }

    final mid05 = _getQuadraticPoint(start, control, end, 0.5);
    final mid035 = _getQuadraticPoint(start, control, end, 0.35);
    final mid065 = _getQuadraticPoint(start, control, end, 0.65);

    final candidatePositions = [
      Offset(mid05.dx + (mid05.dx >= canvasSize.width / 2 ? 18.0 : -18.0), mid05.dy),
      Offset(mid05.dx - (mid05.dx >= canvasSize.width / 2 ? 18.0 : -18.0), mid05.dy),
      Offset(mid035.dx + 16.0, mid035.dy - 12.0),
      Offset(mid065.dx + 16.0, mid065.dy + 12.0),
      Offset(mid05.dx, mid05.dy - 22.0),
      Offset(mid05.dx, mid05.dy + 22.0),
      Offset(control.dx + 22.0, control.dy),
      Offset(control.dx - 22.0, control.dy),
    ];

    Rect? bestRect;
    for (final pos in candidatePositions) {
      final candRect = Rect.fromCenter(
        center: Offset(pos.dx + randomOffset(1.0, rand), pos.dy + randomOffset(1.0, rand)),
        width: badgeWidth,
        height: badgeHeight,
      );
      if (!hasCollision(candRect)) {
        bestRect = candRect;
        break;
      }
    }

    if (bestRect == null) {
      for (double shiftY = 28.0; shiftY <= 140.0; shiftY += 24.0) {
        final c1 = Rect.fromCenter(center: Offset(mid05.dx, mid05.dy - shiftY), width: badgeWidth, height: badgeHeight);
        if (!hasCollision(c1)) { bestRect = c1; break; }
        final c2 = Rect.fromCenter(center: Offset(mid05.dx, mid05.dy + shiftY), width: badgeWidth, height: badgeHeight);
        if (!hasCollision(c2)) { bestRect = c2; break; }
      }
    }

    bestRect ??= Rect.fromCenter(
      center: candidatePositions[0],
      width: badgeWidth,
      height: badgeHeight,
    );

    _drawBadgeBox(canvas, bestRect, textPainter, edgeColor, rand);
    return bestRect;
  }

  static Offset _getQuadraticPoint(Offset p0, Offset p1, Offset p2, double t) {
    final oneMinusT = 1.0 - t;
    final x = oneMinusT * oneMinusT * p0.dx + 2 * oneMinusT * t * p1.dx + t * t * p2.dx;
    final y = oneMinusT * oneMinusT * p0.dy + 2 * oneMinusT * t * p1.dy + t * t * p2.dy;
    return Offset(x, y);
  }

  void _drawBadgeBox(
    Canvas canvas,
    Rect badgeRect,
    TextPainter textPainter,
    Color edgeColor,
    Random rand,
  ) {
    final backdropPaint = Paint()
      ..color = isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFFDFBF7)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
        RRect.fromRectAndRadius(badgeRect, const Radius.circular(6)), backdropPaint);

    final fillPaint = Paint()
      ..color = isDark
          ? edgeColor.withValues(alpha: 0.20)
          : edgeColor.withValues(alpha: 0.14)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
        RRect.fromRectAndRadius(badgeRect, const Radius.circular(6)), fillPaint);

    final borderPaint = Paint()
      ..color = edgeColor
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke;
    _drawImperfectBox(canvas, badgeRect, borderPaint, fillPaint, rand);

    textPainter.paint(
      canvas,
      Offset(badgeRect.center.dx - textPainter.width / 2,
          badgeRect.center.dy - textPainter.height / 2),
    );
  }

  /// Calculates boundary contact point on node perimeter towards targetCenter
  Offset _boundaryPoint(Rect rect, String shape, Offset targetCenter) {
    final dx = targetCenter.dx - rect.center.dx;
    final dy = targetCenter.dy - rect.center.dy;
    final angle = atan2(dy, dx);

    if (shape == 'circle' || shape == 'ellipse') {
      final rx = rect.width / 2 + 3.0;
      final ry = rect.height / 2 + 3.0;
      return Offset(
          rect.center.dx + rx * cos(angle), rect.center.dy + ry * sin(angle));
    }

    // Box or Triangle bounding perimeter
    final scaleX = (rect.width / 2 + 3.0) / max(0.001, dx.abs());
    final scaleY = (rect.height / 2 + 3.0) / max(0.001, dy.abs());
    final scale = min(scaleX, scaleY);
    return Offset(rect.center.dx + dx * scale, rect.center.dy + dy * scale);
  }

  @override
  bool shouldRepaint(covariant _RoughNotebookPainter oldDelegate) {
    return oldDelegate.graphData != graphData ||
        oldDelegate.isDark != isDark ||
        oldDelegate.baseFontSize != baseFontSize;
  }
}
