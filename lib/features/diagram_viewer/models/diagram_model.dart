import 'dart:math' as math;
import 'package:flutter/material.dart';

class DiagramNodeModel {
  final String id;
  final String label;
  final String description;
  final String nodeType; // "root", "branch", "leaf"
  final String colorHex;
  final List<String> formulas;

  // Layout coordinates (calculated by layout engine)
  double x;
  double y;
  double width;
  double height;

  DiagramNodeModel({
    required this.id,
    required this.label,
    this.description = '',
    this.nodeType = 'leaf',
    this.colorHex = '#4F46E5',
    this.formulas = const [],
    this.x = 0,
    this.y = 0,
    this.width = 160,
    this.height = 50,
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

    final rawType = (json['node_type'] ?? json['type'] ?? json['shape'] ?? 'leaf').toString().toLowerCase();
    String type = 'leaf';
    if (rawType.contains('root') || rawType == 'circle') {
      type = 'root';
    } else if (rawType.contains('branch') || rawType == 'diamond') {
      type = 'branch';
    }

    double w = 150;
    double h = 48;
    if (type == 'root') {
      w = 180;
      h = 56;
    } else if (type == 'branch') {
      w = 160;
      h = 50;
    }

    return DiagramNodeModel(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? (json['title']?.toString() ?? 'Concept'),
      description: json['description']?.toString() ?? (json['details']?.toString() ?? (json['subtitle']?.toString() ?? '')),
      nodeType: type,
      colorHex: json['color_hex']?.toString() ?? (type == 'root' ? '#4F46E5' : (type == 'branch' ? '#0EA5E9' : '#10B981')),
      formulas: parseList(json['formulas']),
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
  };
}

class DiagramEdgeModel {
  final String fromId;
  final String toId;
  final String label;

  DiagramEdgeModel({
    required this.fromId,
    required this.toId,
    this.label = '',
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
    );
  }

  Map<String, dynamic> toJson() => {
    'from_id': fromId,
    'to_id': toId,
    'label': label,
  };
}

class DiagramModel {
  final String title;
  final String diagramType;
  final List<DiagramNodeModel> nodes;
  final List<DiagramEdgeModel> edges;

  DiagramModel({
    required this.title,
    this.diagramType = 'mindmap',
    required this.nodes,
    required this.edges,
  });

  factory DiagramModel.fromJson(Map<String, dynamic> json) {
    final title = json['title'] as String? ?? (json['concept'] as String? ?? 'Mind Map');
    final diagramType = json['diagram_type'] as String? ?? 'mindmap';

    final List<DiagramNodeModel> parsedNodes = [];
    final List<DiagramEdgeModel> parsedEdges = [];

    // 1. If hierarchical "root" is present, extract all nodes and edges from the tree!
    if (json['root'] is Map) {
      final rootMap = Map<String, dynamic>.from(json['root'] as Map);
      _extractTreeNodesAndEdges(rootMap, parsedNodes, parsedEdges, null, 0);
    }

    // 2. If flat "nodes" list is present, add any nodes that weren't already added
    final rawNodes = json['nodes'];
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
    final rawEdges = json['edges'];
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
        width: 180,
        height: 56,
      );
    }

    return DiagramModel(
      title: title,
      diagramType: diagramType,
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
  ) {
    final id = treeNode['id']?.toString() ?? 'node_${nodes.length + 1}';
    final label = treeNode['label']?.toString() ?? (treeNode['title']?.toString() ?? 'Concept');
    final details = treeNode['details']?.toString() ?? (treeNode['description']?.toString() ?? '');
    final color = treeNode['color_hex']?.toString() ??
        (depth == 0 ? '#4F46E5' : (depth == 1 ? '#0EA5E9' : '#10B981'));

    final nodeType = depth == 0 ? 'root' : (depth == 1 ? 'branch' : 'leaf');

    nodes.add(DiagramNodeModel(
      id: id,
      label: label,
      description: details,
      nodeType: nodeType,
      colorHex: color,
      formulas: [],
      width: depth == 0 ? 180 : (depth == 1 ? 160 : 140),
      height: depth == 0 ? 56 : (depth == 1 ? 50 : 44),
    ));

    if (parentId != null && parentId.isNotEmpty) {
      edges.add(DiagramEdgeModel(
        fromId: parentId,
        toId: id,
        label: depth == 1 ? 'Branches into' : 'Includes',
      ));
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
          );
        }
      }
    }
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'diagram_type': diagramType,
    'nodes': nodes.map((n) => n.toJson()).toList(),
    'edges': edges.map((e) => e.toJson()).toList(),
  };

  /// Computes geometric layout coordinates for all nodes in the diagram
  void calculateLayout(Size canvasSize) {
    if (nodes.isEmpty) return;

    final centerX = canvasSize.width / 2;
    final centerY = canvasSize.height / 2;

    // Find root node
    final rootIndex = nodes.indexWhere((n) => n.isRoot);
    final root = rootIndex != -1 ? nodes[rootIndex] : nodes.first;
    root.x = centerX - (root.width / 2);
    root.y = centerY - (root.height / 2);

    // Map parent -> children
    final Map<String, List<DiagramNodeModel>> childrenMap = {};
    for (final edge in edges) {
      final child = nodes.firstWhere(
        (n) => n.id == edge.toId,
        orElse: () => DiagramNodeModel(id: '', label: ''),
      );
      if (child.id.isNotEmpty && child.id != root.id) {
        childrenMap.putIfAbsent(edge.fromId, () => []).add(child);
      }
    }

    // Direct children of root (Branches)
    final branches = childrenMap[root.id] ?? nodes.where((n) => n.id != root.id && n.isBranch).toList();
    final branchCount = branches.length;
    const branchRadius = 260.0;

    for (int i = 0; i < branchCount; i++) {
      final angle = (2 * math.pi * i) / (branchCount > 0 ? branchCount : 1);
      final bx = centerX + branchRadius * math.cos(angle);
      final by = centerY + branchRadius * math.sin(angle);
      final branch = branches[i];
      branch.x = bx - (branch.width / 2);
      branch.y = by - (branch.height / 2);

      // Leaves of this branch
      final leaves = childrenMap[branch.id] ?? [];
      final leafCount = leaves.length;
      const leafRadius = 170.0;

      for (int j = 0; j < leafCount; j++) {
        // Spread leaves in an arc facing outwards from root
        final spreadAngle = leafCount > 1
            ? angle - 0.45 + (0.9 * j / (leafCount - 1))
            : angle;
        final lx = bx + leafRadius * math.cos(spreadAngle);
        final ly = by + leafRadius * math.sin(spreadAngle);
        final leaf = leaves[j];
        leaf.x = lx - (leaf.width / 2);
        leaf.y = ly - (leaf.height / 2);
      }
    }

    // Safety fallback for any unconnected nodes: place in an outer orbit
    for (final node in nodes) {
      if (node.x == 0 && node.y == 0 && node.id != root.id) {
        final randomAngle = math.Random(node.id.hashCode).nextDouble() * 2 * math.pi;
        node.x = centerX + 400 * math.cos(randomAngle);
        node.y = centerY + 400 * math.sin(randomAngle);
      }
    }
  }
}
