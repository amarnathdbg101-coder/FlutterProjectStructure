# 📚 Complete File & Directory Index (Flutter Starter with GoRouter)

| Path | Purpose & Use Case |
|---|---|
| `lib/main.dart` | Application entrypoint, `MultiProvider` wiring, `MaterialApp.router` with Light & Dark theme support. |
| `lib/core/routes/app_router.dart` | Centralized Google `go_router` configuration (`AppRoutes.splash`, `login`, `register`, `dashboard`). |
| `lib/core/constants/api_constants.dart` | 1-Click Environment Switcher (`isProduction`, `productionUrl`), emulator vs desktop base URL, endpoints. |
| `lib/core/constants/app_colors.dart` | Curated color system (Primary, Surface, Semantic Success/Error). |
| `lib/core/network/api_client.dart` | Singleton Dio HTTP client with timeouts, logging, and error parser. |
| `lib/core/network/api_response.dart` | Standard Go backend response parser (`success`, `data`, `error`). |
| `lib/core/network/auth_interceptor.dart` | Injects `Authorization: Bearer <token>` into all HTTP requests. |
| `lib/core/network/base_controller.dart` | Base class for all controllers: manages `isLoading`, `errorMessage`, `setLoading`, `setError`. |
| `lib/core/storage/token_storage.dart` | SharedPreferences wrapper for saving/clearing JWT tokens and session. |
| `lib/core/theme/app_theme.dart` | Material 3 Light & Dark theme configurations with Inter typography. |
| `lib/core/utils/validators.dart` | Email, password, and required field input validators. |
| `lib/core/widgets/custom_button.dart` | Sleek primary button with integrated loading spinner. |
| `lib/core/widgets/custom_text_field.dart` | Rounded outlined text field with password visibility toggle. |
| `lib/core/widgets/custom_dialog.dart` | 1-Line confirmation dialog: `CustomDialog.confirm(context, title: '...', ...)`. |
| `lib/core/widgets/custom_snackbar.dart` | Floating success/error notification banners. |
| `lib/core/widgets/empty_state.dart` | Reusable empty list placeholder widget with icon, title, and optional Add button. |
| `lib/core/widgets/error_state.dart` | Reusable error state widget with Retry button. |
| `lib/features/auth/models/user_model.dart` | User profile data structure matching Go backend's `User` model. |
| `lib/features/auth/repositories/auth_repository.dart` | Calls Go backend `/login`, `/register`, `/profile`. |
| `lib/features/auth/controllers/auth_controller.dart` | Extends `BaseController`, manages authentication, token saving, and session. |
| `lib/features/auth/screens/splash_screen.dart` | Startup check: redirects via `context.go` to Dashboard if token exists, else Login. |
| `lib/features/auth/screens/login_screen.dart` | Clean login UI with backend live connectivity card. |
| `lib/features/auth/screens/register_screen.dart` | User registration screen with client-side validations. |
| `lib/features/dashboard/screens/dashboard_screen.dart` | Main dashboard displaying user profile, backend status, and 1-line logout dialog. |
| `lib/features/health/repositories/health_repository.dart` | Calls Go backend `/health` endpoint. |
| `lib/features/health/controllers/health_controller.dart` | Extends `BaseController`, tests connection, uptime, and database state. |
| `lib/features/health/widgets/backend_status_card.dart` | Live visual badge showing "Backend Online / Offline" & DB status. |
| `scripts/generate-feature.bat` | 1-Click scaffolding script to create a new domain in 2 seconds. |
