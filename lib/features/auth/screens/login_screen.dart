import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/language_controller.dart';
import '../../../core/services/data_sync_service.dart';
import '../../../core/services/google_auth_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_ui_components.dart';
import '../../../core/widgets/google_logo_icon.dart';
import '../../../core/widgets/language_selector_dialog.dart';
import '../controllers/auth_controller.dart';

/// Clean, Zero-Friction 1-Tap Google Login Screen for ShopSilo Merchants.
/// Eliminates all passwords, form typing, and forgotten password resets.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isConnectingGoogle = false;

  Future<void> _handleGoogleSignIn() async {
    if (_isConnectingGoogle) return;

    setState(() => _isConnectingGoogle = true);
    final authController = context.read<AuthController>();
    authController.clearError();

    try {
      final googleResult = await GoogleAuthService.signIn();

      if (!googleResult.success || googleResult.idToken == null) {
        if (mounted) {
          setState(() => _isConnectingGoogle = false);
          if (!kIsWeb && Platform.isWindows) {
            _showDesktopPlatformNotice(context, googleResult.error ?? '');
          } else if (googleResult.error != null && !googleResult.error!.contains('cancelled')) {
            authController.setError(googleResult.error!);
          }
        }
        return;
      }

      final success = await authController.loginWithGoogle(
        googleResult.idToken!,
        role: 'shop',
      );

      if (mounted) {
        setState(() => _isConnectingGoogle = false);
      }

      if (success && mounted) {
        DataSyncService.syncOnLogin(context);
        // If merchant already has an active shop registered, go straight to dashboard.
        // Otherwise, navigate to merchant onboarding.
        if (authController.currentShop != null && authController.currentShop!.id.isNotEmpty) {
          context.go('/merchant');
        } else {
          context.go('/merchant');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isConnectingGoogle = false);
        authController.setError('Sign in failed: ${e.toString()}');
      }
    }
  }

  void _showDesktopPlatformNotice(BuildContext context, String message) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        final isDark = Theme.of(modalCtx).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Google Sign-In Notice',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(modalCtx),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Google ka official Sign-In SDK Android OS aur Chrome Web ke liye designed hai. Windows Desktop executable me Google Play Services nahi hoti.',
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.5,
                  color: isDark ? const Color(0xFFCBD5E1) : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Real Google Account Test Karne Ke Tarike:',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('1. ', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                        Expanded(
                          child: Text(
                            'Chrome Web (1-Click Popup): Terminal me "flutter run -d chrome" chalayein. Wahan real Google account selector popup khulega.',
                            style: TextStyle(fontSize: 12.5, color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('2. ', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                        Expanded(
                          child: Text(
                            'Android Phone / Emulator: "flutter run -d android" se phone par native Google Play Services bottom-sheet khulega.',
                            style: TextStyle(fontSize: 12.5, color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(modalCtx);
                    _showStaffPinDialog(context);
                  },
                  icon: const Icon(Icons.pin_rounded, size: 18),
                  label: const Text('Quick Staff PIN se Login Karein (PIN: 1234)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showStaffPinDialog(BuildContext context) {
    final pinController = TextEditingController();
    bool isStaffLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return Container(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      ctx.tr('login_staff_btn'),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(modalCtx),
                    ),
                  ],
                ),
                Text(
                  ctx.tr('login_staff_btn_sub'),
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: pinController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  obscureText: true,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: '••••',
                    counterText: '',
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : AppColors.surfaceSubtle,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : AppColors.border),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: isStaffLoading
                      ? null
                      : () async {
                          final pin = pinController.text.trim();
                          if (pin.length < 4) return;
                          setModalState(() => isStaffLoading = true);
                          final auth = context.read<AuthController>();
                          final ok = await auth.staffLogin(pin);
                          if (!modalCtx.mounted) return;
                          setModalState(() => isStaffLoading = false);
                          if (ok && mounted) {
                            Navigator.of(modalCtx).pop();
                            if (mounted) {
                              context.go('/merchant');
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: isStaffLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(ctx.tr('login_btn_submit'), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const Padding(
        padding: EdgeInsets.all(20),
        child: LanguageSelectorCard(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();
    final langController = context.watch<LanguageController>();
    final isMobile = Responsive.isMobile(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. App Brand Logo
        Center(
          child: Container(
            width: isMobile ? 80 : 92,
            height: isMobile ? 80 : 92,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Image.asset(
              'assets/images/app_mark.png',
              fit: BoxFit.contain,
              errorBuilder: (ctx, err, stack) => const Icon(
                Icons.storefront_rounded,
                size: 44,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 2. Role Badge
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  context.tr('login_badge_merchant'),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 3. Title & Subtitle
        Text(
          context.tr('login_title'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: isMobile ? 24 : 28,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.6,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.tr('login_google_subtitle'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.5,
            height: 1.4,
            color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 28),

        // 4. Zero-Friction Trust Feature Pills
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : AppColors.surfaceSubtle,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : AppColors.border,
            ),
          ),
          child: Column(
            children: [
              _buildTrustRow(
                icon: Icons.bolt_rounded,
                iconColor: const Color(0xFFF59E0B),
                title: context.tr('login_feature_1'),
                subtitle: context.isHindi
                    ? 'बिना फॉर्म भरे सिर्फ 1-क्लिक में सीधा लॉगिन'
                    : 'Instant access without filling long forms',
                isDark: isDark,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(height: 1),
              ),
              _buildTrustRow(
                icon: Icons.vpn_key_off_rounded,
                iconColor: AppColors.primary,
                title: context.tr('login_feature_2'),
                subtitle: context.isHindi
                    ? 'पासवर्ड याद रखने या भूलने की चिंता पूरी तरह खत्म'
                    : 'No passwords to remember, type, or reset',
                isDark: isDark,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(height: 1),
              ),
              _buildTrustRow(
                icon: Icons.verified_user_rounded,
                iconColor: const Color(0xFF10B981),
                title: context.tr('login_feature_3'),
                subtitle: context.isHindi
                    ? 'गूगल द्वारा प्रमाणित सुरक्षित खाता सुरक्षा'
                    : 'Bank-grade OAuth2 account protection',
                isDark: isDark,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 5. Error Banner (if any)
        if (authController.hasError) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    authController.errorMessage!,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],

        // 6. Prominent 1-Tap Google Sign-In Button
        InkWell(
          onTap: (authController.isLoading || _isConnectingGoogle) ? null : _handleGoogleSignIn,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: (authController.isLoading || _isConnectingGoogle)
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        context.tr('login_google_connecting'),
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const GoogleLogoIcon(size: 24),
                      const SizedBox(width: 14),
                      Text(
                        context.tr('login_google_btn'),
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 24),

        // 7. Counter Staff PIN Option (Discreet at bottom)
        Center(
          child: TextButton.icon(
            onPressed: () => _showStaffPinDialog(context),
            icon: const Icon(Icons.dialpad_rounded, size: 16, color: AppColors.textMuted),
            label: Text(
              context.tr('login_staff_pin_title'),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // 8. Terms Note
        Text(
          context.isHindi
              ? 'Google से जारी रखकर आप ShopSilo की सेवा शर्तों व गोपनीयता नीति से सहमत होते हैं।'
              : 'By continuing with Google, you agree to ShopSilo\'s Terms of Service and Privacy Policy.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? const Color(0xFF64748B) : AppColors.textMuted,
            height: 1.35,
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: isMobile
          ? (isDark ? const Color(0xFF0F172A) : AppColors.surface)
          : (isDark ? const Color(0xFF0F172A) : AppColors.background),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Language selector pill badge
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _showLanguageDialog(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : AppColors.border,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.language_rounded, size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      langController.currentLanguage == AppLanguage.hindi ? 'हिन्दी' : 'English',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: isDark ? Colors.white60 : AppColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: isMobile
            ? SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: content,
              )
            : Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: AppCard(
                      padding: const EdgeInsets.all(36),
                      child: content,
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildTrustRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11.5,
                  color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
