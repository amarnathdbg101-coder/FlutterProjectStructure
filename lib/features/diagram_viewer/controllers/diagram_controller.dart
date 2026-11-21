import 'package:flutter/material.dart';
import '../models/diagram_model.dart';
import '../repositories/diagram_repository.dart';

class ExpandNodeResult {
  final bool success;
  final bool isSaturated;
  final String? saturationReason;
  final String? errorMessage;

  const ExpandNodeResult({
    required this.success,
    this.isSaturated = false,
    this.saturationReason,
    this.errorMessage,
  });
}

class DiagramController extends ChangeNotifier {
  final DiagramRepository _repository = DiagramRepository();
  final TransformationController transformController = TransformationController();

  DiagramModel? _diagram;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isLoadingSaved = false;
  String? _errorMessage;
  DiagramNodeModel? _selectedNode;
  String _searchQuery = '';
  bool _isExpandingNode = false;
  DiagramNodeModel? _draggedNode;
  List<SavedMindMapSummaryModel> _savedMindMaps = [];
  bool _isActiveRecallMode = false;
  final Set<String> _revealedNodeIds = {};

  DiagramModel? get diagram => _diagram;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get isLoadingSaved => _isLoadingSaved;
  bool get isExpandingNode => _isExpandingNode;
  String? get errorMessage => _errorMessage;
  DiagramNodeModel? get selectedNode => _selectedNode;
  DiagramNodeModel? get draggedNode => _draggedNode;
  String get searchQuery => _searchQuery;
  List<SavedMindMapSummaryModel> get savedMindMaps => _savedMindMaps;
  MindMapLayoutStyle get layoutStyle => _diagram?.layoutStyle ?? MindMapLayoutStyle.radial;
  bool get isCustomPositions => _diagram?.isCustomPositions ?? false;
  bool get isActiveRecallMode => _isActiveRecallMode;
  Set<String> get revealedNodeIds => _revealedNodeIds;
  int get revealedCount => _revealedNodeIds.length;
  int get totalTestableNodes => _diagram?.nodes.where((n) => !n.isRoot).length ?? 0;

  void toggleActiveRecallMode() {
    _isActiveRecallMode = !_isActiveRecallMode;
    if (_isActiveRecallMode) {
      _revealedNodeIds.clear();
    }
    _version++;
    notifyListeners();
  }

  void revealNode(String nodeId) {
    if (!_revealedNodeIds.contains(nodeId)) {
      _revealedNodeIds.add(nodeId);
      _version++;
      notifyListeners();
    }
  }

  void revealAllNodes() {
    if (_diagram != null) {
      for (final n in _diagram!.nodes) {
        if (!n.isRoot) {
          _revealedNodeIds.add(n.id);
        }
      }
      _version++;
      notifyListeners();
    }
  }

  void resetActiveRecall() {
    _revealedNodeIds.clear();
    _version++;
    notifyListeners();
  }

  int _version = 0;
  int get version => _version;

  void refreshDiagram({Size canvasSize = const Size(2800, 2000)}) {
    if (_diagram == null) return;
    _diagram!.calculateLayout(canvasSize);
    _diagram!.resolveCollisions();
    resetView();
    _version++;
    notifyListeners();
  }

  void selectNode(DiagramNodeModel? node) {
    _selectedNode = node;
    notifyListeners();
  }

  void startDraggingNode(DiagramNodeModel node) {
    _draggedNode = node;
    _selectedNode = node;
    notifyListeners();
  }

  void stopDraggingNode() {
    _draggedNode = null;
    if (_diagram != null) {
      _diagram!.resolveCollisions();
    }
    _version++;
    notifyListeners();
  }

  void moveNode(String nodeId, Offset delta, {bool moveSubtree = true}) {
    if (_diagram == null) return;
    _diagram!.moveNode(nodeId, delta, moveSubtree: moveSubtree);
    _version++;
    notifyListeners();
  }

  void changeLayoutStyle(MindMapLayoutStyle style, {Size canvasSize = const Size(2800, 2000)}) {
    if (_diagram == null) return;
    _diagram!.calculateLayout(canvasSize, style: style);
    _version++;
    notifyListeners();
  }

  void resetToAutoLayout({Size canvasSize = const Size(2800, 2000)}) {
    if (_diagram == null) return;
    _diagram!.calculateLayout(canvasSize);
    _version++;
    notifyListeners();
  }

