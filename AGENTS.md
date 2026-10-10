# Antigravity Agent Guidelines: ShopSilo Frontend

## 1. Environment & Paths
- **Backend Directory**: `C:\Go\ShopSilo\GoBackend`
- **Frontend Directory**: `c:\Go\ShopSilo\Frontend`
- **Backend Git Branch**: Always push to `main` (`origin/main`). Never push to detached `master` to avoid manual PR merges.
- **Backend Routes**: Never use `/api/v1/` prefix. Routes are `/auth/...`, `/shops/...`, `/products/...`.
- **Backend Server**: Production is `https://api.shopsilo.in`. Local is `http://localhost:8080`.

## 2. Token Saving Protocol (Fast & Efficient)
- Do NOT scan or dump the whole repo.
- Inspect target feature folder directly (`lib/features/{auth,dashboard,pos,products,khata,expenses}`).
- Use small line slices with `view_file` (50–100 lines) instead of full file reads.

## 3. Strict Rules & Locked Features
1. **LOCKED - Auth & Role**:
   - Role for this app is ALWAYS `merchant`.
   - Never allow customer accounts to log into this merchant partner app.
   - Never allow merchant accounts to log into customer app.
   - Registration payload sends `role: 'merchant'`.
2. **LOCKED - Languages**:
   - Only 2 languages supported: **English** and **Hindi (हिन्दी)**.
   - Absolutely NO Hinglish strings in UI.
   - All user-facing strings must use `context.tr('key')` from `AppTranslations`.
3. **LOCKED - API Endpoints**:
   - `ApiConstants` paths must never have `/api/v1` prefix.
4. **LOCKED - Multi-Screen Responsiveness & Zero Overflow**:
   - App must run without any pixel overflow on Web App, Android, iOS, Mobile (Portrait/Landscape), Tablet, Laptop, and Desktop.
   - Use `ResponsiveContainer` / `ConstrainedBox` to clamp widths on large screens (no stretched forms or giant modals).
   - Wrap all input sheets/dialogs in `SingleChildScrollView` with `viewInsets.bottom` keyboard padding.
   - Large currency / KPI values must use `FittedBox` to avoid font scaling overflows.
   - Maintain 60-120 FPS performance with `AppScrollBehavior` multi-pointer drag support.
5. **LOCKED - Production Minimalist UI/UX & Universal Component Reuse**:
   - App must NEVER have harsh rainbow colors, clashing gradients, or amateur oversized elements.
   - Use soft slate neutrals (`surfaceSubtle`, `border`, `textMuted`) and consistent `primary` accent.
   - 100% Component Reuse: Every screen MUST use `AppCard`, `AppStatCard`, `AppSectionHeader`, `AppActionTile`, `AppSummaryBanner`, and `AppBadge` from `lib/core/widgets/app_ui_components.dart`.
   - Zero visual clutter: Intuitive, simple, and clean experience for merchants across ALL current and future screens.
6. **LOCKED - Settings & Theme Layout**:
   - Logout option is strictly positioned at the very bottom of Store Settings (`/merchant/profile`), nowhere else.
   - App Theme Selector (Dark, Light, System) is positioned immediately above the Logout button.
7. **LOCKED - Bot Protection & Rate Limiting (Backend)**:
   - No slow Cloudflare challenge / interstitial verification screens ("Just a moment..." spinners).
   - Pure Go in-memory invisible protection (`BotGuard`) with zero latency for legitimate browsers and mobile apps.
   - Rate limiting on sensitive auth endpoints strictly set to 15 requests/minute (`AuthRateLimiter`). OTP requests set to 4 requests/10 minutes (`OTPRateLimiter`).
   - Automated in-memory quarantine (`JailIP`) for vulnerability scanner probes and repeated rate limit violators.

## 4. Continuous User Decisions Log
- See [PROJECT_RULEBOOK.md](file:///c:/Go/ShopSilo/Frontend/PROJECT_RULEBOOK.md) Section 5 for the complete history of user requirements and architectural decisions.
- Whenever the user gives a new rule or permanent decision, update both `PROJECT_RULEBOOK.md` and this file.
