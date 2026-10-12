import 'package:flutter/material.dart';
import '../widgets/custom_snackbar.dart';

abstract class BaseController extends ChangeNotifier {
  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;

  void setLoading(bool value) {
    if (_isLoading != value) {
      _isLoading = value;
      notifyListeners();
    }
  }

  void setError(String? error, {bool showToast = true}) {
    _errorMessage = error;
    notifyListeners();
    if (error != null && error.trim().isNotEmpty && showToast) {
      CustomSnackbar.showError(null, error);
    }
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }
}
