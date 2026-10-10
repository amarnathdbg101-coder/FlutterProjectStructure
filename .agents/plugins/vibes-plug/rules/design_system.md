# Design System Rules

1. **100% Component Reuse**:
   - Always reuse core UI components from `lib/core/widgets/app_ui_components.dart`: `AppCard`, `AppStatCard`, `AppSectionHeader`, `AppBadge`, `AppSummaryBanner`.
2. **Bilingual Strictness**:
   - Zero hardcoded English strings. Always access `context.tr('key')` from `AppTranslations`.
   - Never use Hinglish text in UI.
