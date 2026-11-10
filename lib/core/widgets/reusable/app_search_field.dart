import 'dart:async';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

/// Universal Production-Grade Search Input Field for ShopSilo.
/// Features built-in debouncing, clear button, optional barcode scanner button,
/// and consistent styling across POS, Inventory, Khata, and Procurement screens.
class AppSearchField extends StatefulWidget {
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final VoidCallback? onBarcodeTap;
  final String hintText;
  final bool autofocus;
  final Duration debounceDuration;
  final FocusNode? focusNode;

  const AppSearchField({
    super.key,
    this.controller,
    this.onChanged,
    this.onClear,
    this.onBarcodeTap,
    this.hintText = 'Search items by name, brand, or SKU...',
    this.autofocus = false,
    this.debounceDuration = const Duration(milliseconds: 250),
    this.focusNode,
  });

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  late final TextEditingController _internalController;
  Timer? _debounceTimer;
  bool _hasText = false;

  TextEditingController get _effectiveController =>
      widget.controller ?? _internalController;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _internalController = TextEditingController();
    }
    _hasText = _effectiveController.text.isNotEmpty;
    _effectiveController.addListener(_onTextChange);
  }

  void _onTextChange() {
    final hasText = _effectiveController.text.isNotEmpty;
    if (_hasText != hasText) {
      setState(() => _hasText = hasText);
    }
  }

  void _handleChanged(String value) {
    if (widget.onChanged == null) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(widget.debounceDuration, () {
      if (mounted) {
        widget.onChanged!(value);
      }
    });
  }

  void _handleClear() {
    _effectiveController.clear();
    widget.onClear?.call();
    widget.onChanged?.call('');
  }

  @override
  void dispose() {
    _effectiveController.removeListener(_onTextChange);
    if (widget.controller == null) {
      _internalController.dispose();
    }
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: context.colorSurfaceSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colorBorder, width: 1.0),
      ),
      child: TextField(
        controller: _effectiveController,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        onChanged: _handleChanged,
        textAlignVertical: TextAlignVertical.center,
        style: TextStyle(
          fontSize: 14,
          color: context.colorTextPrimary,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
          enabledBorder: InputBorder.none,
          hintText: widget.hintText,
          hintStyle: TextStyle(
            fontSize: 13.5,
            color: context.colorTextMuted,
            fontWeight: FontWeight.normal,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 20,
            color: context.colorTextMuted,
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_hasText)
                IconButton(
                  icon: const Icon(Icons.cancel_rounded, size: 18),
                  color: context.colorTextMuted,
                  tooltip: 'Clear',
                  splashRadius: 18,
                  onPressed: _handleClear,
                ),
              if (widget.onBarcodeTap != null)
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                  color: AppColors.primary,
                  tooltip: 'Scan Barcode',
                  splashRadius: 18,
                  onPressed: widget.onBarcodeTap,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
