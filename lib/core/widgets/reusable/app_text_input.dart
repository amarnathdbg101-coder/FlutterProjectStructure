import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/app_colors.dart';

/// Universal Standardized Form Input Field for ShopSilo.
/// Replaces inconsistent Raw TextFields and TextFormFields across POS, Products, and Khata.
class AppTextInput extends StatefulWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final String? prefixText;
  final IconData? prefixIcon;
  final Widget? suffix;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixIconTap;
  final bool isPassword;
  final bool isRequired;
  final bool readOnly;
  final bool autofocus;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final FocusNode? focusNode;

  const AppTextInput({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.prefixText,
    this.prefixIcon,
    this.suffix,
    this.suffixIcon,
    this.onSuffixIconTap,
    this.isPassword = false,
    this.isRequired = false,
    this.readOnly = false,
    this.autofocus = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.inputFormatters,
    this.maxLines = 1,
    this.focusNode,
  });

  @override
  State<AppTextInput> createState() => _AppTextInputState();
}

class _AppTextInputState extends State<AppTextInput> {
  bool _obscureText = true;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.isPassword;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Row(
            children: [
              Text(
                widget.label!,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: context.colorTextPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              if (widget.isRequired)
                const Text(
                  ' *',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.error,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        TextFormField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          autofocus: widget.autofocus,
          readOnly: widget.readOnly,
          obscureText: widget.isPassword ? _obscureText : false,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onSubmitted,
          validator: widget.validator,
          inputFormatters: widget.inputFormatters,
          maxLines: widget.isPassword ? 1 : widget.maxLines,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: context.colorTextPrimary,
          ),
          decoration: InputDecoration(
            isDense: true,
            hintText: widget.hint,
            hintStyle: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.normal,
              color: context.colorTextMuted,
            ),
            errorText: widget.errorText,
            helperText: widget.helperText,
            filled: true,
            fillColor: isDark ? context.colorSurfaceSubtle : context.colorSurface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            prefixText: widget.prefixText != null ? '${widget.prefixText} ' : null,
            prefixStyle: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: context.colorTextPrimary,
            ),
            prefixIcon: widget.prefixIcon != null
                ? Icon(widget.prefixIcon, size: 18, color: context.colorTextMuted)
                : null,
            suffix: widget.suffix,
            suffixIcon: widget.isPassword
                ? IconButton(
                    icon: Icon(
                      _obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 18,
                      color: context.colorTextMuted,
                    ),
                    onPressed: () => setState(() => _obscureText = !_obscureText),
                  )
                : (widget.suffixIcon != null
                    ? IconButton(
                        icon: Icon(widget.suffixIcon, size: 18, color: context.colorTextMuted),
                        onPressed: widget.onSuffixIconTap,
                      )
                    : null),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: isDark ? context.colorBorder : AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: isDark ? context.colorBorder : AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.error, width: 1.2),
            ),
          ),
        ),
      ],
    );
  }
}

