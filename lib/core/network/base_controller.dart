import 'dart:async';

import 'package:flutter/material.dart';

import 'api_client.dart';
import '../widgets/custom_snackbar.dart';

abstract class BaseController extends ChangeNotifier {
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _errorAutoClearTimer;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasError =>
      _errorMessage != null && _errorMessage!.trim().isNotEmpty;

  void setLoading(bool value) {
    if (_isLoading != value) {
      _isLoading = value;
      notifyListeners();
    }
  }

  /// Sets an error message and automatically schedules its dismissal after [autoDismissDuration].
  /// This ensures error banners in screens automatically disappear without requiring manual dismissal.
  void setError(
    String? error, {
    bool showToast = true,
    Duration autoDismissDuration = const Duration(seconds: 4),
  }) {
    _errorAutoClearTimer?.cancel();
    final cleanError = error == null ? null : ApiClient.handleError(error);
    _errorMessage = cleanError;
    notifyListeners();

    if (cleanError != null && cleanError.trim().isNotEmpty) {
      if (showToast) {
        CustomSnackbar.showError(null, cleanError);
      }
      // Auto-clear error banner from UI after specified duration
      _errorAutoClearTimer = Timer(autoDismissDuration, () {
        clearError();
      });
    }
  }

  void clearError() {
    _errorAutoClearTimer?.cancel();
    _errorAutoClearTimer = null;
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _errorAutoClearTimer?.cancel();
    super.dispose();
  }
}
