import 'package:flutter/material.dart';

class AppColors {
  // Static Primary Brand Colors
  static const Color primary = Color(0xFF4F46E5);      // Indigo
  static const Color primaryDark = Color(0xFF4338CA);

  // Static Light Theme Palette
  static const Color background = Color(0xFFF8FAFC);   // Crisp Slate 50
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSubtle = Color(0xFFF1F5F9); // Slate 100
  static const Color textPrimary = Color(0xFF0F172A);   // Slate 900
  static const Color textSecondary = Color(0xFF64748B); // Slate 500
  static const Color textMuted = Color(0xFF94A3B8);     // Slate 400
  static const Color border = Color(0xFFE2E8F0);        // Slate 200
  static const Color borderLight = Color(0xFFF1F5F9);
  static const Color primaryLight = Color(0xFFEEF2FF);

  // Static Dark Theme Palette
  static const Color darkBackground = Color(0xFF0F172A); // Slate 900
  static const Color darkSurface = Color(0xFF1E293B);    // Slate 800
  static const Color darkSurfaceSubtle = Color(0xFF334155); // Slate 700
  static const Color darkTextPrimary = Color(0xFFF8FAFC); // Slate 50
  static const Color darkTextSecondary = Color(0xFF94A3B8); // Slate 400
  static const Color darkTextMuted = Color(0xFF64748B);    // Slate 500
  static const Color darkBorder = Color(0xFF334155);       // Slate 700
  static const Color darkPrimaryLight = Color(0xFF312E81); // Deep Indigo

  // Semantic Status Colors
  static const Color success = Color(0xFF10B981);      // Emerald
  static const Color successLight = Color(0xFFECFDF5);
  static const Color darkSuccessLight = Color(0xFF064E3B);

  static const Color error = Color(0xFFEF4444);        // Rose / Red
  static const Color errorLight = Color(0xFFFEF2F2);
  static const Color darkErrorLight = Color(0xFF881337);

  static const Color warning = Color(0xFFF59E0B);      // Amber
  static const Color warningLight = Color(0xFFFFFBEB);
  static const Color darkWarningLight = Color(0xFF78350F);

  // Dynamic Theme Resolvers
  static Color getBg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkBackground : background;

  static Color getSurface(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkSurface : surface;

  static Color getSurfaceSubtle(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkSurfaceSubtle : surfaceSubtle;

  static Color getTextPrimary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkTextPrimary : textPrimary;

  static Color getTextSecondary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkTextSecondary : textSecondary;

  static Color getTextMuted(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkTextMuted : textMuted;

  static Color getBorder(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkBorder : border;

  static Color getPrimaryLight(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkPrimaryLight : primaryLight;

  static Color getSuccessLight(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkSuccessLight : successLight;

  static Color getErrorLight(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkErrorLight : errorLight;

  static Color getWarningLight(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkWarningLight : warningLight;
}

extension AppThemeColorX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  Color get colorPrimary => AppColors.primary;
  Color get colorBg => AppColors.getBg(this);
  Color get colorSurface => AppColors.getSurface(this);
  Color get colorSurfaceSubtle => AppColors.getSurfaceSubtle(this);
  Color get colorTextPrimary => AppColors.getTextPrimary(this);
  Color get colorTextSecondary => AppColors.getTextSecondary(this);
  Color get colorTextMuted => AppColors.getTextMuted(this);
  Color get colorBorder => AppColors.getBorder(this);
  Color get colorPrimaryLight => AppColors.getPrimaryLight(this);
  Color get colorSuccessLight => AppColors.getSuccessLight(this);
  Color get colorErrorLight => AppColors.getErrorLight(this);
  Color get colorWarningLight => AppColors.getWarningLight(this);
}