  void focusNode(DiagramNodeModel node, Size viewportSize, {double zoomLevel = 1.15}) {
    final nodeCenterX = node.x + (node.width / 2);
    final nodeCenterY = node.y + (node.height / 2);
    final targetX = (viewportSize.width / 2) - (nodeCenterX * zoomLevel);
    final targetY = (viewportSize.height / 2) - (nodeCenterY * zoomLevel);

    final matrix = Matrix4.translationValues(targetX, targetY, 0.0)
      ..scaleByDouble(zoomLevel, zoomLevel, 1.0, 1.0);

    transformController.value = matrix;
    _selectedNode = node;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query.trim().toLowerCase();
    notifyListeners();
  }

  bool canWrapOrUnwrap(DiagramNodeModel node) {
    if (_diagram == null || node.isRoot) return false;
    return node.isCollapsed || _diagram!.hasChildren(node.id);
  }

  void toggleCollapse(String nodeId, {Size canvasSize = const Size(2800, 2000)}) {
    if (_diagram == null) return;
    final node = _diagram!.nodes.firstWhere(
      (n) => n.id == nodeId,
      orElse: () => DiagramNodeModel(id: '', label: ''),
    );
    if (node.id.isNotEmpty && !node.isRoot) {
      if (canWrapOrUnwrap(node)) {
        node.isCollapsed = !node.isCollapsed;
        _diagram!.calculateLayout(canvasSize);
        _version++;
        notifyListeners();
      }
    }
  }

  void toggleCollapseAll({Size canvasSize = const Size(2800, 2000)}) {
    if (_diagram == null) return;
    final collapsibleNodes = _diagram!.nodes.where((n) => canWrapOrUnwrap(n)).toList();
    if (collapsibleNodes.isEmpty) return;
    final anyExpanded = collapsibleNodes.any((n) => !n.isCollapsed);
    for (final n in collapsibleNodes) {
      n.isCollapsed = anyExpanded;
    }
    _diagram!.calculateLayout(canvasSize);
    _version++;
    notifyListeners();
  }

  /// Deletes a node and its entire subtree, recomputes the layout, and auto-syncs to database to reduce storage
  Future<bool> deleteNode(String nodeId, {Size canvasSize = const Size(2800, 2000)}) async {
    if (_diagram == null) return false;
    final node = _diagram!.nodes.firstWhere(
      (n) => n.id == nodeId,
      orElse: () => DiagramNodeModel(id: '', label: ''),
    );
    if (node.id.isEmpty || node.isRoot) {
      return false; // Root node cannot be deleted
    }

    // 1. Collect this node and all of its descendants recursively
    final idsToRemove = _diagram!.getSubtreeNodeIds(nodeId);

    // 2. Remove all gathered nodes from the diagram model
    _diagram!.nodes.removeWhere((n) => idsToRemove.contains(n.id));

    // 3. Remove all edges connected to any of the deleted nodes
    _diagram!.edges.removeWhere(
      (e) => idsToRemove.contains(e.fromId) || idsToRemove.contains(e.toId),
    );

    // 4. Reset selected node if it was in the deleted branch
    if (_selectedNode != null && idsToRemove.contains(_selectedNode!.id)) {
      _selectedNode = null;
    }

    // 5. Recompute the diagram layout with automated collision avoidance
    _diagram!.calculateLayout(canvasSize);
    _version++;
    notifyListeners();

    // 6. Auto-sync to PostgreSQL database to reduce stored size immediately
    if (_diagram!.id != null && _diagram!.id!.isNotEmpty) {
      await saveCurrentMindMap();
    }

    return true;
  }

  void zoomIn() {
    final matrix = transformController.value.clone();
    matrix.scaleByDouble(1.2, 1.2, 1.0, 1.0);
    transformController.value = matrix;
  }

  void zoomOut() {
    final matrix = transformController.value.clone();
    matrix.scaleByDouble(0.8, 0.8, 1.0, 1.0);
    transformController.value = matrix;
  }

  void resetView() {
    transformController.value = Matrix4.identity();
  }

  void centerOnDiagram(Size viewportSize, {double zoomLevel = 0.85}) {
    if (_diagram == null || _diagram!.nodes.isEmpty) {
      resetView();
      return;
    }
    final rootIndex = _diagram!.nodes.indexWhere((n) => n.isRoot);
    final targetNode = rootIndex != -1 ? _diagram!.nodes[rootIndex] : _diagram!.nodes.first;
    focusNode(targetNode, viewportSize, zoomLevel: zoomLevel);
  }

