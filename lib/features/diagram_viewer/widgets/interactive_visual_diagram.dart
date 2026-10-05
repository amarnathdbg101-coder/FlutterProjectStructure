import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
// import 'package:url_launcher/url_launcher.dart';
import '../../../core/widgets/custom_snackbar.dart';
import 'hand_drawn_diagram_canvas.dart';

/// Archetype categorization for educational diagrams
enum DiagramArchetype {
  flow,        // Step-by-step sequential or branching process flowchart
  cycle,       // Continuous closed-loop biological/thermodynamic cycle (Krebs, Water, Carnot, Cell cycle)
  comparison,  // Side-by-side or dual-column contrast (Mitosis vs Meiosis, Series vs Parallel)
  tree,        // Hierarchical taxonomy, directory or branching structure
  hub,         // Central core concept with radiating pillar cards (Mind Map)
  stack,       // Layered architectural tiers (OSI 7 Layers, Earth layers, Protocol stacks)
  timeline,    // Chronological milestones, historical eras, or reaction kinetics sequence
}

extension DiagramArchetypeExtension on DiagramArchetype {
  String get label {
    switch (this) {
      case DiagramArchetype.flow:
        return '➔ Flowchart & Logic';
      case DiagramArchetype.cycle:
        return '⟳ Closed Cycle';
      case DiagramArchetype.comparison:
        return '⚔️ Comparison';
      case DiagramArchetype.tree:
        return '🌳 Hierarchy Tree';
      case DiagramArchetype.hub:
        return '🧠 Concept Hub';
      case DiagramArchetype.stack:
        return '📚 Layered Stack';
      case DiagramArchetype.timeline:
        return '⏱️ Timeline / Sequence';
    }
  }

  String get shortName {
    switch (this) {
      case DiagramArchetype.flow:
        return 'Flow';
      case DiagramArchetype.cycle:
        return 'Cycle';
      case DiagramArchetype.comparison:
        return 'Compare';
      case DiagramArchetype.tree:
        return 'Tree';
      case DiagramArchetype.hub:
        return 'Mind Map';
      case DiagramArchetype.stack:
        return 'Stack';
      case DiagramArchetype.timeline:
        return 'Timeline';
    }
  }

  IconData get icon {
    switch (this) {
      case DiagramArchetype.flow:
        return Icons.alt_route_rounded;
      case DiagramArchetype.cycle:
        return Icons.sync_rounded;
      case DiagramArchetype.comparison:
        return Icons.compare_arrows_rounded;
      case DiagramArchetype.tree:
        return Icons.account_tree_rounded;
      case DiagramArchetype.hub:
        return Icons.hub_rounded;
      case DiagramArchetype.stack:
        return Icons.layers_rounded;
      case DiagramArchetype.timeline:
        return Icons.timeline_rounded;
    }
  }
}

/// Data model representing a node in a visual educational diagram
class DiagramNode {
  final String id;
  final String title;
  final String? subtitle;
  final String? type; // 'start', 'process', 'decision', 'output', 'formula', 'sub', 'pillar', 'layer', 'milestone'
  final List<String> targetIds;
  final Color color;
  final IconData icon;
  final int depth;
  final String? branchCondition; // e.g. "Yes", "No", "True", "False", "+ ATP", "Condition Met"
  final List<DiagramNode> branches; // Sub-branches or child choices

  const DiagramNode({
    required this.id,
    required this.title,
    this.subtitle,
    this.type,
    this.targetIds = const [],
    required this.color,
    required this.icon,
    this.depth = 0,
    this.branchCondition,
    this.branches = const [],
  });

  bool get isStart => type == 'start';
  bool get isDecision => type == 'decision';
  bool get isOutput => type == 'output';
  bool get isFormula => type == 'formula';

  DiagramNode copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? type,
    List<String>? targetIds,
    Color? color,
    IconData? icon,
    int depth = 0,
    String? branchCondition,
    List<DiagramNode>? branches,
  }) {
    return DiagramNode(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      type: type ?? this.type,
      targetIds: targetIds ?? this.targetIds,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      depth: depth != 0 ? depth : this.depth,
      branchCondition: branchCondition ?? this.branchCondition,
      branches: branches ?? this.branches,
    );
  }
}

/// Advanced, human-like Graphical Vector Diagram & Educational Visualizer.
/// Supports 7 Context-Aware Diagram Archetypes:
/// 1. ➔ Adaptive Process Flowchart (with terminal pills & decision branches)
/// 2. ⟳ Closed Biological/Physical Cycles (with circular loop return to start)
/// 3. ⚔️ Dual Concept Comparison (Side-by-side contrast cards)
/// 4. 🌳 Hierarchical Taxonomy & Tree Classifications
/// 5. 🧠 Concept Hub & Mind Map (Radiating subject pillars)
/// 6. 📚 Layered Architecture & Protocol Stacks
/// 7. ⏱️ Chronological Timeline & Milestone Process
/// Includes Fullscreen Pan & Zoom Canvas, Archetype Switcher, and One-Tap Copy.
class InteractiveVisualDiagram extends StatefulWidget {
  final String rawText;
  final String diagramTitle;
  final bool isDark;
  final double baseFontSize;
  final DiagramArchetype? initialArchetype;
  final bool isFullscreen;

  const InteractiveVisualDiagram({
    super.key,
    required this.rawText,
    required this.diagramTitle,
    required this.isDark,
    this.baseFontSize = 13.5,
    this.initialArchetype,
    this.isFullscreen = false,
  });

  static DiagramArchetype detectArchetype(String title, String text) {
    return _InteractiveVisualDiagramState.detectArchetype(title, text);
  }

  @override
  State<InteractiveVisualDiagram> createState() => _InteractiveVisualDiagramState();
}

class _InteractiveVisualDiagramState extends State<InteractiveVisualDiagram> {
  final GlobalKey _repaintBoundaryKey = GlobalKey();
  final bool _isHorizontalFlow = false;
  bool _isSketchMode = true;
  HandDrawnGraphData? _jsonGraphData;
  late DiagramArchetype _currentArchetype;
  late List<DiagramNode> _parsedNodes;

  Future<void> _exportDiagramAsImage(BuildContext context) async {
    try {
      final boundary = _repaintBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        await Clipboard.setData(ClipboardData(text: widget.rawText));
        if (context.mounted) {
          CustomSnackbar.showSuccess(context, 'Diagram text copied to clipboard!');
        }
        return;
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 2.5);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        await Clipboard.setData(ClipboardData(text: widget.rawText));
        if (context.mounted) {
          CustomSnackbar.showSuccess(context, 'Diagram text copied to clipboard!');
        }
        return;
      }

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      Directory saveDir = await getApplicationDocumentsDirectory();
      try {
        final downloads = await getDownloadsDirectory();
        if (downloads != null && downloads.existsSync()) {
          saveDir = downloads;
        }
      } catch (_) {}

