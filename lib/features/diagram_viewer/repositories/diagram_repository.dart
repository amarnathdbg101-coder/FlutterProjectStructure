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

  Future<Map<String, dynamic>> expandNode({
    required String concept,
    required String nodeId,
    required String nodeLabel,
    String? nodeDetails,
    String? branchColor,
  }) async {
    final response = await _dio.post(
      ApiConstants.aiDiagramExpand,
      data: {
        'concept': concept,
        'node_id': nodeId,
        'node_label': nodeLabel,
        'node_details': nodeDetails ?? '',
        'branch_color': branchColor ?? '#0EA5E9',
      },
    );

    if (response.statusCode == 200 && response.data['data'] != null) {
      return response.data['data'] as Map<String, dynamic>;
    }
    throw Exception('Failed to expand node');
  }

  // 1. Save MindMap to database
  Future<DiagramModel> saveMindMap({
    required String title,
    required String concept,
    String diagramType = 'mindmap',
    String? domainType,
    String? noteId,
    required Map<String, dynamic> data,
    bool isPinned = false,
  }) async {
    final response = await _dio.post(
      ApiConstants.aiMindMaps,
      data: {
        'title': title,
        'concept': concept,
        'diagram_type': diagramType,
        'domain_type': domainType ?? 'general',
        if (noteId != null && noteId.isNotEmpty) 'note_id': noteId,
        'data': data,
        'is_pinned': isPinned,
      },
    );

    if (response.statusCode == 200 && response.data['data'] != null) {
      final resData = response.data['data'] as Map<String, dynamic>;
      return DiagramModel.fromJson(resData);
    }
    throw Exception(response.data['message'] ?? 'Failed to save mind map');
  }

  // 2. List saved mind maps
  Future<List<SavedMindMapSummaryModel>> listMindMaps({
    String? search,
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _dio.get(
      ApiConstants.aiMindMaps,
      queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
        'limit': limit,
        'offset': offset,
      },
    );

    if (response.statusCode == 200 && response.data['data'] != null) {
      final data = response.data['data'];
      final rawList = data is Map ? (data['items'] as List?) : (data as List?);
      if (rawList != null) {
        return rawList
            .map((e) => SavedMindMapSummaryModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      return [];
    }
    throw Exception(response.data['message'] ?? 'Failed to list mind maps');
  }

  // 3. Get single mind map with full node/edge canvas data
  Future<DiagramModel> getMindMap(String id) async {
    final response = await _dio.get('${ApiConstants.aiMindMaps}/$id');
    if (response.statusCode == 200 && response.data['data'] != null) {
      final resData = response.data['data'] as Map<String, dynamic>;
      return DiagramModel.fromJson(resData);
    }
    throw Exception(response.data['message'] ?? 'Failed to load mind map');
  }

  // 4. Update title, data, or pinned state
  Future<DiagramModel> updateMindMap({
    required String id,
    String? title,
    Map<String, dynamic>? data,
    bool? isPinned,
  }) async {
    final Map<String, dynamic> body = {};
    if (title != null) body['title'] = title;
    if (data != null) body['data'] = data;
    if (isPinned != null) body['is_pinned'] = isPinned;

    final response = await _dio.put(
      '${ApiConstants.aiMindMaps}/$id',
      data: body,
    );

    if (response.statusCode == 200 && response.data['data'] != null) {
      final resData = response.data['data'] as Map<String, dynamic>;
      return DiagramModel.fromJson(resData);
    }
    throw Exception(response.data['message'] ?? 'Failed to update mind map');
  }

  // 5. Delete mind map
  Future<void> deleteMindMap(String id) async {
    final response = await _dio.delete('${ApiConstants.aiMindMaps}/$id');
    if (response.statusCode != 200) {
      throw Exception(response.data['message'] ?? 'Failed to delete mind map');
    }
  }

  // 6. Toggle pin status
  Future<DiagramModel> togglePin(String id) async {
    final response = await _dio.patch('${ApiConstants.aiMindMaps}/$id/pin');
    if (response.statusCode == 200 && response.data['data'] != null) {
      final resData = response.data['data'] as Map<String, dynamic>;
      return DiagramModel.fromJson(resData);
    }
    throw Exception(response.data['message'] ?? 'Failed to toggle pin');
  }
}
