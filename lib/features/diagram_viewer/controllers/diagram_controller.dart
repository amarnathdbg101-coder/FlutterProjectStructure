import 'package:flutter/material.dart';
import '../models/diagram_model.dart';
import '../repositories/diagram_repository.dart';

class DiagramController extends ChangeNotifier {
  final DiagramRepository _repository = DiagramRepository();
  final TransformationController transformController = TransformationController();

  DiagramModel? _diagram;
  bool _isLoading = false;
  String? _errorMessage;
  DiagramNodeModel? _selectedNode;

  DiagramModel? get diagram => _diagram;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  DiagramNodeModel? get selectedNode => _selectedNode;

  void selectNode(DiagramNodeModel? node) {
    _selectedNode = node;
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
}