      final fileName = 'StudySilo_Diagram_${DateTime.now().millisecondsSinceEpoch}.png';
      File file = File('${saveDir.path}/$fileName');

      try {
        await file.writeAsBytes(pngBytes);
      } catch (writeErr) {
        debugPrint('File write error on $saveDir: $writeErr');
        final temp = await getTemporaryDirectory();
        file = File('${temp.path}/$fileName');
        await file.writeAsBytes(pngBytes);
      }

      if (context.mounted) {
        CustomSnackbar.showSuccess(context, '📸 HD Diagram exported successfully!');
        _showImagePreviewDialog(context, file, pngBytes);
      }
    } catch (e) {
      debugPrint('Export diagram error: $e');
      await Clipboard.setData(ClipboardData(text: widget.rawText));
      if (context.mounted) {
        CustomSnackbar.showSuccess(context, 'Diagram specification copied to clipboard!');
      }
    }
  }

  void _showImagePreviewDialog(BuildContext context, File file, Uint8List bytes) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Colors.black38,
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.photo_library_rounded, color: Color(0xFF6366F1), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Exported HD Diagram',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: widget.isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  color: widget.isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: InteractiveViewer(
                    maxScale: 4.0,
                    child: Image.memory(bytes, fit: BoxFit.contain),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '📁 Location: ${file.path}',
                style: TextStyle(
                  fontSize: 11,
                  color: widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.folder_open_rounded, size: 16),
                    label: const Text('Open Folder'),
                    onPressed: () {
                      try {
                        CustomSnackbar.showInfo(context, 'Saved in: ${file.parent.path}');
                      } catch (_) {}
                    },
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Done'),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const List<Color> _palette = [
    Color(0xFF6366F1), // Indigo
    Color(0xFF10B981), // Emerald
    Color(0xFF8B5CF6), // Violet
    Color(0xFF06B6D4), // Cyan
    Color(0xFFF59E0B), // Amber
    Color(0xFFEC4899), // Pink
    Color(0xFF3B82F6), // Blue
    Color(0xFF14B8A6), // Teal
  ];

  @override
  void initState() {
    super.initState();
    _currentArchetype = widget.initialArchetype ??
        detectArchetype(widget.diagramTitle, widget.rawText);
    _parsedNodes = _parseRawDiagramIntoNodes(widget.rawText, widget.isDark, _currentArchetype);
    _jsonGraphData = HandDrawnGraphData.tryParse(widget.rawText, widget.diagramTitle, isDark: widget.isDark);
    _isSketchMode = true;
  }

  @override
  void didUpdateWidget(covariant InteractiveVisualDiagram oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rawText != widget.rawText ||
        oldWidget.isDark != widget.isDark ||
        oldWidget.diagramTitle != widget.diagramTitle ||
        oldWidget.initialArchetype != widget.initialArchetype) {
      if (oldWidget.rawText != widget.rawText || widget.initialArchetype != oldWidget.initialArchetype) {
        _currentArchetype = widget.initialArchetype ??
            detectArchetype(widget.diagramTitle, widget.rawText);
      }
      _parsedNodes = _parseRawDiagramIntoNodes(widget.rawText, widget.isDark, _currentArchetype);
      _jsonGraphData = HandDrawnGraphData.tryParse(widget.rawText, widget.diagramTitle, isDark: widget.isDark);
      _isSketchMode = true;
    }
  }

  static DiagramArchetype detectArchetype(String title, String text) {
    final lowerTitle = title.toLowerCase();
    final lowerText = text.toLowerCase();
    final combined = '$lowerTitle $lowerText';

    // 1. Cycle detection
    if (combined.contains('cycle') ||
        combined.contains('loop') ||
        combined.contains('circular') ||
        combined.contains('krebs') ||
        combined.contains('calvin') ||
        combined.contains('carnot') ||
        combined.contains('nitrogen cycle') ||
        combined.contains('water cycle') ||
        combined.contains('feedback loop') ||
        combined.contains('regenerat') ||
        combined.contains('rotation')) {
      return DiagramArchetype.cycle;
    }

    // 2. Comparison detection
    if (combined.contains('compare') ||
        combined.contains('versus') ||
        combined.contains(' vs ') ||
        combined.contains(' vs. ') ||
        combined.contains('difference') ||
        combined.contains('contrast') ||
        combined.contains('series vs parallel') ||
        combined.contains('mitosis vs meiosis') ||
        combined.contains('ram vs rom') ||
        combined.contains('tcp vs udp') ||
        lowerText.contains('[side a') ||
        lowerText.contains('side a:') ||
        lowerText.contains('concept a:')) {
      return DiagramArchetype.comparison;
    }

    // 3. Tree / Hierarchy detection
    if (combined.contains('tree') ||
        combined.contains('hierarchy') ||
        combined.contains('taxonomy') ||
        combined.contains('classification') ||
        combined.contains('categories') ||
        text.contains('├──') ||
        text.contains('└──')) {
      return DiagramArchetype.tree;
    }

    // 4. Layered Stack detection
    if (combined.contains('stack') ||
        combined.contains('layer') ||
        combined.contains('tier') ||
        combined.contains('osi model') ||
        combined.contains('tcp/ip stack') ||
        combined.contains('atmosphere') ||
        combined.contains('soil profile') ||
        combined.contains('strata') ||
        combined.contains('pyramid')) {
      return DiagramArchetype.stack;
    }

    // 5. Concept Hub / Mindmap detection
    if (combined.contains('mindmap') ||
        combined.contains('hub') ||
        combined.contains('pillars') ||
        combined.contains('laws') ||
        combined.contains('components') ||
        combined.contains('principles') ||
        combined.contains('dimensions') ||
        combined.contains('facets') ||
        lowerText.contains('[hub:') ||
        lowerText.contains('hub:')) {
      return DiagramArchetype.hub;
    }

    // 6. Timeline detection
    if (combined.contains('timeline') ||
        combined.contains('chronolog') ||
        combined.contains('history') ||
        combined.contains('phase') ||
        combined.contains('era') ||
        combined.contains('milestone') ||
        combined.contains('epoch') ||
        combined.contains('evolution')) {
      return DiagramArchetype.timeline;
    }

    return DiagramArchetype.flow;
  }

  /// Robust Universal Parser that handles:
  /// - JSON Diagram blocks ({ "nodes": [...], "edges": [...] })
  /// - Mermaid graph/flowchart syntax (graph TD, flowchart LR, A[Title] --> B{Check?})
  /// - Bracket Arrow notation ([Start: X] -> [Process: Y] -> [End: Z])
  /// - ASCII box art & connector arrows
  /// - Tree indentation & branch characters (├──, └──)
  /// - Comparison dual-column notation ([Side A: ...] vs [Side B: ...])
  /// - Mindmap hub & pillar items ([Hub: ...] * [Pillar 1: ...])
  /// - Stack layered tiers ([Layer N: ...])
  static List<DiagramNode> _parseRawDiagramIntoNodes(String text, bool isDark, DiagramArchetype archetype) {
    // Step 0: Check if input is a JSON diagram block ({ "nodes": [...], "edges": [...] })
    final jsonStr = HandDrawnGraphData.findOuterJsonBlock(text);
    if (jsonStr != null) {
      try {
        final decoded = jsonDecode(jsonStr);
        if (decoded is Map<String, dynamic> &&
            (decoded.containsKey('nodes') || decoded.containsKey('diagram') || decoded.containsKey('edges'))) {
          final jsonNodes = _parseJsonDiagramNodes(decoded, isDark);
          if (jsonNodes.isNotEmpty) {
            return jsonNodes;
          }
        }
      } catch (_) {}
    }

    final List<DiagramNode> nodes = [];
    int colorIdx = 0;

    // Step A: Strip code fence lines if present
    final cleanInput = text
        .replaceAll(RegExp(r'^```[a-zA-Z0-9_\-:]*\s*\n?', multiLine: true), '')
        .replaceAll(RegExp(r'\n?```\s*$', multiLine: true), '')
        .trim();

    // Check if input is Mermaid graph syntax
    final isMermaid = cleanInput.toLowerCase().contains('graph ') ||
        cleanInput.toLowerCase().contains('flowchart ') ||
        RegExp(r'[a-zA-Z0-9_\-]+\s*(?:\[|\(|\{).*?-->', multiLine: true).hasMatch(cleanInput);

    if (isMermaid) {
      final mermaidNodes = _parseMermaidSyntax(cleanInput, isDark);
      if (mermaidNodes.isNotEmpty) {
        return mermaidNodes;
      }
    }

    final lines = cleanInput.split('\n');

    // Step B: Filter out Mermaid header lines (e.g. "graph TD", "flowchart LR")
    final filteredLines = lines.where((l) {
      final t = l.trim().toLowerCase();
      if (t.startsWith('graph ') || t == 'graph' || t.startsWith('flowchart ') || t == 'flowchart') {
        return false;
      }
      return true;
    }).toList();

    for (int lineIdx = 0; lineIdx < filteredLines.length; lineIdx++) {
      final rawLine = filteredLines[lineIdx];
      var line = rawLine.trim();
      if (line.isEmpty) continue;

      // Ignore pure horizontal boundary lines from ASCII box art (e.g. +-------+, --------, =======)
      if (RegExp(r'^[\|\+\-\=\*\#\:\s_]{3,}$').hasMatch(line)) {
        continue;
      }

      // Calculate tree depth if tree characters present
      int depth = 0;
      if (rawLine.contains('├──') || rawLine.contains('└──') || rawLine.contains('|   ')) {
        depth = (rawLine.contains('├') ? rawLine.indexOf('├') : rawLine.indexOf('└')) ~/ 4 + 1;
      }

      // Detect if line represents a Mermaid branch with condition e.g. "B -->|Yes| C[Process]"
      String? mermaidCondition;
      final mermaidCondMatch = RegExp(r'-->\|(.*?)\|\s*').firstMatch(line);
      if (mermaidCondMatch != null) {
        mermaidCondition = mermaidCondMatch.group(1)?.trim();
        line = line.replaceFirst(mermaidCondMatch.group(0)!, '--> ');
      }

      // Clean ASCII table/box borders and connectors
      line = line.replaceAll(RegExp(r'^[\|\+\-\=\*\>\#\.\:\s├──└──│]+'), '').trim();
      line = line.replaceAll(RegExp(r'[\|\+\-\=\*\#\:\s]+$'), '').trim();

      // If line is empty after stripping borders, skip
      if (line.isEmpty || line.length < 2) continue;

      // Check for Mermaid decision syntax e.g. A{Condition?}
      bool isMermaidDecision = false;
      final decisionMatch = RegExp(r'\{([^\}]+)\}').firstMatch(line);
      if (decisionMatch != null) {
        isMermaidDecision = true;
      }

      // Split if line contains arrow separators like "A -> B -> C" or "A --> B"
      final stepParts = line.split(RegExp(r'\s*(?:-->|->|==>|=>|→|➔|⭢|↳)\s*'));

      for (int i = 0; i < stepParts.length; i++) {
        var part = stepParts[i].trim();
        if (part.isEmpty) continue;

        // Clean enclosing brackets e.g. [Step 1: Title] or ([Title]) or {Title}
        part = part.replaceAllMapped(RegExp(r'^[\[\(\{]+(.*?)[\]\)\}]+$'), (m) => m.group(1) ?? '').trim();
        if (part.isEmpty) continue;

        String title = part;
        String? subtitle;
        IconData icon = Icons.hub_rounded;
        String type = 'process';

        // Check if there is colon or pipe separation e.g. "Step 1: Glycolysis | Cytoplasm"
        if (part.contains('|')) {
          final barParts = part.split('|');
          title = barParts[0].trim();
          subtitle = barParts.sublist(1).map((s) => s.trim()).join(' • ');
        } else if (part.contains(':')) {
          final colParts = part.split(':');
          final prefix = colParts[0].trim();
          final suffix = colParts.sublist(1).join(':').trim();

          // If prefix is "Step 1", "Stage 2", "Phase 3", we make suffix the title
          // and DO NOT put "Step 1" in subtitle to avoid redundant duplication!
          if (RegExp(r'^(?:step|phase|stage|layer|pillar|branch|milestone|node)\s*\d+$', caseSensitive: false).hasMatch(prefix)) {
            title = suffix.isNotEmpty ? suffix : prefix;
            subtitle = null; // Step chip will display "Step X" cleanly
          } else {
            title = prefix;
            subtitle = suffix.isNotEmpty ? suffix : null;
          }
        }

        // Subtitle parenthetical extraction e.g. "Krebs Cycle (Mitochondrial Matrix)"
        final parenMatch = RegExp(r'^(.*?)\s*\((.*?)\)$').firstMatch(title);
        if (parenMatch != null) {
          title = parenMatch.group(1)!.trim();
          subtitle = parenMatch.group(2)!.trim();
        }

        // Avoid subtitle repeating the step number
        if (subtitle != null && RegExp(r'^(?:step|stage|phase|layer)\s*\d+$', caseSensitive: false).hasMatch(subtitle.trim())) {
          subtitle = null;
        }

        // Detect node archetype, condition, & icon
        final lower = title.toLowerCase();
        if (lower.contains('start') || lower.contains('input') || lower.contains('initial') || lower.contains('origin') || lower.contains('entry')) {
          icon = Icons.play_circle_fill_rounded;
          type = 'start';
        } else if (lower.contains('end') || lower.contains('output') || lower.contains('result') || lower.contains('final') || lower.contains('product') || lower.contains('exit')) {
          icon = Icons.flag_rounded;
          type = 'output';
        } else if (isMermaidDecision || lower.contains('if ') || lower.contains('check') || lower.contains('decision') || lower.contains('condition') || title.endsWith('?')) {
          icon = Icons.alt_route_rounded;
          type = 'decision';
        } else if (lower.contains('calc') || lower.contains('equation') || lower.contains('formula') || lower.contains('math') || lower.contains('integral')) {
          icon = Icons.functions_rounded;
          type = 'formula';
        } else if (lower.contains('energy') || lower.contains('atp') || lower.contains('power') || lower.contains('volt') || lower.contains('force') || lower.contains('current')) {
          icon = Icons.bolt_rounded;
        } else if (lower.contains('dna') || lower.contains('cell') || lower.contains('protein') || lower.contains('enzyme') || lower.contains('acid') || lower.contains('glucose')) {
          icon = Icons.biotech_rounded;
        } else if (lower.contains('layer') || lower.contains('protocol') || lower.contains('network') || lower.contains('data') || lower.contains('packet')) {
          icon = Icons.layers_rounded;
        } else if (archetype == DiagramArchetype.timeline || lower.contains('year') || lower.contains('century') || lower.contains('era')) {
          icon = Icons.event_available_rounded;
          type = 'milestone';
        }

        final nodeColor = _palette[colorIdx % _palette.length];
        colorIdx++;

        nodes.add(DiagramNode(
          id: 'node_${nodes.length + 1}',
          title: title,
          subtitle: subtitle,
          type: type,
          color: nodeColor,
          icon: icon,
          depth: depth,
          branchCondition: mermaidCondition,
        ));
      }
    }

    if (nodes.isEmpty) {
      nodes.add(const DiagramNode(
        id: 'node_1',
        title: 'Core Concept & Logic Flow',
        subtitle: 'Structured educational pathway overview',
        color: Color(0xFF6366F1),
        icon: Icons.account_tree_rounded,
      ));
    }

    return nodes;
  }

  static List<DiagramNode> _parseJsonDiagramNodes(Map<String, dynamic> json, bool isDark) {
    final Map<String, dynamic> data = (json['diagram'] is Map<String, dynamic>)
        ? json['diagram'] as Map<String, dynamic>
        : json;

    final rawNodes = data['nodes'] ?? json['nodes'];
    final rawEdges = data['edges'] ?? data['relations'] ?? json['edges'];
    final List<DiagramNode> nodes = [];
    final Map<String, DiagramNode> nodeMap = {};

    if (rawNodes is List) {
      for (int i = 0; i < rawNodes.length; i++) {
        final item = rawNodes[i];
        if (item is Map<String, dynamic>) {
          final id = item['id']?.toString() ?? 'node_${i + 1}';
          final title = item['label']?.toString() ??
              item['title']?.toString() ??
              'Concept ${i + 1}';
          final subtitle = item['subtitle']?.toString() ?? item['description']?.toString();
          final rawShape = item['shape']?.toString().toLowerCase() ?? item['type']?.toString().toLowerCase() ?? 'box';
          final shape = HandDrawnGraphData.resolveSemanticShape(rawShape, title, subtitle: subtitle);
          final color = _palette[i % _palette.length];

          IconData icon = Icons.hub_rounded;
          if (shape == 'cylinder') icon = Icons.storage_rounded;
          if (shape == 'capsule') icon = Icons.play_circle_fill_rounded;
          if (shape == 'triangle') icon = Icons.alt_route_rounded;

          final node = DiagramNode(
            id: id,
            title: title,
            subtitle: subtitle,
            type: shape,
            color: color,
            icon: icon,
          );
          nodes.add(node);
          nodeMap[id] = node;
        }
      }
    }

    if (rawEdges is List) {
      for (int i = 0; i < rawEdges.length; i++) {
        final e = rawEdges[i];
        if (e is Map<String, dynamic>) {
          final fromId = e['from']?.toString() ?? '';
          final toId = e['to']?.toString() ?? '';
          final condition = e['label']?.toString() ?? e['condition']?.toString();

          if (nodeMap.containsKey(fromId) && nodeMap.containsKey(toId)) {
            final sourceNode = nodeMap[fromId]!;
            if (!sourceNode.targetIds.contains(toId)) {
              final updatedTargets = List<String>.from(sourceNode.targetIds)..add(toId);
              nodeMap[fromId] = sourceNode.copyWith(
                targetIds: updatedTargets,
                branchCondition: condition ?? sourceNode.branchCondition,
              );
            }
          }
        }
      }
    }

    return nodes.map((n) => nodeMap[n.id] ?? n).toList();
  }

  static List<DiagramNode> _parseMermaidSyntax(String text, bool isDark) {
    final Map<String, DiagramNode> nodeMap = {};
    final List<String> nodeOrder = [];
    int colorIdx = 0;

    final lines = text.split('\n');
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final lower = line.toLowerCase();
      if (lower.startsWith('graph ') || lower == 'graph' || lower.startsWith('flowchart ') || lower == 'flowchart') {
        continue;
      }

      // Check for connection pattern: Source -->|condition| Target or Source --> Target
      final edgeRegex = RegExp(r'^(.*?)\s*(?:-->|->)\s*(?:\|(.*?)\|\s*)?(.*)$');
      final match = edgeRegex.firstMatch(line);

      if (match != null) {
        final sourceRaw = match.group(1)!.trim();
        final condition = match.group(2)?.trim();
        final targetRaw = match.group(3)!.trim();

        final sourceNode = _extractOrCreateMermaidNode(sourceRaw, nodeMap, colorIdx++);
        if (!nodeOrder.contains(sourceNode.id)) nodeOrder.add(sourceNode.id);

        final targetNode = _extractOrCreateMermaidNode(targetRaw, nodeMap, colorIdx++, branchCondition: condition);
        if (!nodeOrder.contains(targetNode.id)) nodeOrder.add(targetNode.id);

        final currentSource = nodeMap[sourceNode.id]!;
        if (!currentSource.targetIds.contains(targetNode.id)) {
          final updatedTargets = List<String>.from(currentSource.targetIds)..add(targetNode.id);
          nodeMap[sourceNode.id] = currentSource.copyWith(targetIds: updatedTargets);
        }
      } else {
        // Standalone node definition on its own line e.g. "A[Title]"
        final node = _extractOrCreateMermaidNode(line, nodeMap, colorIdx++);
        if (!nodeOrder.contains(node.id)) nodeOrder.add(node.id);
      }
    }

    return nodeOrder.map((id) => nodeMap[id]!).toList();
  }

  static DiagramNode _extractOrCreateMermaidNode(
    String raw,
    Map<String, DiagramNode> nodeMap,
    int colorIdx, {
    String? branchCondition,
  }) {
    // Matches: ID([Title]), ID((Title)), ID{Title}, ID[[Title]], ID[Title], or just ID
    final defRegex = RegExp(r'^([a-zA-Z0-9_\-]+)\s*(?:(\(\[|\(\(|\{|\(\[|\[\[|\(|\[)(.*?)(\)\]|\)\)|\}\]|\}\]|\}\]|\}|\)|\]))?$');
    final match = defRegex.firstMatch(raw.trim());

    String id = raw.trim();
    String? openBracket;
    String? label;

    if (match != null) {
      id = match.group(1)!.trim();
      openBracket = match.group(2);
      label = match.group(3)?.trim();
    }

    if (nodeMap.containsKey(id) && (label == null || label.isEmpty)) {
      final existing = nodeMap[id]!;
      if (branchCondition != null && existing.branchCondition == null) {
        final updated = existing.copyWith(branchCondition: branchCondition);
        nodeMap[id] = updated;
        return updated;
      }
      return existing;
    }

    String title = label ?? id;
    String? subtitle;
    String type = 'process';
    IconData icon = Icons.hub_rounded;

    // Check bracket type for semantics
    if (openBracket == '([' || openBracket == '((') {
      type = 'start';
      icon = Icons.play_circle_fill_rounded;
    } else if (openBracket == '{') {
      type = 'decision';
      icon = Icons.alt_route_rounded;
    }

    // Check if label contains colon e.g. "Start: User Request" or "Result: Success"
    if (title.contains(':')) {
      final parts = title.split(':');
      final prefix = parts[0].trim();
      final suffix = parts.sublist(1).join(':').trim();
      final pLower = prefix.toLowerCase();

      if (pLower.startsWith('start') || pLower.startsWith('input') || pLower.startsWith('entry')) {
        type = 'start';
        icon = Icons.play_circle_fill_rounded;
        title = suffix.isNotEmpty ? suffix : prefix;
      } else if (pLower.startsWith('end') || pLower.startsWith('result') || pLower.startsWith('final') || pLower.startsWith('output')) {
        type = 'output';
        icon = Icons.flag_rounded;
        title = suffix.isNotEmpty ? suffix : prefix;
      } else if (pLower.startsWith('check') || pLower.startsWith('decision') || pLower.startsWith('if')) {
        type = 'decision';
        icon = Icons.alt_route_rounded;
        title = suffix.isNotEmpty ? suffix : prefix;
      } else if (RegExp(r'^(?:step|phase|stage|layer)\s*\d+$', caseSensitive: false).hasMatch(prefix)) {
        title = suffix.isNotEmpty ? suffix : prefix;
        subtitle = null;
      } else {
        title = prefix;
        subtitle = suffix.isNotEmpty ? suffix : null;
      }
    }

    final lower = title.toLowerCase();
    if (type == 'process') {
      if (lower.contains('start') || lower.contains('input') || lower.contains('origin')) {
        type = 'start';
        icon = Icons.play_circle_fill_rounded;
      } else if (lower.contains('end') || lower.contains('result') || lower.contains('final') || lower.contains('output')) {
        type = 'output';
        icon = Icons.flag_rounded;
      } else if (lower.contains('if ') || lower.contains('check') || lower.contains('decision') || title.endsWith('?')) {
        type = 'decision';
        icon = Icons.alt_route_rounded;
      }
    }

    final color = _palette[colorIdx % _palette.length];
    final node = DiagramNode(
      id: id,
      title: title,
      subtitle: subtitle,
      type: type,
      color: color,
      icon: icon,
      branchCondition: branchCondition,
    );

    nodeMap[id] = node;
    return node;
  }

  void _openFullscreenModal(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => _DiagramFullscreenViewer(
          diagramTitle: widget.diagramTitle,
          nodes: _parsedNodes,
          rawText: widget.rawText,
          isDark: widget.isDark,
          archetype: _currentArchetype,
          baseFontSize: widget.baseFontSize,
          onArchetypeChanged: (newArch) {
            setState(() {
              _currentArchetype = newArch;
              _parsedNodes = _parseRawDiagramIntoNodes(widget.rawText, widget.isDark, _currentArchetype);
            });
          },
        ),
      ),
    );
  }



  void _showNodeInspector(BuildContext context, DiagramNode node) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: node.color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(node.icon, color: node.color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        node.title,
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: widget.isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (node.type != null)
                        Text(
                          'Type: ${node.type?.toUpperCase()}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: node.color,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (node.subtitle != null) ...[
              Text(
                'Description & Details:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                node.subtitle!,
                style: TextStyle(
                  fontSize: 14,
                  color: widget.isDark ? const Color(0xFFE2E8F0) : Colors.black87,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF6366F1),
                  side: const BorderSide(color: Color(0xFF6366F1)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('Ask AI Deep Dive on this Concept'),
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('🧠 AI is generating a deep-dive breakdown for "${node.title}"...'),
                      backgroundColor: const Color(0xFF6366F1),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF6366F1).withValues(alpha: widget.isDark ? 0.35 : 0.22),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: widget.isDark ? 0.35 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🏷️ DIAGRAM HEADER & CONTROL TOOLBAR
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: widget.isDark ? const Color(0xFF1E1B4B).withValues(alpha: 0.6) : const Color(0xFFEEF2FF),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              border: Border(
                bottom: BorderSide(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Icon(Icons.schema_rounded, size: 14, color: Colors.white),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.diagramTitle,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF6366F1),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _currentArchetype.label,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),

                // 📝 Scratch Diagram Badge (Clean Scratch Notebook Mode)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.edit_note_rounded,
                        size: 13,
                        color: Color(0xFF6366F1),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Scratch',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6366F1),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),

                // 📸 1-Tap HD Image Export & Copy
                IconButton(
                  icon: const Icon(Icons.file_download_rounded, size: 18, color: Color(0xFF6366F1)),
                  tooltip: 'Export HD Image & Copy Spec',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: () => _exportDiagramAsImage(context),
                ),
                const SizedBox(width: 2),

                // Fullscreen Pan & Zoom (hidden if already in fullscreen viewer)
                if (!widget.isFullscreen)
                  IconButton(
                    icon: const Icon(Icons.fullscreen_rounded, size: 18, color: Color(0xFF6366F1)),
                    tooltip: 'Fullscreen Interactive Canvas',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: () => _openFullscreenModal(context),
                  ),
              ],
            ),
          ),

          // 🎨 ACTIVE SCRATCH DIAGRAM CANVAS (Smooth Animated Switcher)
          RepaintBoundary(
            key: _repaintBoundaryKey,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: SingleChildScrollView(
                key: ValueKey('${_currentArchetype.name}_$_isSketchMode'),
                scrollDirection: Axis.horizontal,
                child: _buildActiveDiagramView(
                  context,
                  _parsedNodes,
                  _currentArchetype,
                  widget.isDark,
                  widget.baseFontSize,
                  isHorizontalFlow: _isHorizontalFlow,
                ),
              ),
            ),
          ),

          // 💡 Diagram Explanation Banner
          if (_jsonGraphData?.conceptSummary != null && _jsonGraphData!.conceptSummary!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 2, 14, 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: widget.isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('💡 ', style: TextStyle(fontSize: 13)),
                    Expanded(
                      child: Text(
                        _jsonGraphData!.conceptSummary!.trim(),
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                          color: widget.isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActiveDiagramView(
    BuildContext context,
    List<DiagramNode> nodes,
    DiagramArchetype archetype,
    bool isDark,
    double baseFontSize, {
    bool isHorizontalFlow = false,
  }) {
    if (_isSketchMode) {
      final graphData = _jsonGraphData ??
          HandDrawnGraphData.fromDiagramNodes(nodes, widget.diagramTitle);
      return HandDrawnDiagramCanvas(
        graphData: graphData,
        isDark: isDark,
        baseFontSize: baseFontSize,
      );
    }

    switch (archetype) {
      case DiagramArchetype.cycle:
        return _buildCycleLayout(context, nodes, isDark, baseFontSize);
      case DiagramArchetype.comparison:
        return _buildComparisonLayout(context, nodes, isDark, baseFontSize);
      case DiagramArchetype.tree:
        return _buildTreeLayout(context, nodes, isDark, baseFontSize);
      case DiagramArchetype.hub:
        return _buildHubLayout(context, nodes, isDark, baseFontSize);
      case DiagramArchetype.stack:
        return _buildStackLayout(context, nodes, isDark, baseFontSize);
      case DiagramArchetype.timeline:
        return _buildTimelineLayout(context, nodes, isDark, baseFontSize);
      case DiagramArchetype.flow:
        if (isHorizontalFlow) {
          return _buildHorizontalSequenceLayout(context, nodes, isDark, baseFontSize);
        }
        return _buildFlowLayout(context, nodes, isDark, baseFontSize);
    }
  }

  // ===========================================================================
  // 1. ➔ PROCESS FLOWCHART LAYOUT (Start pill, decision diamond & branching)
  // ===========================================================================
  Widget _buildFlowLayout(
    BuildContext context,
    List<DiagramNode> nodes,
    bool isDark,
    double baseFontSize,
  ) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          for (int i = 0; i < nodes.length; i++) ...[
            GestureDetector(
              onTap: () => _showNodeInspector(context, nodes[i]),
              child: _buildFlowchartNode(nodes[i], i + 1, isDark, baseFontSize),
            ),
            if (i < nodes.length - 1)
              _buildConnectorArrow(
                nodes[i].color,
                isDark,
                condition: nodes[i + 1].branchCondition,
              ),
          ],
        ],
      ),
    );
  }

  /// Horizontal scrolling step track
  Widget _buildHorizontalSequenceLayout(
    BuildContext context,
    List<DiagramNode> nodes,
    bool isDark,
    double baseFontSize,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(nodes.length, (idx) {
            final node = nodes[idx];
            final isLast = idx == nodes.length - 1;

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  constraints: const BoxConstraints(maxWidth: 220, minWidth: 140),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: node.color.withValues(alpha: isDark ? 0.4 : 0.3),
                      width: 1.4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: node.color.withValues(alpha: isDark ? 0.12 : 0.06),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: node.color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Step ${idx + 1}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: node.color,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Icon(node.icon, size: 14, color: node.color),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        node.title,
                        style: GoogleFonts.outfit(
                          fontSize: baseFontSize,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (node.subtitle != null && node.subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          node.subtitle!,
                          style: TextStyle(
                            fontSize: baseFontSize - 2.5,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (!isLast) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (nodes[idx + 1].branchCondition != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            margin: const EdgeInsets.only(bottom: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              nodes[idx + 1].branchCondition!,
                              style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                            ),
                          ),
                        Row(
                          children: [
                            Container(width: 14, height: 2, color: const Color(0xFF6366F1)),
                            const Icon(Icons.arrow_forward_rounded, size: 16, color: Color(0xFF6366F1)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildFlowchartNode(
    DiagramNode node,
    int stepNumber,
    bool isDark,
    double baseFontSize,
  ) {
    // 🟢 START NODE: Capsule stadium shape with glowing status dot
    if (node.isStart) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.18 : 0.1),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: const Color(0xFF10B981), width: 1.6),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(
                color: Color(0xFF10B981),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Step $stepNumber',
                style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('START', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                node.title,
                style: GoogleFonts.outfit(
                  fontSize: baseFontSize + 1,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    // 🏁 END / OUTPUT NODE: Goal stadium shape with emerald/gold outline
    if (node.isOutput) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF8B5CF6).withValues(alpha: isDark ? 0.18 : 0.1),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: const Color(0xFF8B5CF6), width: 1.6),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.flag_rounded, size: 16, color: Color(0xFF8B5CF6)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Step $stepNumber',
                style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6)),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('RESULT / END', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6))),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                node.title,
                style: GoogleFonts.outfit(
                  fontSize: baseFontSize + 1,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    // 🔷 DECISION / CONDITION NODE: Diamond badge with decision question & branching
    if (node.isDecision) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.16 : 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF59E0B), width: 1.6),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.alt_route_rounded, size: 14, color: Color(0xFFD97706)),
                ),
                const SizedBox(width: 8),
                const Text(
                  'DECISION POINT / CONDITION',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFD97706), letterSpacing: 0.5),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              node.title,
              style: GoogleFonts.outfit(
                fontSize: baseFontSize + 1.5,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              textAlign: TextAlign.center,
            ),
            if (node.subtitle != null && node.subtitle!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                node.subtitle!,
                style: TextStyle(
                  fontSize: baseFontSize - 2,
                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      );
    }

    // 🧮 SCIENTIFIC / FORMULA NODE
    if (node.isFormula) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF06B6D4).withValues(alpha: isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF06B6D4), width: 1.3),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF06B6D4).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.functions_rounded, size: 18, color: Color(0xFF06B6D4)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    node.title,
                    style: GoogleFonts.firaCode(
                      fontSize: baseFontSize,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFF67E8F9) : const Color(0xFF0891B2),
                    ),
                  ),
                  if (node.subtitle != null && node.subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      node.subtitle!,
                      style: TextStyle(fontSize: baseFontSize - 2, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    // 🟦 STANDARD PROCESS NODE
    return _buildNodeCard(node, stepNumber, isDark, baseFontSize);
  }

  // ===========================================================================
  // 2. ⟳ CLOSED CYCLE LAYOUT (Krebs, Water, Carnot, Cell cycle)
  // ===========================================================================
  Widget _buildCycleLayout(
    BuildContext context,
    List<DiagramNode> nodes,
    bool isDark,
    double baseFontSize,
  ) {
    final firstNode = nodes.isNotEmpty ? nodes.first : null;

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          // Cycle Banner Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.loop_rounded, size: 14, color: Color(0xFF10B981)),
                SizedBox(width: 6),
                Text(
                  'Continuous Closed-Loop Cycle (Repeats Indefinitely)',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                ),
              ],
            ),
          ),

          // Steps in cycle
          for (int i = 0; i < nodes.length; i++) ...[
            _buildNodeCard(nodes[i], i + 1, isDark, baseFontSize, isCycle: true),
            if (i < nodes.length - 1)
              _buildConnectorArrow(nodes[i].color, isDark),
          ],

          // Closing Loop Connector back to Step 1
          if (firstNode != null && nodes.length > 1) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Center(
                child: Column(
                  children: [
                    Container(width: 2.5, height: 12, color: const Color(0xFF10B981)),
                    const Icon(Icons.arrow_downward_rounded, size: 20, color: Color(0xFF10B981)),
                  ],
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.18 : 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF10B981), width: 1.4),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFF10B981)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '⟳ Loop Closes: Regenerates initial substrate and restarts at Stage 1 (${firstNode.title})',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // 3. ⚔️ COMPARISON LAYOUT (A vs B, Mitosis vs Meiosis, Series vs Parallel)
  // ===========================================================================
  Widget _buildComparisonLayout(
    BuildContext context,
    List<DiagramNode> nodes,
    bool isDark,
    double baseFontSize,
  ) {
    final mid = (nodes.length / 2).ceil();
    final sideA = nodes.sublist(0, mid);
    final sideB = nodes.sublist(mid);

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.compare_arrows_rounded, size: 14, color: Color(0xFF8B5CF6)),
                SizedBox(width: 6),
                Text(
                  'Comparative Concept Analysis & Core Distinctions',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6)),
                ),
              ],
            ),
          ),

          if (sideB.isNotEmpty) ...[
            // Side A Card
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.14 : 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('CONCEPT A', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          sideA.first.title,
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: baseFontSize + 1, color: const Color(0xFF6366F1)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (final node in sideA)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_circle_outline_rounded, size: 14, color: Color(0xFF6366F1)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${node.title}${node.subtitle != null ? " • ${node.subtitle}" : ""}',
                              style: TextStyle(fontSize: baseFontSize - 1, color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B)),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // VS divider badge
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3.5),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('VS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
              ),
            ),

            // Side B Card
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.14 : 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('CONCEPT B', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          sideB.first.title,
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: baseFontSize + 1, color: const Color(0xFF10B981)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (final node in sideB)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_circle_outline_rounded, size: 14, color: Color(0xFF10B981)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${node.title}${node.subtitle != null ? " • ${node.subtitle}" : ""}',
                              style: TextStyle(fontSize: baseFontSize - 1, color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B)),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ] else ...[
            for (int i = 0; i < nodes.length; i++)
              _buildNodeCard(nodes[i], i + 1, isDark, baseFontSize),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // 4. 🌳 HIERARCHICAL TREE LAYOUT (Taxonomy & Branching Structures)
  // ===========================================================================
  Widget _buildTreeLayout(
    BuildContext context,
    List<DiagramNode> nodes,
    bool isDark,
    double baseFontSize,
  ) {
    final root = nodes.isNotEmpty ? nodes.first : null;
    final branches = nodes.length > 1 ? nodes.sublist(1) : <DiagramNode>[];

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tree Root Card
          if (root != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF6366F1), width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_tree_rounded, color: Color(0xFF6366F1), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      root.title,
                      style: GoogleFonts.outfit(
                        fontSize: baseFontSize + 1.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Branches with visual tree indentation lines
          for (int i = 0; i < branches.length; i++) ...[
            Padding(
              padding: const EdgeInsets.only(left: 14, bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 16,
                    height: 1.5,
                    color: branches[i].color,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: branches[i].color.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        children: [
                          Icon(branches[i].icon, size: 15, color: branches[i].color),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  branches[i].title,
                                  style: TextStyle(
                                    fontSize: baseFontSize,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                if (branches[i].subtitle != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    branches[i].subtitle!,
                                    style: TextStyle(
                                      fontSize: baseFontSize - 2,
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // 5. 🧠 CONCEPT HUB & MIND MAP LAYOUT (Core subject + radiating pillars)
  // ===========================================================================
  Widget _buildHubLayout(
    BuildContext context,
    List<DiagramNode> nodes,
    bool isDark,
    double baseFontSize,
  ) {
    final hub = nodes.isNotEmpty ? nodes.first : null;
    final pillars = nodes.length > 1 ? nodes.sublist(1) : <DiagramNode>[];

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          if (hub != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF6366F1).withValues(alpha: isDark ? 0.35 : 0.15),
                    const Color(0xFF8B5CF6).withValues(alpha: isDark ? 0.35 : 0.15),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF6366F1), width: 1.5),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.hub_rounded, size: 20, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'CORE CONCEPT HUB',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF6366F1), letterSpacing: 0.5),
                        ),
                        Text(
                          hub.title,
                          style: GoogleFonts.outfit(
                            fontSize: baseFontSize + 2,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(pillars.length, (idx) {
              final p = pillars[idx];
              return Container(
                width: MediaQuery.sizeOf(context).width > 400 ? (MediaQuery.sizeOf(context).width - 64) / 2 : double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: p.color.withValues(alpha: 0.35)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: p.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(p.icon, size: 14, color: p.color),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.title,
                            style: TextStyle(
                              fontSize: baseFontSize - 0.5,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          if (p.subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              p.subtitle!,
                              style: TextStyle(
                                fontSize: baseFontSize - 2.5,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 6. 📚 LAYERED STACK LAYOUT (OSI 7 Layers, Earth's layers, Protocol stacks)
  // ===========================================================================
  Widget _buildStackLayout(
    BuildContext context,
    List<DiagramNode> nodes,
    bool isDark,
    double baseFontSize,
  ) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          for (int i = 0; i < nodes.length; i++) ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: nodes[i].color.withValues(alpha: 0.35)),
                boxShadow: [
                  BoxShadow(
                    color: nodes[i].color.withValues(alpha: isDark ? 0.08 : 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: nodes[i].color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Layer ${nodes.length - i}',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: nodes[i].color),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(nodes[i].icon, size: 16, color: nodes[i].color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nodes[i].title,
                          style: TextStyle(
                            fontSize: baseFontSize,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        if (nodes[i].subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            nodes[i].subtitle!,
                            style: TextStyle(
                              fontSize: baseFontSize - 2,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // 7. ⏱️ TIMELINE & MILESTONES LAYOUT
  // ===========================================================================
  Widget _buildTimelineLayout(
    BuildContext context,
    List<DiagramNode> nodes,
    bool isDark,
    double baseFontSize,
  ) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: List.generate(nodes.length, (idx) {
          final node = nodes[idx];
          final isLast = idx == nodes.length - 1;

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Timeline indicator line + dot
                SizedBox(
                  width: 32,
                  child: Column(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: node.color,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: node.color.withValues(alpha: 0.4),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: node.color.withValues(alpha: 0.35),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Milestone Card
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: node.color.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: node.color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Phase ${idx + 1}',
                                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: node.color),
                              ),
                            ),
                            const Spacer(),
                            Icon(node.icon, size: 14, color: node.color),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          node.title,
                          style: GoogleFonts.outfit(
                            fontSize: baseFontSize,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        if (node.subtitle != null && node.subtitle!.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            node.subtitle!,
                            style: TextStyle(
                              fontSize: baseFontSize - 2,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildNodeCard(
    DiagramNode node,
    int stepNumber,
    bool isDark,
    double baseFontSize, {
    bool isCycle = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: node.color.withValues(alpha: isDark ? 0.4 : 0.25),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: node.color.withValues(alpha: isDark ? 0.15 : 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Step number / Icon badge
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: node.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(node.icon, color: node.color, size: 18),
          ),
          const SizedBox(width: 12),

          // Title & Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: node.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Step $stepNumber',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: node.color,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        node.title,
                        style: GoogleFonts.outfit(
                          fontSize: baseFontSize + 0.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (node.subtitle != null && node.subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    node.subtitle!,
                    style: TextStyle(
                      fontSize: baseFontSize - 2,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectorArrow(
    Color color,
    bool isDark, {
    String? condition,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Center(
        child: Column(
          children: [
            if (condition != null && condition.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                margin: const EdgeInsets.only(bottom: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Text(
                  condition,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
            Container(
              width: 2.2,
              height: 14,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    color.withValues(alpha: 0.5),
                    color,
                  ],
                ),
              ),
            ),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 24,
              color: color,
            ),
          ],
        ),
      ),
    );
  }
}

/// Fullscreen Interactive Pan & Zoom viewer for diagrams
class _DiagramFullscreenViewer extends StatefulWidget {
  final String diagramTitle;
  final List<DiagramNode> nodes;
  final String rawText;
  final bool isDark;
  final DiagramArchetype archetype;
  final double baseFontSize;
  final ValueChanged<DiagramArchetype>? onArchetypeChanged;

  const _DiagramFullscreenViewer({
    required this.diagramTitle,
    required this.nodes,
    required this.rawText,
    required this.isDark,
    required this.archetype,
    required this.baseFontSize,
    this.onArchetypeChanged,
  });

  @override
  State<_DiagramFullscreenViewer> createState() => _DiagramFullscreenViewerState();
}

class _DiagramFullscreenViewerState extends State<_DiagramFullscreenViewer> {
  late DiagramArchetype _currentArchetype;
  final TransformationController _transController = TransformationController();

  @override
  void initState() {
    super.initState();
    _currentArchetype = widget.archetype;
  }

  void _zoomIn() {
    _transController.value = _transController.value.clone()..scaleByDouble(1.2, 1.2, 1.0, 1.0);
  }

  void _zoomOut() {
    _transController.value = _transController.value.clone()..scaleByDouble(0.8, 0.8, 1.0, 1.0);
  }

  void _resetZoom() {
    _transController.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.isDark ? const Color(0xFF0B1120) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.diagramTitle, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('Hand-Drawn Scratch Notebook', style: TextStyle(fontSize: 11, color: widget.isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5))),
          ],
        ),
        backgroundColor: widget.isDark ? const Color(0xFF0F172A) : Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_in_rounded, size: 20),
            tooltip: 'Zoom In',
            onPressed: _zoomIn,
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out_rounded, size: 20),
            tooltip: 'Zoom Out',
            onPressed: _zoomOut,
          ),
          IconButton(
            icon: const Icon(Icons.center_focus_strong_rounded, size: 20),
            tooltip: 'Reset Zoom',
            onPressed: _resetZoom,
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 20),
            tooltip: 'Copy Diagram Text',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: widget.rawText));
              CustomSnackbar.showSuccess(context, 'Diagram copied to clipboard!');
            },
          ),
        ],
      ),
      body: InteractiveViewer(
              transformationController: _transController,
              boundaryMargin: const EdgeInsets.all(80),
              minScale: 0.4,
              maxScale: 4.0,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: InteractiveVisualDiagram(
                      rawText: widget.rawText,
                      diagramTitle: widget.diagramTitle,
                      isDark: widget.isDark,
                      baseFontSize: widget.baseFontSize + 1,
                      initialArchetype: _currentArchetype,
                      isFullscreen: true,
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
