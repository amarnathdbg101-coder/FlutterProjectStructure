import 'dart:math' as math;
import 'package:flutter/material.dart';

class DiagramNodeModel {
  final String id;
  final String label;
  final String description;
  final String nodeType; // "root", "branch", "leaf"
  final String colorHex;
  final List<String> formulas;

  final String branchId;
  final String domainType;
  final String keyTakeaway;
  final String examTrap;
  final int importance; // 1 to 5
  final String badge;
  final Map<String, String> metrics;
  final String codeSnippet;
  final List<String> crossLinks;

  // Layout & Interaction state
  double x;
  double y;
  double width;
  double height;
  bool isCollapsed;
  bool isVisible;

  DiagramNodeModel({
    required this.id,
    required this.label,
    this.description = '',
    this.nodeType = 'leaf',
    this.colorHex = '#4F46E5',
    this.formulas = const [],
    this.branchId = '',
    this.domainType = 'general',
    this.keyTakeaway = '',
    this.examTrap = '',
    this.importance = 3,
    this.badge = '',
    this.metrics = const {},
    this.codeSnippet = '',
    this.crossLinks = const [],
    this.x = 0,
    this.y = 0,
    this.width = 160,
    this.height = 54,
    this.isCollapsed = false,
    this.isVisible = true,
  });

  bool get isRoot => nodeType == 'root';
  bool get isBranch => nodeType == 'branch';
  bool get isLeaf => nodeType == 'leaf';

