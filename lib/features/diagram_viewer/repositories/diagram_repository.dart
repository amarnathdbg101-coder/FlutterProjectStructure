import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/diagram_model.dart';

class DiagramRepository {
  final Dio _dio = ApiClient().dio;

  Future<DiagramModel> generateDiagram({
    required String topic,
    String? noteId,
    String diagramType = 'mindmap',
  }) async {
    final response = await _dio.post(
      ApiConstants.aiDiagram,
      data: {
        'concept': topic,
        'topic': topic,
        'depth': 3,
        if (noteId != null && noteId.isNotEmpty) 'note_id': noteId,
        'diagram_type': diagramType,
      },
    );

    if (response.statusCode == 200 && response.data['data'] != null) {
      final data = response.data['data'] as Map<String, dynamic>;
      return DiagramModel.fromJson(data);
    }
    throw Exception('Failed to generate diagram');
  }
}
