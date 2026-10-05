import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/api_key_entry.dart';

/// Secure on-device Multi-API-Key Vault and Key-Swap Engine.
class ApiKeyVaultService {
  static final ApiKeyVaultService _instance = ApiKeyVaultService._internal();
  factory ApiKeyVaultService() => _instance;
  ApiKeyVaultService._internal();

  static const String _diskKeyVault = 'studysilo_api_key_vault_v1';
  static const String _diskKeyActiveIndex = 'studysilo_api_key_active_index_v1';
  static const String _legacySinglePrefKey = 'gemini_api_key';

  List<ApiKeyEntry> _cachedKeys = [];
  int _activeKeyIndex = 0;
  bool _isInitialized = false;

  final ValueNotifier<List<ApiKeyEntry>> keysNotifier = ValueNotifier<List<ApiKeyEntry>>([]);
  final ValueNotifier<int> activeKeyIndexNotifier = ValueNotifier<int>(0);
  final ValueNotifier<String> activeKeyNotifier = ValueNotifier<String>('');

  List<ApiKeyEntry> get allKeys => List.unmodifiable(_cachedKeys);
  int get activeKeyIndex => _activeKeyIndex;
  bool get hasCustomKeys => _cachedKeys.isNotEmpty;
  int get keyCount => _cachedKeys.length;

  ApiKeyEntry? get activeKeyEntry {
    if (_cachedKeys.isEmpty) return null;
    if (_activeKeyIndex < 0 || _activeKeyIndex >= _cachedKeys.length) {
      _activeKeyIndex = 0;
    }
    return _cachedKeys[_activeKeyIndex];
  }

  String get activeApiKey {
    final entry = activeKeyEntry;
    return entry != null ? entry.key.trim() : '';
  }

  Future<void> loadVault({bool forceReload = false}) async {
    if (_isInitialized && !forceReload) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final vaultJson = prefs.getString(_diskKeyVault);
      final savedIndex = prefs.getInt(_diskKeyActiveIndex) ?? 0;

      if (vaultJson != null && vaultJson.trim().isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(vaultJson);
        _cachedKeys = decoded
            .map((item) => ApiKeyEntry.fromJson(Map<String, dynamic>.from(item as Map)))
            .where((entry) => entry.key.trim().isNotEmpty)
            .toList();
      } else {
        final legacyKey = prefs.getString(_legacySinglePrefKey);
        if (legacyKey != null && legacyKey.trim().isNotEmpty) {
          _cachedKeys = [ApiKeyEntry.create(key: legacyKey.trim(), label: 'Primary Gemini Key')];
          await _saveToDisk();
        }
      }

      if (_cachedKeys.isNotEmpty) {
        _activeKeyIndex = savedIndex.clamp(0, _cachedKeys.length - 1);
      } else {
        _activeKeyIndex = 0;
      }

      _isInitialized = true;
      _broadcastUpdates();
    } catch (e) {
      debugPrint('ApiKeyVaultService load error: $e');
    }
  }

  Future<ApiKeyEntry> addKey(String key, {String? label}) async {
    await loadVault();
    final cleanKey = key.trim();
    if (cleanKey.isEmpty) {
      throw Exception('API Key cannot be empty.');
    }

    final existingIdx = _cachedKeys.indexWhere((k) => k.key.trim() == cleanKey);
    if (existingIdx != -1) {
      _activeKeyIndex = existingIdx;
      await _saveToDisk();
      _broadcastUpdates();
      return _cachedKeys[existingIdx];
    }

    final newEntry = ApiKeyEntry.create(
      key: cleanKey,
      label: label,
      existingCount: _cachedKeys.length,
    );

    _cachedKeys.add(newEntry);
    if (_cachedKeys.length == 1) {
      _activeKeyIndex = 0;
    }

    await _saveToDisk();
    _broadcastUpdates();
    return newEntry;
  }

  Future<void> removeKey(String id) async {
    await loadVault();
    final idx = _cachedKeys.indexWhere((k) => k.id == id);
    if (idx == -1) return;

    _cachedKeys.removeAt(idx);

    if (_cachedKeys.isEmpty) {
      _activeKeyIndex = 0;
    } else if (_activeKeyIndex >= _cachedKeys.length) {
      _activeKeyIndex = _cachedKeys.length - 1;
    }

    await _saveToDisk();
    _broadcastUpdates();
  }

  Future<void> setActiveIndex(int index) async {
    await loadVault();
    if (_cachedKeys.isEmpty) return;

    _activeKeyIndex = index.clamp(0, _cachedKeys.length - 1);
    await _saveToDisk();
    _broadcastUpdates();
  }

  Future<ApiKeyEntry?> swapToNextKey() async {
    await loadVault();
    if (_cachedKeys.isEmpty) return null;

    if (_cachedKeys.length == 1) {
      _activeKeyIndex = 0;
      _broadcastUpdates();
      return _cachedKeys.first;
    }

    _activeKeyIndex = (_activeKeyIndex + 1) % _cachedKeys.length;
    _cachedKeys[_activeKeyIndex] = _cachedKeys[_activeKeyIndex].copyWith(
      lastUsedAt: DateTime.now(),
      totalRequests: _cachedKeys[_activeKeyIndex].totalRequests + 1,
    );

    await _saveToDisk();
    _broadcastUpdates();
    return _cachedKeys[_activeKeyIndex];
  }

  Future<void> _saveToDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _cachedKeys.map((e) => e.toJson()).toList();
      await prefs.setString(_diskKeyVault, jsonEncode(jsonList));
      await prefs.setInt(_diskKeyActiveIndex, _activeKeyIndex);
      if (_cachedKeys.isNotEmpty) {
        await prefs.setString(_legacySinglePrefKey, _cachedKeys[_activeKeyIndex].key);
      }
    } catch (e) {
      debugPrint('ApiKeyVaultService save error: $e');
    }
  }

  void _broadcastUpdates() {
    keysNotifier.value = List.unmodifiable(_cachedKeys);
    activeKeyIndexNotifier.value = _activeKeyIndex;
    activeKeyNotifier.value = activeApiKey;
  }
}
