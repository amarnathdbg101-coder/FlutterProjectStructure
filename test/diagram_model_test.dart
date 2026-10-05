import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_project_structure/features/diagram_viewer/models/diagram_model.dart';

void main() {
  group('Diagram Model & Layout Tests', () {
    test('DiagramModel JSON serialization and layout computation', () {
      final json = {
        'title': 'Quantum Physics Mind Map',
        'diagram_type': 'mindmap',
        'nodes': [
          {
            'id': 'root-1',
            'label': 'Quantum Mechanics',
            'node_type': 'root',
            'color_hex': '#4F46E5',
            'description': 'Fundamental theory in physics',
            'formulas': [r'i\hbar \frac{\partial \psi}{\partial t} = \hat{H}\psi'],
          },
          {
            'id': 'branch-1',
            'label': 'Wave Mechanics',
            'node_type': 'branch',
            'color_hex': '#0EA5E9',
            'description': 'Wave-particle duality and wavefunctions',
            'formulas': [r'\lambda = \frac{h}{p}'],
          },
          {
            'id': 'branch-2',
            'label': 'Matrix Mechanics',
            'node_type': 'branch',
            'color_hex': '#10B981',
            'description': 'Heisenberg representation',
          },
          {
            'id': 'leaf-1',
            'label': 'De Broglie Wavelength',
            'node_type': 'leaf',
            'color_hex': '#0EA5E9',
          },
        ],
        'edges': [
          {'from_id': 'root-1', 'to_id': 'branch-1', 'label': 'Includes'},
          {'from_id': 'root-1', 'to_id': 'branch-2', 'label': 'Includes'},
          {'from_id': 'branch-1', 'to_id': 'leaf-1', 'label': 'Defines'},
        ],
      };

      final diagram = DiagramModel.fromJson(json);
      expect(diagram.title, 'Quantum Physics Mind Map');
      expect(diagram.nodes.length, 4);
      expect(diagram.edges.length, 3);

      const canvasSize = Size(1200, 900);
      diagram.calculateLayout(canvasSize);

      // Verify Root is centered
      final root = diagram.nodes.firstWhere((n) => n.id == 'root-1');
      expect(root.x, closeTo(canvasSize.width / 2 - root.width / 2, 1.0));
      expect(root.y, closeTo(canvasSize.height / 2 - root.height / 2, 1.0));

      // Verify Branches are distanced from Root
      final branch1 = diagram.nodes.firstWhere((n) => n.id == 'branch-1');
      expect(branch1.x, isNot(equals(root.x)));
      expect(branch1.y, isNot(equals(root.y)));

      // Serialization test
      final serialized = diagram.toJson();
      expect(serialized['title'], 'Quantum Physics Mind Map');
      expect((serialized['nodes'] as List).length, 4);
    });

    test('DiagramModel parses hierarchical root tree and from/to edges seamlessly', () {
      final backendJson = {
        'concept': 'Thermodynamics',
        'diagram_type': 'mindmap',
        'root': {
          'id': 'root-1',
          'label': 'Thermodynamics Laws',
          'details': 'Core study of heat, energy, and work',
          'color_hex': '#4F46E5',
          'children': [
            {
              'id': 'branch-1',
              'label': 'First Law',
              'details': 'Energy conservation',
              'color_hex': '#0EA5E9',
              'children': [
                {
                  'id': 'leaf-1-1',
                  'label': 'Internal Energy',
                  'details': 'State function dU = dQ - dW',
                  'color_hex': '#38BDF8',
                  'children': [],
                },
              ],
            },
            {
              'id': 'branch-2',
              'label': 'Second Law',
              'details': 'Entropy and spontaneity',
              'color_hex': '#8B5CF6',
              'children': [],
            },
          ],
        },
        'edges': [
          {'from': 'root-1', 'to': 'branch-1', 'label': 'Governs'},
          {'from': 'root-1', 'to': 'branch-2', 'label': 'Governs'},
        ],
      };

      final diagram = DiagramModel.fromJson(backendJson);
      expect(diagram.title, 'Thermodynamics');
      expect(diagram.nodes.length, greaterThanOrEqualTo(4));
      expect(diagram.edges.length, greaterThanOrEqualTo(2));

      // Edge from and to should match node IDs
      final firstEdge = diagram.edges.first;
      expect(firstEdge.fromId, isNotEmpty);
      expect(firstEdge.toId, isNotEmpty);

      const canvasSize = Size(1400, 1000);
      diagram.calculateLayout(canvasSize);

      final root = diagram.nodes.firstWhere((n) => n.isRoot);
      expect(root.label, 'Thermodynamics Laws');
      expect(root.x, closeTo(1400 / 2 - root.width / 2, 1.0));
      expect(root.y, closeTo(1000 / 2 - root.height / 2, 1.0));
    });
  });
}
