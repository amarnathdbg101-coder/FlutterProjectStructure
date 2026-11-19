import 'dart:async';

import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../localization/language_controller.dart';
import '../../services/voice_input_service.dart';
import 'app_voice_icon_button.dart';

/// Universal Production-Grade Search Input Field for ShopSilo.
/// Features built-in debouncing, clear button, speech-to-text voice search,
/// and consistent styling across screens.
class AppSearchField extends StatefulWidget {
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final String hintText;
  final bool autofocus;
  final bool enableVoice;
  final bool showSubmitButton;
  final Duration debounceDuration;
  final FocusNode? focusNode;

  const AppSearchField({
    super.key,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.hintText = 'Search items by name, brand, or SKU...',
    this.autofocus = false,
    this.enableVoice = true,
    this.showSubmitButton = false,
    this.debounceDuration = const Duration(milliseconds: 250),
    this.focusNode,
  });

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  late final TextEditingController _internalController;
  FocusNode? _internalFocusNode;
  Timer? _debounceTimer;
  bool _hasText = false;

  TextEditingController get _effectiveController =>
      widget.controller ?? _internalController;

  FocusNode get _effectiveFocusNode =>
      widget.focusNode ?? (_internalFocusNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _internalController = TextEditingController();
    }
    _hasText = _effectiveController.text.isNotEmpty;
    _effectiveController.addListener(_onTextChange);
    _effectiveFocusNode.addListener(_onFocusChange);
  }

  void _onTextChange() {
    final hasText = _effectiveController.text.isNotEmpty;
    if (_hasText != hasText) {
      setState(() => _hasText = hasText);
    }
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
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
    _effectiveFocusNode.removeListener(_onFocusChange);
    _internalFocusNode?.dispose();
    if (widget.controller == null) {
      _internalController.dispose();
    }
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final voiceService = AppVoiceInputService.instance;

    return ListenableBuilder(
      listenable: voiceService,
      builder: (context, _) {
        final isListening = voiceService.isListeningTo(_effectiveController);
        final isFocused = _effectiveFocusNode.hasFocus;
        bool isHindi = false;
        try {
          isHindi = context.isHindi;
        } catch (_) {
          isHindi = false;
        }

        final dynamicHint = isListening
            ? (isHindi ? 'सुन रहे हैं... बोलिए' : 'Listening... speak now')
            : widget.hintText;

        return Container(
          height: 52,
          decoration: BoxDecoration(
            color: context.colorSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isListening
                  ? AppColors.error
                  : (isFocused ? AppColors.primary : context.colorBorder),
              width: isListening || isFocused ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isListening
                    ? AppColors.error.withValues(alpha: 0.15)
                    : Colors.black.withValues(
                        alpha: context.isDark ? 0.2 : 0.03,
                      ),
                blurRadius: isListening ? 8 : 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Icon(
                isListening ? Icons.graphic_eq_rounded : Icons.search_rounded,
                size: 20,
                color: isListening
                    ? AppColors.error
                    : (isFocused ? AppColors.primary : context.colorTextMuted),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: _effectiveController,
                  focusNode: _effectiveFocusNode,
                  autofocus: widget.autofocus,
                  onChanged: _handleChanged,
                  onSubmitted: (val) {
                    _debounceTimer?.cancel();
                    widget.onChanged?.call(val);
                    widget.onSubmitted?.call(val);
                  },
                  textAlignVertical: TextAlignVertical.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: context.colorTextPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    hintText: dynamicHint,
                    hintStyle: TextStyle(
                      fontSize: 13.5,
                      color: isListening
                          ? AppColors.error
                          : context.colorTextMuted,
                      fontWeight: isListening
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
              if (_hasText)
                IconButton(
                  tooltip: isHindi ? 'खोज साफ़ करें' : 'Clear search',
                  constraints: const BoxConstraints.tightFor(
                    width: 44,
                    height: 44,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: _handleClear,
                  icon: Icon(
                    Icons.cancel_rounded,
                    size: 18,
                    color: context.colorTextMuted,
                  ),
                ),
              if (widget.enableVoice) ...[
                const SizedBox(width: 2),
                AppVoiceIconButton(
                  controller: _effectiveController,
                  hint: widget.hintText,
                  size: 20,
                  styledButton: false,
                  onChanged: (val) {
                    _handleChanged(val);
                  },
                  onSubmitted: (val) {
                    _handleChanged(val);
                    widget.onSubmitted?.call(val);
                  },
                ),
              ],
              if (widget.showSubmitButton) ...[
                const SizedBox(width: 4),
                Material(
                  color: context.isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      _debounceTimer?.cancel();
                      widget.onChanged?.call(_effectiveController.text.trim());
                      widget.onSubmitted?.call(
                        _effectiveController.text.trim(),
                      );
                    },
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Tooltip(
                        message: isHindi ? 'खोजें' : 'Search',
                        child: const Icon(
                          Icons.search_rounded,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
