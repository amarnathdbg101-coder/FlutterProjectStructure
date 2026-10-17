import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/ai_language_service.dart';
import '../../../core/storage/hive_storage.dart';
import '../models/diagram_model.dart';

class DiagramRepository {
  final Dio _dio = ApiClient().dio;

  Future<DiagramModel> generateDiagram({
    required String topic,
    String? noteId,
    String diagramType = 'mindmap',
  }) async {
    final selectedLang = AILanguageService.getSelectedLanguageSync();
    final response = await _dio.post(
      ApiConstants.aiDiagram,
      data: {
        'concept': topic,
        'topic': topic,
        'depth': 3,
        if (noteId != null && noteId.isNotEmpty) 'note_id': noteId,
        'diagram_type': diagramType,
        if (selectedLang.isNotEmpty) 'ai_language': selectedLang,
        if (selectedLang.isNotEmpty) 'language': selectedLang,
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
    String? mindMapId,
    int nodeDepth = 0,
    bool force = false,
  }) async {
    final selectedLang = AILanguageService.getSelectedLanguageSync();
    final response = await _dio.post(
      ApiConstants.aiDiagramExpand,
      data: {
        'concept': concept,
        'node_id': nodeId,
        'node_label': nodeLabel,
        'node_details': nodeDetails ?? '',
        'branch_color': branchColor ?? '#0EA5E9',
        'node_depth': nodeDepth,
        'force': force,
        if (mindMapId != null && mindMapId.isNotEmpty) 'mind_map_id': mindMapId,
        if (selectedLang.isNotEmpty) 'ai_language': selectedLang,
        if (selectedLang.isNotEmpty) 'language': selectedLang,
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
      final model = DiagramModel.fromJson(resData);
      if (model.id != null) {
        await HiveStorage.cacheMindMap(model.id!, resData);
      }
      return model;
    }
    throw Exception(response.data['message'] ?? 'Failed to save mind map');
  }

  // 2. List saved mind maps (Offline-first with Hive cache)
  Future<List<SavedMindMapSummaryModel>> listMindMaps({
    String? search,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
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
          final list = rawList
              .map((e) => SavedMindMapSummaryModel.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
          // Cache to Hive for 0ms offline loads
          await HiveStorage.cacheMindMapList(rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList());
          return list;
        }
        return [];
      }
    } catch (_) {
      // Fallback to offline cached mind maps if network fails
      final cached = HiveStorage.getCachedMindMapList();
      if (cached.isNotEmpty) {
        return cached.map((e) => SavedMindMapSummaryModel.fromJson(e)).toList();
      }
    }
    return [];
  }

  // 3. Get single mind map with full node/edge canvas data (Offline-first)
  Future<DiagramModel> getMindMap(String id) async {
    try {
      final response = await _dio.get('${ApiConstants.aiMindMaps}/$id');
      if (response.statusCode == 200 && response.data['data'] != null) {
        final resData = response.data['data'] as Map<String, dynamic>;
        await HiveStorage.cacheMindMap(id, resData);
        return DiagramModel.fromJson(resData);
      }
    } catch (_) {
      // Fallback to local Hive cache for instant 0ms offline view
      final cached = HiveStorage.getCachedMindMap(id);
      if (cached != null) {
        return DiagramModel.fromJson(cached);
      }
    }
    final cached = HiveStorage.getCachedMindMap(id);
    if (cached != null) {
      return DiagramModel.fromJson(cached);
    }
    throw Exception('Failed to load mind map from cloud and no local offline cache found');
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

  // 7. ⚡ 1-Tap Mind Map to Quiz Conversion
  Future<Map<String, dynamic>> generateQuizFromMindMap({
    required String concept,
    String? title,
    String? archetype,
    required List<Map<String, dynamic>> nodes,
    int numQuestions = 5,
    String difficulty = 'medium',
  }) async {
    final response = await _dio.post(
      ApiConstants.aiDiagramGenerateQuiz,
      data: {
        'concept': concept,
        if (title != null) 'title': title,
        if (archetype != null) 'archetype': archetype,
        'nodes': nodes,
        'num_questions': numQuestions,
        'difficulty': difficulty,
      },
    );

    if (response.statusCode == 200 && response.data['data'] != null) {
      return Map<String, dynamic>.from(response.data['data'] as Map);
    }
    throw Exception(response.data['message'] ?? 'Failed to generate quiz from mind map');
  }

  // 8. ⚡ 1-Tap Mind Map to 3D Flip Flashcards
  Future<Map<String, dynamic>> generateFlashcardsFromMindMap({
    required String concept,
    String? title,
    String? archetype,
    required List<Map<String, dynamic>> nodes,
    int cardCount = 6,
    String difficulty = 'medium',
    bool saveDeck = false,
  }) async {
    final response = await _dio.post(
      ApiConstants.aiDiagramGenerateFlashcards,
      data: {
        'concept': concept,
        if (title != null) 'title': title,
        if (archetype != null) 'archetype': archetype,
        'nodes': nodes,
        'card_count': cardCount,
        'difficulty': difficulty,
        'save_deck': saveDeck,
      },
    );

    if (response.statusCode == 200 && response.data['data'] != null) {
      return Map<String, dynamic>.from(response.data['data'] as Map);
    }
    throw Exception(response.data['message'] ?? 'Failed to generate flashcards from mind map');
  }

  // 9. 🖨️ High-Res Vector PDF Wall Poster Exporter
  Future<List<int>> exportMindMapPDF({
    required String title,
    required String concept,
    String? archetype,
    String? summary,
    required List<Map<String, dynamic>> nodes,
    required List<Map<String, dynamic>> edges,
    String paperSize = 'A4',
  }) async {
    final response = await _dio.post<List<int>>(
      ApiConstants.aiDiagramExportPdf,
      data: {
        'title': title,
        'concept': concept,
        if (archetype != null) 'archetype': archetype,
        if (summary != null) 'summary': summary,
        'nodes': nodes,
        'edges': edges,
        'paper_size': paperSize,
      },
      options: Options(responseType: ResponseType.bytes),
    );

    if (response.statusCode == 200 && response.data != null) {
      return response.data!;
    }
    throw Exception('Failed to export mind map PDF poster');
  }
}
