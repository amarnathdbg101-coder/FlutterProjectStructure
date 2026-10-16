import 'package:flutter/material.dart';
import '../models/diagram_model.dart';
import '../repositories/diagram_repository.dart';

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

  void toggleCollapse(String branchId, {Size canvasSize = const Size(2800, 2000)}) {
    if (_diagram == null) return;
    final branch = _diagram!.nodes.firstWhere(
      (n) => n.id == branchId,
      orElse: () => DiagramNodeModel(id: '', label: ''),
    );
    if (branch.id.isNotEmpty && branch.isBranch) {
      branch.isCollapsed = !branch.isCollapsed;
      _diagram!.calculateLayout(canvasSize);
      _version++;
      notifyListeners();
    }
  }

  void toggleCollapseAll({Size canvasSize = const Size(2800, 2000)}) {
    if (_diagram == null) return;
    final branches = _diagram!.nodes.where((n) => n.isBranch).toList();
    if (branches.isEmpty) return;
    final anyExpanded = branches.any((b) => !b.isCollapsed);
    for (final b in branches) {
      b.isCollapsed = anyExpanded;
    }
    _diagram!.calculateLayout(canvasSize);
    _version++;
    notifyListeners();
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
      result.calculateLayout(canvasSize);
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
    model.calculateLayout(canvasSize);
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

  Future<bool> expandNode(DiagramNodeModel node, {Size canvasSize = const Size(2800, 2000)}) async {
    if (_diagram == null) return false;
    _isExpandingNode = true;
    notifyListeners();

    try {
      final res = await _repository.expandNode(
        concept: _diagram!.concept,
        nodeId: node.id,
        nodeLabel: node.label,
        nodeDetails: node.description,
        branchColor: node.colorHex,
        mindMapId: _diagram!.id,
      );

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

      _diagram!.calculateLayout(canvasSize);

      // Auto-persist expanded sub-branches in PostgreSQL database
      if (_diagram!.id != null && _diagram!.id!.isNotEmpty) {
        await saveCurrentMindMap();
      }

      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
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
      model.calculateLayout(canvasSize);
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
