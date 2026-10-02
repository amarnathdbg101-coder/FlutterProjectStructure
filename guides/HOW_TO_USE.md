# 📱 Complete Guide: How to Use Flutter Project Structure

Ye template aapke **Go Backend (`C:\\Go\\GoProjectStructure`)** se 1-to-1 connect hone ke liye aur rapid hackathons ke liye banaya gaya hai.

---

## ⚡ Quick Start (Under 1 Minute)

### 1. Copy or Clone
```powershell
xcopy /E /I /H C:\\Go\\FlutterProjectStructure C:\\Go\\MyNewApp
```

### 2. Backend URL Configure Karein
`lib/core/constants/api_constants.dart` file me:
- **Android Emulator:** `http://10.0.2.2:8080` (pre-configured)
- **Windows Desktop / Web:** `http://localhost:8080` (pre-configured)
- **Production Server:** `isProduction = true; productionUrl = 'https://api.myapp.com';`

### 3. Run App
```powershell
flutter run
# Ya shortcut: .\\run-app.bat
```

---

## 🗺️ GoRouter Navigation (Declarative & Clean)

Is project me official Google **`go_router`** configured hai:

```dart
// Screen badalna (navigate):
context.go(AppRoutes.dashboard); // Replace current screen
context.push(AppRoutes.register);  // Push on top (with back button)
context.pop();                     // Back jaana
```

Routes centrally `lib/core/routes/app_router.dart` me defined hain:
- `AppRoutes.splash` (`/`)
- `AppRoutes.login` (`/login`)
- `AppRoutes.register` (`/register`)
- `AppRoutes.dashboard` (`/dashboard`)

---

## 🧰 Reusable Helpers (Zero Repetition!)

1. **`BaseController`:** Har controller `BaseController` extend karta hai (`isLoading`, `errorMessage`, `setLoading`, `setError`).
2. **`EmptyStateWidget`:** Jab list empty ho: `EmptyStateWidget(title: 'No items', onAction: ...)`
3. **`ErrorStateWidget`:** Network error aane par: `ErrorStateWidget(message: '...', onRetry: ...)`
4. **`CustomDialog.confirm(...)`:** 1-Line confirmation dialog:
   ```dart
   if (await CustomDialog.confirm(context, title: 'Delete', message: 'Are you sure?', isDestructive: true)) {
     // delete logic
   }
   ```
5. **Dark Mode:** `AppTheme.darkTheme` pre-configured hai (Device dark mode par auto-switch hota hai).

---

## ⚡ 1-Click Feature Generator

Naya feature (jaise `Product`, `Order`, `Todo`) banana ho:
```powershell
.\\scripts\\generate-feature.bat Product
```
Ye 2 second me create kar dega:
1. `features/product/models/product_model.dart`
2. `features/product/repositories/product_repository.dart`
3. `features/product/controllers/product_controller.dart` (extends `BaseController`)
4. `features/product/screens/product_list_screen.dart` (with Empty state, Error state, Modal bottom sheet, and Delete dialog!)