  Future<void> generateDiagram(
    String topic, {
    String? noteId,
    String diagramType = 'mindmap',
    Size canvasSize = const Size(2800, 2000),
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _repository.generateDiagram(
        topic: topic,
        noteId: noteId,
        diagramType: diagramType,
      );
      final hasServerLayout = result.nodes.any((n) => n.x != 0 || n.y != 0);
      if (!hasServerLayout) {
        result.calculateLayout(canvasSize);
      }
      _diagram = result;
      resetView();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setDiagramDirect(DiagramModel model, {Size canvasSize = const Size(2800, 2000)}) {
    final hasServerLayout = model.nodes.any((n) => n.x != 0 || n.y != 0);
    if (!hasServerLayout) {
      model.calculateLayout(canvasSize);
    }
    _diagram = model;
    resetView();
    notifyListeners();
  }

  void clearDiagram() {
    _diagram = null;
    _selectedNode = null;
    _errorMessage = null;
    notifyListeners();
  }

  int calculateNodeDepth(DiagramNodeModel targetNode) {
    if (_diagram == null) return 0;
    int depth = 0;
    String currentId = targetNode.id;
    final visited = <String>{currentId};
    while (true) {
      String? parentId;
      for (final edge in _diagram!.edges) {
        if (edge.toId == currentId) {
          parentId = edge.fromId;
          break;
        }
      }
      if (parentId == null || visited.contains(parentId)) break;
      visited.add(parentId);
      depth++;
      currentId = parentId;
    }
    return depth;
  }

  Future<ExpandNodeResult> expandNode(
    DiagramNodeModel node, {
    Size canvasSize = const Size(2800, 2000),
    bool force = false,
  }) async {
    if (_diagram == null) {
      return const ExpandNodeResult(success: false, errorMessage: 'Diagram not loaded');
    }
    _isExpandingNode = true;
    notifyListeners();

    try {
      final depth = calculateNodeDepth(node);
      final res = await _repository.expandNode(
        concept: _diagram!.concept,
        nodeId: node.id,
        nodeLabel: node.label,
        nodeDetails: node.description,
        branchColor: node.colorHex,
        mindMapId: _diagram!.id,
        nodeDepth: depth,
        force: force,
        parentX: node.x,
        parentY: node.y,
        parentWidth: node.width,
        parentHeight: node.height,
      );

      final isSaturated = res['is_saturated'] == true;
      final canExpand = res['can_expand'] != false;
      final saturationReason = res['saturation_reason'] as String?;

      if (!force && (isSaturated || !canExpand)) {
        return ExpandNodeResult(
          success: false,
          isSaturated: true,
          saturationReason: saturationReason ?? 'AI Advisory: Yeh topic already atomic depth par hai. Aage expand karne se conceptual confusion badh sakta hai.',
        );
      }

      final rawNodes = res['new_nodes'];
      final rawEdges = res['new_edges'];

      if (rawNodes is List) {
        for (final n in rawNodes) {
          if (n is Map) {
            final childNode = DiagramNodeModel.fromJson(Map<String, dynamic>.from(n));
            if (!_diagram!.nodes.any((existing) => existing.id == childNode.id)) {
              _diagram!.nodes.add(childNode);
            }
          }
        }
      }

      if (rawEdges is List) {
        for (final e in rawEdges) {
          if (e is Map) {
            final childEdge = DiagramEdgeModel.fromJson(Map<String, dynamic>.from(e));
            if (!_diagram!.edges.any((existing) => existing.fromId == childEdge.fromId && existing.toId == childEdge.toId)) {
              _diagram!.edges.add(childEdge);
            }
          }
        }
      }

      final hasServerCoords = rawNodes is List && rawNodes.any((n) => n is Map && (n['x'] != null && n['x'] != 0));
      if (!hasServerCoords) {
        _diagram!.calculateLayout(canvasSize);
      } else {
        _diagram!.resolveCollisions();
      }

      // Auto-persist expanded sub-branches in PostgreSQL database
      if (_diagram!.id != null && _diagram!.id!.isNotEmpty) {
        await saveCurrentMindMap();
      }

      return const ExpandNodeResult(success: true);
    } catch (e) {
      _errorMessage = e.toString();
      return ExpandNodeResult(success: false, errorMessage: e.toString());
    } finally {
      _isExpandingNode = false;
      _version++;
      notifyListeners();
    }
  }

  // --- CRUD PERSISTENCE METHODS ---

  Future<void> loadSavedMindMaps({String? search}) async {
    _isLoadingSaved = true;
    notifyListeners();

    try {
      _savedMindMaps = await _repository.listMindMaps(search: search);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoadingSaved = false;
      notifyListeners();
    }
  }

  Future<bool> saveCurrentMindMap({String? customTitle}) async {
    if (_diagram == null) return false;
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final title = (customTitle != null && customTitle.trim().isNotEmpty)
          ? customTitle.trim()
          : _diagram!.title;
      final data = _diagram!.toJson();

      if (_diagram!.id != null && _diagram!.id!.isNotEmpty) {
        final updated = await _repository.updateMindMap(
          id: _diagram!.id!,
          title: title,
          data: data,
        );
        _diagram!.id = updated.id;
        _diagram!.isPinned = updated.isPinned;
      } else {
        final saved = await _repository.saveMindMap(
          title: title,
          concept: _diagram!.title,
          diagramType: _diagram!.diagramType,
          domainType: _diagram!.domainType,
          data: data,
          isPinned: _diagram!.isPinned,
        );
        _diagram!.id = saved.id;
        _diagram!.isPinned = saved.isPinned;
      }

      await loadSavedMindMaps();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> loadMindMapById(String id, {Size canvasSize = const Size(1200, 900)}) async {
    _isLoading = true;
    _errorMessage = null;
    _selectedNode = null;
    notifyListeners();

    try {
      final model = await _repository.getMindMap(id);
      final hasServerLayout = model.nodes.any((n) => n.x != 0 || n.y != 0);
      if (!hasServerLayout) {
        model.calculateLayout(canvasSize);
      }
      _diagram = model;
      resetView();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteSavedMindMap(String id) async {
    try {
      await _repository.deleteMindMap(id);
      _savedMindMaps.removeWhere((item) => item.id == id);
      if (_diagram?.id == id) {
        _diagram = null;
        _selectedNode = null;
      }
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> togglePinSavedMindMap(String id) async {
    try {
      final updated = await _repository.togglePin(id);
      if (_diagram?.id == id) {
        _diagram!.isPinned = updated.isPinned;
      }
      await loadSavedMindMaps();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ⚡ 1-Tap Mind Map to Active Recall Quiz
  Future<Map<String, dynamic>?> generateQuizFromMindMap({int numQuestions = 5, String difficulty = 'medium'}) async {
    if (_diagram == null) return null;
    try {
      final nodesData = _diagram!.nodes.map((n) => n.toJson()).toList();
      final quizData = await _repository.generateQuizFromMindMap(
        concept: _diagram!.concept,
        title: _diagram!.title,
        archetype: _diagram!.archetype,
        nodes: nodesData,
        numQuestions: numQuestions,
        difficulty: difficulty,
      );
      return quizData;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  // ⚡ 1-Tap Mind Map to 3D Flip Flashcards
  Future<Map<String, dynamic>?> generateFlashcardsFromMindMap({int cardCount = 6, String difficulty = 'medium', bool saveDeck = true}) async {
    if (_diagram == null) return null;
    try {
      final nodesData = _diagram!.nodes.map((n) => n.toJson()).toList();
      final deckData = await _repository.generateFlashcardsFromMindMap(
        concept: _diagram!.concept,
        title: _diagram!.title,
        archetype: _diagram!.archetype,
        nodes: nodesData,
        cardCount: cardCount,
        difficulty: difficulty,
        saveDeck: saveDeck,
      );
      return deckData;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  // 🖨️ Export High-Res Printable Vector PDF Poster
  Future<List<int>?> exportMindMapPDF({String paperSize = 'A4'}) async {
    if (_diagram == null) return null;
    try {
      final nodesData = _diagram!.nodes.map((n) => n.toJson()).toList();
      final edgesData = _diagram!.edges.map((e) => e.toJson()).toList();
      final pdfBytes = await _repository.exportMindMapPDF(
        title: _diagram!.title,
        concept: _diagram!.concept,
        archetype: _diagram!.archetype,
        summary: _diagram!.summary,
        nodes: nodesData,
        edges: edgesData,
        paperSize: paperSize,
      );
      return pdfBytes;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }
}