  factory DiagramNodeModel.fromJson(Map<String, dynamic> json) {
    List<String> parseList(dynamic raw) {
      if (raw is List) {
        return raw.map((e) => e.toString()).toList();
      }
      return [];
    }

    Map<String, String> parseMetrics(dynamic raw) {
      if (raw is Map) {
        return raw.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
      return {};
    }

    final rawType = (json['node_type'] ?? json['type'] ?? json['shape'] ?? 'leaf').toString().toLowerCase();
    String type = 'leaf';
    if (rawType.contains('root') || rawType == 'circle') {
      type = 'root';
    } else if (rawType.contains('branch') || rawType == 'diamond') {
      type = 'branch';
    }

    double w = 165;
    double h = 54;
    if (type == 'root') {
      w = 195;
      h = 62;
    } else if (type == 'branch') {
      w = 175;
      h = 56;
    }

    int imp = 3;
    final rawImp = json['importance'];
    if (rawImp is int) {
      imp = rawImp.clamp(1, 5);
    } else if (rawImp is num) {
      imp = rawImp.toInt().clamp(1, 5);
    }

    return DiagramNodeModel(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? (json['title']?.toString() ?? 'Concept'),
      description: json['description']?.toString() ?? (json['details']?.toString() ?? (json['subtitle']?.toString() ?? '')),
      nodeType: type,
      colorHex: json['color_hex']?.toString() ?? (type == 'root' ? '#4F46E5' : (type == 'branch' ? '#0EA5E9' : '#10B981')),
      formulas: parseList(json['formulas']),
      branchId: json['branch_id']?.toString() ?? '',
      domainType: json['domain_type']?.toString() ?? 'general',
      keyTakeaway: json['key_takeaway']?.toString() ?? '',
      examTrap: json['exam_trap']?.toString() ?? '',
      importance: imp,
      badge: json['badge']?.toString() ?? '',
      metrics: parseMetrics(json['metrics']),
      codeSnippet: json['code_snippet']?.toString() ?? '',
      crossLinks: parseList(json['cross_links']),
      width: w,
      height: h,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'description': description,
    'node_type': nodeType,
    'color_hex': colorHex,
    'formulas': formulas,
    'branch_id': branchId,
    'domain_type': domainType,
    'key_takeaway': keyTakeaway,
    'exam_trap': examTrap,
    'importance': importance,
    'badge': badge,
    'metrics': metrics,
    'code_snippet': codeSnippet,
    'cross_links': crossLinks,
    'is_collapsed': isCollapsed,
  };
}

class DiagramEdgeModel {
  final String fromId;
  final String toId;
  final String label;
  final bool isCrossLink;
  final String style;

  DiagramEdgeModel({
    required this.fromId,
    required this.toId,
    this.label = '',
    this.isCrossLink = false,
    this.style = 'solid',
  });

  factory DiagramEdgeModel.fromJson(Map<String, dynamic> json) {
    final from = json['from_id']?.toString() ??
        (json['from']?.toString() ?? (json['source']?.toString() ?? ''));
    final to = json['to_id']?.toString() ??
        (json['to']?.toString() ?? (json['target']?.toString() ?? ''));

    return DiagramEdgeModel(
      fromId: from,
      toId: to,
      label: json['label']?.toString() ?? '',
      isCrossLink: json['is_cross_link'] == true,
      style: json['style']?.toString() ?? (json['is_cross_link'] == true ? 'dashed' : 'solid'),
    );
  }

  Map<String, dynamic> toJson() => {
    'from_id': fromId,
    'to_id': toId,
    'label': label,
    'is_cross_link': isCrossLink,
    'style': style,
  };
}

enum MindMapLayoutStyle {
  radial,
  horizontal,
  vertical,
}

class DiagramModel {
  String? id;
  final String title;
  final String diagramType;
  final String domainType;
  bool isPinned;
  MindMapLayoutStyle layoutStyle;
  bool isCustomPositions;
  final List<DiagramNodeModel> nodes;
  final List<DiagramEdgeModel> edges;

  DiagramModel({
    this.id,
    required this.title,
    this.diagramType = 'mindmap',
    this.domainType = 'general',
    this.isPinned = false,
    this.layoutStyle = MindMapLayoutStyle.radial,
    this.isCustomPositions = false,
    required this.nodes,
    required this.edges,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'concept': title,
    'diagram_type': diagramType,
    'domain_type': domainType,
    'nodes': nodes.map((n) => n.toJson()).toList(),
    'edges': edges.map((e) => e.toJson()).toList(),
  };

  factory DiagramModel.fromJson(Map<String, dynamic> json) {
    final payload = (json['data'] is Map<String, dynamic>)
        ? json['data'] as Map<String, dynamic>
        : (json['data'] is Map ? Map<String, dynamic>.from(json['data'] as Map) : json);

    final id = json['id']?.toString();
    final isPinned = json['is_pinned'] == true;
    final title = json['title'] as String? ??
        (payload['title'] as String? ??
            (json['concept'] as String? ??
                (payload['concept'] as String? ?? 'Mind Map')));
    final diagramType = json['diagram_type'] as String? ??
        (payload['diagram_type'] as String? ?? 'mindmap');
    final domainType = json['domain_type'] as String? ??
        (payload['domain_type'] as String? ?? 'general');

    final List<DiagramNodeModel> parsedNodes = [];
    final List<DiagramEdgeModel> parsedEdges = [];

    // 1. If hierarchical "root" is present, extract all nodes and edges from the tree
    if (payload['root'] is Map) {
      final rootMap = Map<String, dynamic>.from(payload['root'] as Map);
      _extractTreeNodesAndEdges(rootMap, parsedNodes, parsedEdges, null, 0, '');
    }

    // 2. If flat "nodes" list is present, add any nodes that weren't already added
    final rawNodes = payload['nodes'] ?? json['nodes'];
    if (rawNodes is List) {
      for (final n in rawNodes) {
        if (n is Map) {
          final node = DiagramNodeModel.fromJson(Map<String, dynamic>.from(n));
          if (!parsedNodes.any((existing) => existing.id == node.id)) {
            parsedNodes.add(node);
          }
        }
      }
    }

    // 3. If flat "edges" list is present, add any edges that weren't already added
    final rawEdges = payload['edges'] ?? json['edges'];
    if (rawEdges is List) {
      for (final e in rawEdges) {
        if (e is Map) {
          final edge = DiagramEdgeModel.fromJson(Map<String, dynamic>.from(e));
          if (!parsedEdges.any((existing) => existing.fromId == edge.fromId && existing.toId == edge.toId)) {
            parsedEdges.add(edge);
          }
        }
      }
    }

    // If no root was marked, designate the first node as root
    if (parsedNodes.isNotEmpty && !parsedNodes.any((n) => n.isRoot)) {
      final first = parsedNodes.first;
      parsedNodes[0] = DiagramNodeModel(
        id: first.id,
        label: first.label,
        description: first.description,
        nodeType: 'root',
        colorHex: first.colorHex,
        formulas: first.formulas,
        branchId: first.branchId,
        domainType: first.domainType,
        keyTakeaway: first.keyTakeaway,
        examTrap: first.examTrap,
        importance: first.importance,
        badge: first.badge,
        metrics: first.metrics,
        codeSnippet: first.codeSnippet,
        crossLinks: first.crossLinks,
        width: 195,
        height: 62,
      );
    }

    return DiagramModel(
      id: id,
      title: title,
      diagramType: diagramType,
      domainType: domainType,
      isPinned: isPinned,
      nodes: parsedNodes,
      edges: parsedEdges,
    );
  }

  static void _extractTreeNodesAndEdges(
    Map<String, dynamic> treeNode,
    List<DiagramNodeModel> nodes,
    List<DiagramEdgeModel> edges,
    String? parentId,
    int depth,
    String currentBranchId,
  ) {
    final id = treeNode['id']?.toString() ?? 'node_${nodes.length + 1}';
    final label = treeNode['label']?.toString() ?? (treeNode['title']?.toString() ?? 'Concept');
    final details = treeNode['details']?.toString() ?? (treeNode['description']?.toString() ?? '');
    final color = treeNode['color_hex']?.toString() ??
        (depth == 0 ? '#4F46E5' : (depth == 1 ? '#0EA5E9' : '#10B981'));

    final nodeType = depth == 0 ? 'root' : (depth == 1 ? 'branch' : 'leaf');
    final branchId = depth == 1 ? id : (depth > 1 ? currentBranchId : '');

    List<String> formulas = [];
    final rawFormulas = treeNode['formulas'];
    if (rawFormulas is List) {
      formulas = rawFormulas.map((e) => e.toString()).toList();
    }

    Map<String, String> metrics = {};
    final rawMetrics = treeNode['metrics'];
    if (rawMetrics is Map) {
      metrics = rawMetrics.map((k, v) => MapEntry(k.toString(), v.toString()));
    }

    List<String> crossLinks = [];
    final rawCross = treeNode['cross_links'];
    if (rawCross is List) {
      crossLinks = rawCross.map((e) => e.toString()).toList();
    }

    int imp = 3;
    final rawImp = treeNode['importance'];
    if (rawImp is int) {
      imp = rawImp.clamp(1, 5);
    } else if (rawImp is num) {
      imp = rawImp.toInt().clamp(1, 5);
    }

    nodes.add(DiagramNodeModel(
      id: id,
      label: label,
      description: details,
      nodeType: nodeType,
      colorHex: color,
      formulas: formulas,
      branchId: branchId,
      domainType: treeNode['domain_type']?.toString() ?? 'general',
      keyTakeaway: treeNode['key_takeaway']?.toString() ?? '',
      examTrap: treeNode['exam_trap']?.toString() ?? '',
      importance: imp,
      badge: treeNode['badge']?.toString() ?? '',
      metrics: metrics,
      codeSnippet: treeNode['code_snippet']?.toString() ?? '',
      crossLinks: crossLinks,
      width: depth == 0 ? 195 : (depth == 1 ? 175 : 160),
      height: depth == 0 ? 62 : (depth == 1 ? 56 : 50),
    ));

    if (parentId != null && parentId.isNotEmpty) {
      edges.add(DiagramEdgeModel(
        fromId: parentId,
        toId: id,
        label: depth == 1 ? 'Branches into' : 'Includes',
      ));
    }

    // Cross-links
    for (final targetId in crossLinks) {
      if (targetId.isNotEmpty) {
        edges.add(DiagramEdgeModel(
          fromId: id,
          toId: targetId,
          label: 'Relates to',
          isCrossLink: true,
          style: 'dashed',
        ));
      }
    }

    final children = treeNode['children'];
    if (children is List) {
      for (final child in children) {
        if (child is Map) {
          _extractTreeNodesAndEdges(
            Map<String, dynamic>.from(child),
            nodes,
            edges,
            id,
            depth + 1,
            branchId,
          );
        }
      }
    }
  }

  /// Computes geometric layout coordinates and handles branch folding/expansion
  void calculateLayout(Size canvasSize, {MindMapLayoutStyle? style}) {
    if (nodes.isEmpty) return;
    if (style != null) {
      layoutStyle = style;
    }
    isCustomPositions = false;

    // Map parent -> children (excluding cross-links)
    final Map<String, List<DiagramNodeModel>> childrenMap = {};
    for (final edge in edges) {
      if (edge.isCrossLink) continue;
      final child = nodes.firstWhere(
        (n) => n.id == edge.toId,
        orElse: () => DiagramNodeModel(id: '', label: ''),
      );
      if (child.id.isNotEmpty) {
        childrenMap.putIfAbsent(edge.fromId, () => []).add(child);
      }
    }

    // Find root node
    final rootIndex = nodes.indexWhere((n) => n.isRoot);
    final root = rootIndex != -1 ? nodes[rootIndex] : nodes.first;
    root.isVisible = true;

    switch (layoutStyle) {
      case MindMapLayoutStyle.radial:
        _calculateRadialLayout(canvasSize, root, childrenMap);
        break;
      case MindMapLayoutStyle.horizontal:
        _calculateHorizontalLayout(canvasSize, root, childrenMap);
        break;
      case MindMapLayoutStyle.vertical:
        _calculateVerticalLayout(canvasSize, root, childrenMap);
        break;
    }
  }

  void _calculateRadialLayout(
    Size canvasSize,
    DiagramNodeModel root,
    Map<String, List<DiagramNodeModel>> childrenMap,
  ) {
    final centerX = canvasSize.width / 2;
    final centerY = canvasSize.height / 2;
    root.x = centerX - (root.width / 2);
    root.y = centerY - (root.height / 2);

    final branches = childrenMap[root.id] ?? nodes.where((n) => n.id != root.id && n.isBranch).toList();
    final branchCount = branches.length;
    const branchRadius = 280.0;

    for (int i = 0; i < branchCount; i++) {
      final angle = (2 * math.pi * i) / (branchCount > 0 ? branchCount : 1);
      final bx = centerX + branchRadius * math.cos(angle);
      final by = centerY + branchRadius * math.sin(angle);
      final branch = branches[i];
      branch.isVisible = true;
      branch.x = bx - (branch.width / 2);
      branch.y = by - (branch.height / 2);

      final leaves = childrenMap[branch.id] ?? [];
      final leafCount = leaves.length;

      for (int j = 0; j < leafCount; j++) {
        final leaf = leaves[j];
        if (branch.isCollapsed) {
          leaf.isVisible = false;
          leaf.x = bx;
          leaf.y = by;
          continue;
        }

        leaf.isVisible = true;
        final leafRadius = (j % 2 == 0) ? 180.0 : 240.0;
        final spreadAngle = leafCount > 1
            ? angle - 0.50 + (1.0 * j / (leafCount - 1))
            : angle;
        final lx = bx + leafRadius * math.cos(spreadAngle);
        final ly = by + leafRadius * math.sin(spreadAngle);
        leaf.x = lx - (leaf.width / 2);
        leaf.y = ly - (leaf.height / 2);

        final subLeaves = childrenMap[leaf.id] ?? [];
        for (int k = 0; k < subLeaves.length; k++) {
          final subLeaf = subLeaves[k];
          if (!leaf.isVisible) {
            subLeaf.isVisible = false;
            continue;
          }
          subLeaf.isVisible = true;
          final subAngle = spreadAngle - 0.40 + (0.80 * k / (subLeaves.length > 1 ? subLeaves.length - 1 : 1));
          const subDist = 145.0;
          subLeaf.x = lx + subDist * math.cos(subAngle) - (subLeaf.width / 2);
          subLeaf.y = ly + subDist * math.sin(subAngle) - (subLeaf.height / 2);
        }
      }
    }

    _placeUnconnectedNodes(canvasSize, root);
  }

  void _calculateHorizontalLayout(
    Size canvasSize,
    DiagramNodeModel root,
    Map<String, List<DiagramNodeModel>> childrenMap,
  ) {
    final centerX = canvasSize.width / 2;
    final centerY = canvasSize.height / 2;
    root.x = centerX - (root.width / 2);
    root.y = centerY - (root.height / 2);

    final branches = childrenMap[root.id] ?? nodes.where((n) => n.id != root.id && n.isBranch).toList();
    final branchCount = branches.length;
    if (branchCount == 0) return;

    final rightBranches = <DiagramNodeModel>[];
    final leftBranches = <DiagramNodeModel>[];

    for (int i = 0; i < branchCount; i++) {
      if (i % 2 == 0) {
        rightBranches.add(branches[i]);
      } else {
        leftBranches.add(branches[i]);
      }
    }

    // Layout Right-hand side branches
    _layoutHorizontalSide(
      branches: rightBranches,
      isRight: true,
      root: root,
      centerX: centerX,
      centerY: centerY,
      childrenMap: childrenMap,
    );

    // Layout Left-hand side branches
    _layoutHorizontalSide(
      branches: leftBranches,
      isRight: false,
      root: root,
      centerX: centerX,
      centerY: centerY,
      childrenMap: childrenMap,
    );

    _placeUnconnectedNodes(canvasSize, root);
  }

  void _layoutHorizontalSide({
    required List<DiagramNodeModel> branches,
    required bool isRight,
    required DiagramNodeModel root,
    required double centerX,
    required double centerY,
    required Map<String, List<DiagramNodeModel>> childrenMap,
  }) {
    final count = branches.length;
    if (count == 0) return;

    const verticalSpacing = 160.0;
    final totalHeight = (count - 1) * verticalSpacing;
    final startY = centerY - (totalHeight / 2);

    for (int i = 0; i < count; i++) {
      final branch = branches[i];
      branch.isVisible = true;
      final bx = isRight
          ? (centerX + 190.0)
          : (centerX - 190.0 - branch.width);
      final by = startY + (i * verticalSpacing) - (branch.height / 2);
      branch.x = bx;
      branch.y = by;

      final leaves = childrenMap[branch.id] ?? [];
      final leafCount = leaves.length;

      for (int j = 0; j < leafCount; j++) {
        final leaf = leaves[j];
        if (branch.isCollapsed) {
          leaf.isVisible = false;
          leaf.x = bx;
          leaf.y = by;
          continue;
        }
        leaf.isVisible = true;

        const leafSpacing = 72.0;
        final leavesTotalHeight = (leafCount - 1) * leafSpacing;
        final leafStartY = by + (branch.height / 2) - (leavesTotalHeight / 2) - (leaf.height / 2);

        final lx = isRight
            ? (bx + branch.width + 90.0)
            : (bx - 90.0 - leaf.width);
        final ly = leafStartY + (j * leafSpacing);
        leaf.x = lx;
        leaf.y = ly;

        final subLeaves = childrenMap[leaf.id] ?? [];
        for (int k = 0; k < subLeaves.length; k++) {
          final subLeaf = subLeaves[k];
          if (!leaf.isVisible) {
            subLeaf.isVisible = false;
            continue;
          }
          subLeaf.isVisible = true;
          final sx = isRight ? (lx + leaf.width + 70.0) : (lx - 70.0 - subLeaf.width);
          final sy = ly + ((k - (subLeaves.length - 1) / 2) * 60.0);
          subLeaf.x = sx;
          subLeaf.y = sy;
        }
      }
    }
  }

  void _calculateVerticalLayout(
    Size canvasSize,
    DiagramNodeModel root,
    Map<String, List<DiagramNodeModel>> childrenMap,
  ) {
    final centerX = canvasSize.width / 2;
    root.x = centerX - (root.width / 2);
    root.y = 80;

    final branches = childrenMap[root.id] ?? nodes.where((n) => n.id != root.id && n.isBranch).toList();
    final branchCount = branches.length;
    if (branchCount == 0) return;

    final branchStep = canvasSize.width / (branchCount + 1);

    for (int i = 0; i < branchCount; i++) {
      final branch = branches[i];
      branch.isVisible = true;
      final bx = (i + 1) * branchStep - (branch.width / 2);
      const by = 260.0;
      branch.x = bx;
      branch.y = by;

      final leaves = childrenMap[branch.id] ?? [];
      final leafCount = leaves.length;

      for (int j = 0; j < leafCount; j++) {
        final leaf = leaves[j];
        if (branch.isCollapsed) {
          leaf.isVisible = false;
          leaf.x = bx;
          leaf.y = by;
          continue;
        }
        leaf.isVisible = true;
        leaf.x = bx;
        leaf.y = by + 120.0 + (j * 78.0);

        final subLeaves = childrenMap[leaf.id] ?? [];
        for (int k = 0; k < subLeaves.length; k++) {
          final subLeaf = subLeaves[k];
          subLeaf.isVisible = true;
          subLeaf.x = bx + (k % 2 == 0 ? 110.0 : -110.0);
          subLeaf.y = leaf.y + 40.0;
        }
      }
    }

    _placeUnconnectedNodes(canvasSize, root);
  }

  void _placeUnconnectedNodes(Size canvasSize, DiagramNodeModel root) {
    final centerX = canvasSize.width / 2;
    final centerY = canvasSize.height / 2;
    for (final node in nodes) {
      if (node.x == 0 && node.y == 0 && node.id != root.id) {
        final randomAngle = math.Random(node.id.hashCode).nextDouble() * 2 * math.pi;
        node.isVisible = true;
        node.x = centerX + 440 * math.cos(randomAngle);
        node.y = centerY + 440 * math.sin(randomAngle);
      }
    }
  }

  /// Translates a node and optionally its whole subtree by [delta]
  void moveNode(String nodeId, Offset delta, {bool moveSubtree = true}) {
    final target = nodes.firstWhere(
      (n) => n.id == nodeId,
      orElse: () => DiagramNodeModel(id: '', label: ''),
    );
    if (target.id.isEmpty) return;

    isCustomPositions = true;
    target.x += delta.dx;
    target.y += delta.dy;

    if (moveSubtree) {
      final Set<String> visited = {nodeId};
      final List<String> queue = [nodeId];

      while (queue.isNotEmpty) {
        final currentId = queue.removeAt(0);
        for (final edge in edges) {
          if (edge.isCrossLink) continue;
          if (edge.fromId == currentId && !visited.contains(edge.toId)) {
            visited.add(edge.toId);
            queue.add(edge.toId);
            final child = nodes.firstWhere(
              (n) => n.id == edge.toId,
              orElse: () => DiagramNodeModel(id: '', label: ''),
            );
            if (child.id.isNotEmpty) {
              child.x += delta.dx;
              child.y += delta.dy;
            }
          }
        }
      }
    }
  }
}

class SavedMindMapSummaryModel {
  final String id;
  final String title;
  final String concept;
  final String diagramType;
  final String domainType;
  final String? noteId;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime updatedAt;

  SavedMindMapSummaryModel({
    required this.id,
    required this.title,
    required this.concept,
    this.diagramType = 'mindmap',
    this.domainType = 'general',
    this.noteId,
    this.isPinned = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SavedMindMapSummaryModel.fromJson(Map<String, dynamic> json) {
    return SavedMindMapSummaryModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      concept: json['concept']?.toString() ?? '',
      diagramType: json['diagram_type']?.toString() ?? 'mindmap',
      domainType: json['domain_type']?.toString() ?? 'general',
      noteId: json['note_id']?.toString(),
      isPinned: json['is_pinned'] == true,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

