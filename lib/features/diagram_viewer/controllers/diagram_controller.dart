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
  List<SavedMindMapSummaryModel> _savedMindMaps = [];

  DiagramModel? get diagram => _diagram;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get isLoadingSaved => _isLoadingSaved;
  bool get isExpandingNode => _isExpandingNode;
  String? get errorMessage => _errorMessage;
  DiagramNodeModel? get selectedNode => _selectedNode;
  String get searchQuery => _searchQuery;
  List<SavedMindMapSummaryModel> get savedMindMaps => _savedMindMaps;

  void selectNode(DiagramNodeModel? node) {
    _selectedNode = node;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query.trim().toLowerCase();
    notifyListeners();
  }

  void toggleCollapse(String branchId, {Size canvasSize = const Size(1400, 1000)}) {
    if (_diagram == null) return;
    final branch = _diagram!.nodes.firstWhere(
      (n) => n.id == branchId,
      orElse: () => DiagramNodeModel(id: '', label: ''),
    );
    if (branch.id.isNotEmpty && branch.isBranch) {
      branch.isCollapsed = !branch.isCollapsed;
      _diagram!.calculateLayout(canvasSize);
      notifyListeners();
    }
  }

  void toggleCollapseAll({Size canvasSize = const Size(1400, 1000)}) {
    if (_diagram == null) return;
    final branches = _diagram!.nodes.where((n) => n.isBranch).toList();
    if (branches.isEmpty) return;
    final anyExpanded = branches.any((b) => !b.isCollapsed);
    for (final b in branches) {
      b.isCollapsed = anyExpanded;
    }
    _diagram!.calculateLayout(canvasSize);
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
    Size canvasSize = const Size(1200, 900),
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

  void setDiagramDirect(DiagramModel model, {Size canvasSize = const Size(1200, 900)}) {
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

  Future<bool> expandNode(DiagramNodeModel node, {Size canvasSize = const Size(1400, 1000)}) async {
    if (_diagram == null) return false;
    _isExpandingNode = true;
    notifyListeners();

    try {
      final res = await _repository.expandNode(
        concept: _diagram!.title,
        nodeId: node.id,
        nodeLabel: node.label,
        nodeDetails: node.description,
        branchColor: node.colorHex,
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
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isExpandingNode = false;
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
}
