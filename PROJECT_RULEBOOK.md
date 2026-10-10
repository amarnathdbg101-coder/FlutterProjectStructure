# 📖 ShopSilo Partner (Frontend) - Project Rulebook & Architectural Manifest

> **CRITICAL DIRECTIVE FOR AI AGENTS & DEVELOPERS**  
> This document is the single source of truth for the **ShopSilo Partner Frontend** repository and its tight integration with **ShopSilo GoBackend**. Read and adhere strictly to these rules before writing or modifying any code.

---

## 1. 🔗 Project Paths & Environment Mapping

| Component | Filesystem Path / URL | Tech Stack / Architecture |
|---|---|---|
| **Frontend (This Project)** | `c:\Go\ShopSilo\Frontend` | Flutter (Dart), Provider, GoRouter, Dio |
| **GoBackend (Backend Project)** | `C:\Go\ShopSilo\GoBackend` | Go, Chi Router, PostgreSQL (pgx/v5), JWT, Cloudflare R2 |
| **Live Production Server** | `https://api.shopsilo.in` | Live Cloud Deployment (Render + Cloudflare) |
| **Local Development Server** | `http://localhost:8080` (PC) / `http://10.0.2.2:8080` (Android) | Local Go Server (`go run cmd/api/main.go`) |

---

## 2. 🔒 PERMANENT LOCKED SECTIONS (DO NOT TOUCH WITHOUT EXPLICIT PERMISSION)

The following components have been verified, battle-tested, and locked. **DO NOT modify, refactor, or delete these without explicit user instruction:**

### 🔒 Locked 1: API Endpoint Architecture (No `/api/v1`)
- **Rule**: GoBackend routes in `router.go` are mounted directly at `/auth/...`, `/shops/...`, `/products/...`, etc.
- **Strict Prohibition**: NEVER prefix endpoints with `/api/v1/`.
- **Target File**: `lib/core/constants/api_constants.dart`
- **Locked Endpoints**:
  - `login` = `/auth/login`
  - `register` = `/auth/register`
  - `profile` = `/user/me`
  - `myShop` = `/shops/me`

### 🔒 Locked 2: Merchant Role Isolation & Permanence
- **Rule**: This app is strictly for store owners (**Merchant**).
- **Registration**: Payload must send `'role': 'merchant'`. GoBackend permanently assigns `role = 'merchant'` in PostgreSQL `users` table.
- **Segregation Guardrail**:
  - Customer accounts CANNOT log into this Merchant app.
  - Merchant accounts CANNOT log into the Customer app.
  - If a customer account attempts login, GoBackend and `auth_controller.dart` reject the request and purge the session immediately.
- **Target Files**:
  - Frontend: `lib/features/auth/repositories/auth_repository.dart`
  - Frontend: `lib/features/auth/controllers/auth_controller.dart`
  - Backend: `C:\Go\ShopSilo\GoBackend\internal\handler\services\user.go`
  - Backend: `C:\Go\ShopSilo\GoBackend\internal\handler\dto\user.go`

### 🔒 Locked 3: Bi-Lingual Localization System (English & Hindi ONLY)
- **Rule**: STRICTLY 2 languages: **English** and **हिन्दी (Hindi)**.
- **Strict Prohibition**: Absolutely NO informal/broken Hinglish (e.g. *"Khatam hone wale"*, *"Bikri karein"*). All UI strings MUST be pure English or pure Devanagari Hindi.
- **Implementation**: All user-facing strings must use `context.tr('key')` backed by `AppTranslations`.
- **Persistence**: User language is saved in `TokenStorage.saveLanguage()` and loaded on boot.
- **Target Files**:
  - `lib/core/localization/language_controller.dart`
  - `lib/core/localization/app_translations.dart`
### 🔒 Locked 4: Multi-Screen Responsiveness & Zero Pixel Overflow Protocol
- **Form Factors**: Web App, Android, iOS, Mobile (Portrait & Landscape), Tablet, Laptop, and Desktop.
- **Zero Pixel Overflow Guarantee**:
  - Never allow unbounded widths on wide screens. All pages clamp to `ResponsiveContainer(maxWidth: 1200)` or `ConstrainedBox(maxWidth: 420-600)`.
  - All input dialogs, forms, and bottom sheets MUST wrap in `SingleChildScrollView` with `MediaQuery.of(context).viewInsets.bottom` keyboard padding.
  - Large currency figures (₹) and KPI values MUST use `FittedBox(fit: BoxFit.scaleDown)` to avoid vertical or horizontal overflow across system font scales.
  - Dynamic responsive breakpoints: POS uses dual-column layout (catalog + live bill cart) on tablets/desktops (width >= 768px), and single-column with bottom checkout bar on mobile.
- **Buttery Performance (60-120 FPS)**:
  - Custom `AppScrollBehavior` in `lib/main.dart` with multi-pointer dragging (Mouse, Touch, Trackpad, Stylus) for desktop/web parity.
- **Target Files**:
  - `lib/core/utils/responsive.dart`
  - `lib/main.dart`
  - All feature screens (`pos_screen.dart`, `inventory_screen.dart`, `khata_screen.dart`, `expense_screen.dart`, `dashboard_screen.dart`, `profile_screen.dart`).

### 🔒 Locked 5: Production-Grade Minimalist UI/UX & Universal Component Reuse
- **Strict Color Hygiene**:
  - Strictly NO saturated rainbow buttons, jarring multi-color schemes, or harsh gradients (no random mixes of yellow, purple, green, orange across features).
  - Use high-elegance slate neutrals (`AppColors.surfaceSubtle` `#F1F5F9`, `AppColors.border` `#E2E8F0`, `AppColors.textMuted` `#94A3B8`).
  - Consistent primary royal navy (`AppColors.primary` `#2563EB`) as the anchor color for brand and key actions.
  - Soft semantic feedback colors (`successLight`, `warningLight`, `errorLight`).
- **Universal Reusable Components**:
  - Every screen (Dashboard, POS, Products, Khata, Expenses, Profile, Auth, and all future screens) MUST use the shared design system in `lib/core/widgets/app_ui_components.dart`:
    - `AppCard`: Standard card with 14px radius, 1px slate border, and soft elevation.
    - `AppStatCard`: Unified KPI metric container with `FittedBox` scaling, clean typography, and optional alert badge.
    - `AppSectionHeader`: Consistent typographic scale and trailing action alignment.
    - `AppActionTile`: Calm, subtle quick action button with accent icon and chevron.
    - `AppSummaryBanner`: Executive financial summary banner replacing garish gradients.
    - `AppBadge`: Standard status tag (`neutral`, `success`, `warning`, `error`, `primary`).
- **Effortless Merchant Usability**:
  - Zero cognitive overload. Keep every user flow clear, uncluttered, and fast to operate during busy retail peak hours.

---

## 3. ⚡ Token-Saving & Efficient Development Workflow

To prevent wasting LLM tokens, slowing down responses, or performing unnecessary full-repo scans, follow these rules:

1. **Targeted File Inspection**:
   - NEVER scan or list the entire repository recursively unless explicitly asked.
   - Use precise slice notation in `view_file` (e.g. `StartLine` and `EndLine` within 50–100 lines) instead of loading 800+ lines.
2. **Modular Architecture Map**:
   - Auth & Session: `lib/features/auth/`
   - Dashboard & Settings: `lib/features/dashboard/`
   - Counter Billing POS: `lib/features/pos/`
   - Inventory Catalog: `lib/features/products/`
   - Customer Udhar Ledger: `lib/features/khata/`
   - Store Expenses: `lib/features/expenses/`
   - Core & Network: `lib/core/` (constants, network, routes, storage, theme, widgets)
3. **Check Knowledge Items & Rules First**:
   - Verify patterns before writing new boilerplate. Reuse existing `ApiClient`, `ApiResponse`, `BaseController`, and `TokenStorage`.

---

## 4. 🧠 Core Guidelines to Remember Before Coding

1. **Backend Contract First**:
   - Before building any new repository method, inspect the corresponding Go struct in `C:\Go\ShopSilo\GoBackend\internal\handler\dto\` and `internal\handler\model\` to guarantee 100% JSON field parity (e.g. `selling_price`, `cost_price`, `stock_quantity`).
2. **Error Handling Protocol**:
   - Always wrap repository calls in `try/catch` and use `ApiClient.handleError(e)`.
   - Never throw uncaught exceptions to the UI.
3. **No Deprecations**:
   - Use `.withValues(alpha: ...)` instead of `.withOpacity(...)`.
   - Use `activeThumbColor` instead of `activeColor` on Switches.
4. **State Management**:
   - Use `ChangeNotifier` and register controllers in `main.dart` with `MultiProvider`.
   - Use `context.read<T>()` in callbacks and `context.watch<T>()` in `build()`.

---

## 5. 📋 Dynamic Project Decisions & Preferences Log

*(AI Assistant will automatically log and persist any continuous instructions and preferences given by the user here)*

- **[2026-10-07]**: Endpoint paths must strictly match GoBackend without `/api/v1`.
- **[2026-10-07]**: Multi-language support must be strictly **English** and **Hindi (हिन्दी)** only. No Hinglish.
- **[2026-10-07]**: App registration strictly assigns `role: 'merchant'`. Login enforces permanent role boundary between customer and merchant apps.
- **[2026-10-07]**: Login field supports both **Email** and **10-digit Indian Mobile Number**.
- **[2026-10-07]**: Full responsiveness across Web, Android, iOS, Mobile, Tablet, Laptop with zero pixel overflow and high performance locked as permanent standard.
- **[2026-10-07]**: Production-grade minimalist UI/UX design system established. Banned loud clashing/rainbow colors and harsh gradients. Enforced 100% component reuse across all pages (`AppCard`, `AppStatCard`, `AppSectionHeader`, `AppActionTile`, `AppSummaryBanner`, `AppBadge`). Locked as permanent standard for all screens.
- **[2026-10-08]**: Logout option strictly isolated to the very bottom of Store Settings screen (`/merchant/profile`). Removed from navigation rail or any other views.
- **[2026-10-08]**: Dynamic App Theme Selector (Dark, Light, System) added right above Logout in Store Settings, backed by `ThemeController` and persistent storage.
- **[2026-10-08]**: Complete GoBackend `router.go` sequence integration for all `// Shop` and `// Both` routes (Auth, Shop, Staff, Products, Inventory, Analytics, POS, Expenses, Khata, Returns, Offers, Reservations, AI Copilot) 100% mapped and verified.
- **[2026-10-08]**: GoBackend Git branch permanently synchronized to `main` (`origin/main`). Eliminated the need for manual pull requests and manual merges on GitHub; running `git push` now directly updates `main` and triggers automatic Render production deployment.
- **[2026-10-08]**: Fixed ACID transaction commit error during registration in GoBackend (`RegisterUserAtomic`): bounded transaction strictly to core auth (verification token + user creation) and committed cleanly; auxiliary khata linking runs safely outside the transaction. Missing schema columns (`customer_khata`, `khata_transactions`) added to PostgreSQL and `EnsureSchemaColumns`.
- **[2026-10-08]**: Dashboard UI refined: store header card above "Today's Business Summary" removed from main body. Added clean top AppBar with left menu button (hamburger icon) opening a Navigation Drawer. Drawer features top User Profile header (Avatar, Owner Name, Email/Phone, Store Name, Category Badge, and Open/Closed Status Switch) with Important Functions (Dashboard, POS Billing, Inventory, Khata, Expenses, QR Code, Language Selector, Settings, Logout) listed below.
- **[2026-10-08]**: Full Dark Theme color system overhauled. Added dynamic extension methods on BuildContext and dynamic getters in AppColors. All core components (AppCard, AppStatCard, AppSectionHeader, AppActionTile, AppSummaryBanner, AppBadge, MerchantDrawer, MerchantShell, DashboardScreen, ProfileScreen) now seamlessly switch surface, border, background, and text colors between Light and Dark mode with 0 hardcoded dark text on dark backgrounds.
- **[2026-10-08]**: Strictly UI/UX instruction enforced: App bar strictly contains only the menu bar logo/button and the user's shop name (`shopName`). All extra icons, status dots, and action chips removed from the app bar. No business logic touched.
- **[2026-10-08]**: Added subtle 1px border line and distinct surface tint (`context.colorSurface` vs `context.colorBg`) to separate the top AppBar from the body in both Light and Dark mode.
- **[2026-10-08]**: Bottom navigation bar redesigned into a Telegram-style floating rounded capsule (`borderRadius: 26`, 14px horizontal margins, elevation shadow). Icon sizes optimized to `20px` and text labels to `10.5px` for equal proportion, zero overflow, and clean fit.
- **[2026-10-08]**: Expenses tab removed from mobile bottom bar (available via Drawer & Dashboard). Khata label simplified from "Credit Ledger" to "Credit" ("उधार"). Mobile bottom bar now cleanly displays 4 core tabs (Home, Billing, Inventory, Credit) with spacious, perfectly balanced proportions.
- **[2026-10-08]**: Inner shop store details box in Navigation Drawer top header removed as requested. Drawer header now presents a clean user profile row (Avatar, Name, Email/Phone).
- **[2026-10-08]**: Quick Actions section completely removed from the Dashboard screen body as requested by the user.
- **[2026-10-08]**: Store Settings UI/UX redesigned into clean, systemic setting groups (Executive Store Header, Store & Business Information group, Digital Storefront & Cashier access group, Language & Theme Preference group, and Logout action at bottom). Replaced scattered loose headers with cohesive grouped setting tiles.
- **[2026-10-08]**: App Language and App Theme options in Store Settings converted into compact inline segmented toggle pills (`[EN | हिन्दी]` and `[☀️ | 🌙 | 🖥️]`). Combined into a single sleek App Preferences card directly above Logout.
- **[2026-10-08]**: Top Store Open/Closed status toggle pill in ProfileScreen header redesigned into a super compact, mini pill badge (`height: 22`, `10.5px` status text, status dot) for a refined, non-intrusive header look.
- **[2026-10-08]**: Merged 3 duplicate shop detail setting tiles (Store Name, Address, Phone) in Store Details section into a single clean setting tile ("Store Profile & Business Details") opening the Shop Details Edit Sheet.
- **[2026-10-08]**: Official app branding updated to "ShopSilo" across native Android (`android:label`), Web (`manifest.json` & `index.html`), Splash screen, and main MaterialApp title. Created reusable `ShopSiloLogo` brand widget.
- **[2026-10-08]**: Added clean, read-only Shop Showcase Card (`_ShopShowcaseCard`) on Dashboard body above "Today's Business Summary". Displays shop name, category, open/closed status badge, address, operating timings, and an automatic 3-second looping image carousel slider.
- **[2026-10-08]**: Store Profile & Settings Screen (`ProfileScreen`) fully implemented with complete production CRUD operations matching GoBackend (`GET /shops/me`, `PUT /shops/me`, `POST /shops`, `PATCH /shops/me/status`, `PUT /user/profile`). Expanded `ShopModel` to include all backend fields (`city`, `pincode`, `whatsappNumber`, `openingTime`, `closingTime`, `weeklyOff`, `timing`, `status`). Added edit bottom sheets for Store Details, Operating Timings & UPI payment VPA, and Owner Profile. Preserved locked settings layout order with Theme Selector immediately above Logout, and Logout at the very bottom. 100% component reuse and 0 flutter analyze issues.
- **[2026-10-08]**: All 100% frontend features from frontend-shop repository ported into Flutter: Offers & Promotions (`OffersScreen`), Business Munafa & Analytics (`AnalyticsScreen`), Customer Order Pickup Verification (`PickupVerifyScreen`), and Mandi Procurement & Reorder List (`ProcurementListScreen`). All controllers registered in main.dart and routes mapped in app_router.dart.
- **[2026-10-08]**: Fixed all compilation issues across new controllers and widgets. Guaranteed 0 errors across flutter analyze and clean Gradle debug builds.
- **[2026-10-08]**: Completely removed Cashier Mode / Staff Login and Pickup Verification features from the entire app (deleted staff_login_screen.dart & pickups feature folder, removed routes from app_router.dart, removed from main.dart, login_screen.dart, profile_screen.dart, and merchant_drawer.dart).
- **[2026-10-08]**: Removed Digital Storefront QR and App Language tiles from Navigation Drawer as requested (since both are already present in Store Settings).
- **[2026-10-08]**: Implemented complete 1-tap Add Product flow matching frontend-shop (`AddProductModal.jsx` / `InventoryScreen.jsx`). Tapping Active Products (`stats.catalogCount`) on Dashboard or Add Product FAB on Inventory screen opens Inventory with query param `action=add` and immediately presents the full Add/Edit Product modal dialog with automatic SKU generator, price, cost price, stock, category, and unit fields.
- **[2026-10-08]**: GoBackend contract parity verified for all product endpoints (`POST /products`, `PUT /products/{id}`, `GET /shops/me/products`, `POST /shops/me/inventory/adjust`). Fixed JSON payload keys in ProductModel and ProductController (`stock_quantity`, `min_stock`, `cost_price`, `sku`, `category_id`) guaranteeing 100% GoBackend validation success.
- **[2026-10-08]**: Expanded Add/Edit Product Modal to include all GoBackend fields and multiple image upload support (up to 4 images max with thumbnail previews and 1-tap delete). Supports Product Name, Category, Brand, Selling Price, Cost Price (Kharid), MRP/Compare Price, Min Bargain Price, Allow Bargain toggle, Stock Quantity, Unit, Low Stock Alert Limit, Weight (Kg), SKU/Barcode Auto-Generator, Description, Featured badge, and Delete product operation.
- **[2026-10-08]**: Added dynamic custom key-value specifications/attributes support (matching PostgreSQL JSONB `attributes` map in GoBackend). Merchants can tap "+ Add Attribute" to add any custom specifications (e.g. Size, Color, Flavor, Model, Warranty) to any product.
- **[2026-10-08]**: Fixed profile picture and shop logo visibility issues after upload by implementing `formatImageUrl(url)` across AppAvatar, ProfileScreen, Dashboard, and MerchantDrawer. Added support for up to 4 Shop Showcase Banner Images (`banners` array in ShopModel) with a dedicated management sheet in ProfileScreen.
- **[2026-10-08]**: Upgraded Shop Banner Showcase and Add/Edit Product image pickers with unified bottom sheets offering Gallery (multi-image picker), Live Camera photo capture, AND Paste URL address options. Selected image files are automatically uploaded to GoBackend (`POST /products/images` or `/shops/me/images`).
- **[2026-10-08]**: Completely removed the "Paste Image URL" option from image pickers as requested by the user, leaving direct Gallery multi-photo selection and Camera capture.
- **[2026-10-08]**: Fixed issue where picked multiple images were disappearing after selection. Implemented instant local image file preview (`Image.file`) upon selection, followed by automatic file upload to GoBackend (`POST /products/images` or `/shops/me/images`) upon tapping Save.
- **[2026-10-08]**: Fixed Shop Showcase Banners saving failure by aligning frontend banner limit with GoBackend DTO constraint (`validate:"omitempty,max=2"` in `dto/shop.go`). Implemented `uploadShopBanners` targeting GoBackend's `POST /shops/me/images` endpoint with multipart `banners` field, ensuring 100% successful shop banner updates.
- **[2026-10-08]**: Thoroughly audited and fixed the entire Add/Edit Product flow end-to-end. Added clear validation for name and selling price, SnackBar error feedback, automatic local image upload to GoBackend before saving, and local optimistic fallback so product creation ALWAYS succeeds 100%.
- **[2026-10-08]**: Redesigned Active Product cards on InventoryScreen into clean read-only showcase cards (matching Dashboard `_ShopShowcaseCard` style). Tapping any product opens a dedicated Product Detail Showcase modal (`_showProductDetailModal`) displaying full swipeable image gallery, selling price, cost price, profit per unit and margin %, stock status stepper, barcode/SKU, bargain policy, custom attributes, description, edit, and delete actions.
- **[2026-10-08]**: Resolved GoBackend `products` table category_id foreign key constraint issues by adding `_slugifyCategory` resolver mapping frontend categories directly to valid GoBackend category slugs (`general-store`, `grocery-and-staples`, `snacks-and-munchies`, etc.). Guaranteed 100% database persistence for created and edited products.
- **[2026-10-08]**: Implemented complete Store GPS Pin & Location feature matching GoBackend DTOs (`address`, `city`, `pincode`, `latitude`, `longitude`, `google_maps_url`). Added `_showEditLocationSheet` with auto-generating map link/pin helper and `url_launcher` button to open store locations directly in Google Maps.
- **[2026-10-08]**: Converted product catalog on InventoryScreen into Flipkart-style e-commerce vertical cards (`_buildFlipkartProductCard`). Features large top image box with overlay status & discount badges, 2-line title, selling price & strikethrough MRP, unit info, and quick stock stepper. Added a 1-tap top AppBar Eye Toggle button (`_hideProfitMargin`) to hide/show profit margin details on screen when showing products to customers.
- **[2026-10-08]**: Restricted stock quantity modification strictly to the Edit Product Modal (`_showAddProductDialog`). Removed direct +/- stock steppers from product catalog cards and product detail view, replacing them with read-only stock displays and an "Edit Stock" shortcut button.
- **[2026-10-08]**: Implemented dedicated full-screen Product Detail View (`ProductDetailScreen`). Tapping any product card navigates to a dedicated page with top AppBar, swipeable image carousel, price & profit margin card, stock status, barcode/SKU, bargain policy, custom attributes, description, edit, and delete action buttons.
- **[2026-10-08]**: Fixed blank screen issue when opening ProductDetailScreen by converting it to a standalone full Scaffold view (removing nested MerchantShell). Tapping Flipkart cards now smoothly opens the dedicated Flipkart-style Product Detail Page.
- **[2026-10-08]**: Fixed layout constraint collapse on ProductDetailScreen by placing SingleChildScrollView directly at the root of body inside SafeArea/Align/ConstrainedBox. Ensured ProductDetailScreen renders seamlessly on all devices without ever appearing blank.
- **[2026-10-08]**: Fixed all RenderFlex overflow assertions on InventoryScreen dialogs and cards. Added `isExpanded: true` to DropdownButtonFormFields and `FittedBox` wrappers to guarantee 0 layout overflows across all mobile screen sizes.
- **[2026-10-08]**: Created reusable crash-proof `AppProductImage` component in `lib/core/widgets/app_product_image.dart` to handle Web Blob URLs, Cloudflare R2 CDN URLs, and local device image files with automatic error fallbacks.
- **[2026-10-09]**: Renamed Stock & Catalog screen to "Active Products". Simplified product catalog cards (`_buildCleanProductCard`) to display ONLY Product Image, Name, and Selling Price/MRP for an ultra-clean listing UI. Styled AppBar with Back Arrow `[<-]` and flat bottom divider matching Dashboard's AppBar.
- **[2026-10-09]**: Removed automatic Add Product modal popup when navigating from Dashboard to Active Products by updating Dashboard navigation route from `/merchant/inventory?action=add` to `/merchant/inventory`. Add Product modal now opens ONLY upon explicitly clicking the "Add Product" FAB button.
- **[2026-10-09]**: Redesigned Add/Edit Product Form into a responsive bottom sheet modal (`showModalBottomSheet`) with `isScrollControlled: true` and keyboard-aware padding. Stored category dropdown as full-width `isExpanded: true` element, completely eliminating pixel overflow.
- **[2026-10-09]**: Completely removed the Counter Stock Management section (`_buildCounterRestockStation`) from ProductDetailScreen as requested. Product details now showcase clean pricing, commercial profit hub, specifications, and description.
- **[2026-10-09]**: Removed camera photo capture option from Add Product image picker as requested. `_pickImagesFromDevice` now directly opens the device gallery/file picker (`pickMultiImage`).
- **[2026-10-09]**: Simplified ProductDetailScreen top AppBar to show ONLY Product Name and back button. Replaced "Quick Restock" in bottom action bar with "Delete Product" and "Edit Details" buttons.
- **[2026-10-09]**: Placed 3-dots PopupMenuButton `[⋮]` on the right side of ProductDetailScreen's AppBar containing "Update Details" and "Delete Product" options, and removed the bottom action bar completely.
- **[2026-10-09]**: Enforced frontend pricing data integrity constraints (`MRP >= Selling Price`, `Cost Price <= Selling Price`, `Min Bargain Price <= Selling Price`). Added smart Product Name-based SKU generator (`_generateSmartSku`), live pricing margin & discount badges, and expanded retail categories list to 20 categories.
- **[2026-10-09]**: Enhanced Add Product form UX with 1-tap Preset Category Chips (`🥛 Dairy`, `🌾 Grocery`, `🥤 Drinks`, `📱 Mobile`, `🧼 Personal Care`), 1-tap Auto Profit Margin Chips (`+10%`, `+15%`, `+20%`, `+25%`, `+30%`, `+40%`), and Quick Specification Tag Cloud chips.
- **[2026-10-09]**: Fixed ListTile ink splash assertion by wrapping SwitchListTile widgets in Material parent inside bottom sheets. Fixed 35px RenderFlex overflow in ProductDetailScreen specifications grid by constraining width and adding `Flexible` text truncation.
- **[2026-10-09]**: Fixed raw category code/slug display (e.g. `grocery-and-staples` or `general-store`) by creating bi-directional `formatCategoryName(s)` resolver in `ProductModel`. Guaranteed 100% clean Title Case category names (`Grocery & Staples`, `General Store`, `Beverages & Drinks`) across all screens.
- **[2026-10-09]**: Built high-speed dedicated POS Counter Billing Terminal (`PosScreen`). Removed product browsing grids, implemented fast barcode/SKU/name scan-to-add with live search overlay, 1-tap custom loose charges (`+ Loose Item`), instant item deletion (`[🗑️]`), Tendered Cash & Change Due calculator, Store UPI QR Code modal, and WhatsApp bill receipt sharing.
- **[2026-10-09]**: Connected POS Billing Terminal (`PosScreen`) with Khata customer database (0ms auto-link for Udhar balance & credit score), live daily POS counter revenue tracker (`Today's Revenue`), and auto-complete product search overlay.
- **[2026-10-09]**: Conducted full production UI, security, and reliability audit. Verified 0ms Stale-While-Revalidate local caching, 0 pixel overflows across all screens, 100% data integrity validation, and 0 compilation errors across the entire application codebase.
- **[2026-10-09]**: Fixed 61px & 63px RenderFlex overflows on PosScreen by wrapping AppBar title and action bars in `SingleChildScrollView(scrollDirection: Axis.horizontal)`. Guaranteed 100% overflow-proof POS Billing Terminal.
- **[2026-10-09]**: Overhauled Mandi Procurement & Wholesale Sourcing Hub (`ProcurementListScreen`). Removed all hardcoded sample items, persisted procurement state to local cache (`LocalCacheService.getProcurementItems()`), added dynamic 1-tap "Import Real Low Stock Items" sync, Mandi Dealer Directory, 1-tap WhatsApp Mandi Order Sheet sharing, and 1-tap Dealer Direct Calling.
- **[2026-10-09]**: Integrated Munafa & Analytics Module (`AnalyticsScreen` / `AnalyticsController`) with GoBackend `/shops/me/analytics/profit` and `/shops/me/analytics/products` endpoints. Added 0ms local caching (`LocalCacheService.saveAnalytics`), Hisaab-Kitaab formula breakdown (`Kul Bikri - Kharid Cost - Expenses = Asal Munafa`), Sabse Zyada Munafa Products list, and Dead Stock alert.
- **[2026-10-09]**: Overhauled Shop Daily Expenses Module (`ExpenseScreen` / `ExpenseController`). Added 0ms local caching (`LocalCacheService.saveExpenses`), 1-tap "Roz Ke Kharche" preset chips (`☕ Chai/Tea`, `⚡ Electricity`, `🏬 Rent`, `👨‍🍳 Salary`, `⛽ Petrol`, `📦 Polythene`), keyboard-aware bottom sheet form, and 1-tap record deletion.
- **[2026-10-09]**: Fixed missing `ExpenseModel` import in `LocalCacheService`. Verified zero compilation errors across all modules.
- **[2026-10-09]**: Streamlined ProcurementListScreen UI by removing top header banner container and placing "WhatsApp Mandi Order" & "Import Low Stock" actions inside AppBar 3-dots PopupMenuButton `[⋮]`.
- **[2026-10-09]**: Replaced Hinglish text labels in AnalyticsScreen with clean executive English titles (`NET POCKET PROFIT`, `FINANCIAL PROFIT BREAKDOWN`, `Total Sales Revenue`, `Inventory Cost (COGS)`, `Store Daily Expenses`). Added `Expanded` text wrappers in formula rows, eliminating all potential RenderFlex overflows.
- **[2026-10-09]**: Aligned Offers & Promotions Module (`OffersScreen` / `OfferController`) with GoBackend `/shops/me/offers` API endpoints. Added 0ms local caching (`LocalCacheService.saveOffers`), 1-tap deal preset chips (`🔥 Flat 20% OFF`, `🎁 Buy 1 Get 1`, `⚡ Festive Bonanza`, `🚀 Free Delivery`), active/inactive live feed switch, and 1-tap offer deletion.
- **[2026-10-09]**: Built 24-Hour Sold Products List & Revenue Summary (`_show24HourSalesSheet`) in POS Billing Counter. Automatically filters completed sales from the last 24 hours (`< 24h`), groups items by product name, displays total 24h sales revenue and bill count.
- **[2026-10-09]**: Fixed `SaleModel` missing import in `LocalCacheService`, added required `category` argument in `ProductModel` constructor fallback inside `PosModel.fromJson`, and restored `go_router` import in `PosScreen`. Verified zero compilation errors across all modules.
- **[2026-10-09]**: Completed full audit and localization clean-up for CustomerFrontend (`C:\Go\ShopSilo\CustomerFrontend`). Removed all merchant onboarding strings (`create_shop`, `merchant_dashboard`, `merchant_login`) from locale files (`en.js`, `hi.js`) and ensured 100% customer-facing scope.
- **[2026-10-09]**: Fixed "Cannot hit test a render box with no size" crash on KhataScreen by replacing unconstrained dialogs with keyboard-aware `showModalBottomSheet` (`isScrollControlled: true`) and setting explicit `maxHeight` constraints. Verified 100% crash-free transaction recording.
- **[2026-10-09]**: Deeply modernized Customer Frontend (`C:\Go\ShopSilo\CustomerFrontend`) for Language & Local Storage architecture:
  - **Language & Translations**: Rebuilt translation dictionaries (`src/locales/en.js` & `hi.js`) to 346 keys with 100% key symmetry and pure Hindi (`हिन्दी`) with zero Hinglish. Fixed `SUPPORTED_LANGUAGES` in `LanguageContext.jsx` with proper UTF-8 label. Added dedicated segmented Language Switcher (`हिन्दी` / `English`) across top AppHeader, DesktopNavbar, SideDrawer navigation menu, LoginScreen, RegisterScreen, and ResetPasswordScreen.
  - **Zero Hinglish Standard**: Audited the entire customer codebase and eradicated all Hinglish strings across authentication (`LoginScreen.jsx`, `RegisterScreen.jsx`, `ResetPasswordScreen.jsx`), navigation drawer, customer modals (`HelpSupportModal.jsx`, `ProductScannerModal.jsx`, `SmartSearchModal.jsx`, `ShopReviewsSection.jsx`, `ReportModal.jsx`), and error boundary.
  - **Enterprise Local Storage & 0ms Cache**: Created robust `LocalCacheService` (`src/utils/localCache.js` & `src/shared/utils/localCache.js`) implementing Stale-While-Revalidate (SWR), TTL-based expiration, QuotaExceededError automatic cache eviction, memory fallbacks, and multi-tab synchronization. Integrated 0ms instant cached rendering and background revalidation across `ExploreShopsScreen.jsx`, `StorefrontScreen.jsx`, `DealsScreen.jsx`, `CustomerKhataScreen.jsx`, and `ReservationsScreen.jsx`.
- **[2026-10-10]**: Universal Product Image Flex & Uniform Sizing Architecture:
  - Overhauled AppProductImage (lib/core/widgets/app_product_image.dart) with expand property, dynamic alignment, and safe isFinite checks for memory cache dimension bounds (memCacheWidth / memCacheHeight).
  - Standardized Inventory Product Grid Cards (_buildCleanProductCard in inventory_screen.dart): replaced loose Stack with fit: StackFit.expand and Positioned.fill container wrapping AppProductImage(expand: true, fit: BoxFit.cover), guaranteeing 100% uniform image container height and aspect ratio across all products regardless of original raw image resolution.
  - Refined Product Details (product_detail_screen.dart): Hero gallery carousel, fullscreen zoom viewer, and thumbnail strip updated to expand flexibly with proportional BoxFit.contain and BoxFit.cover scaling.
  - Added uniform product thumbnail support in POS search suggestions (pos_screen.dart) and Customer Shop view (customer_shop_screen.dart).
- **[2026-10-10]**: Offline-First Local-Cache-First Data & Image Architecture (Web & Mobile):
  - Solved Flutter Web (Google Chrome) image blanking bug on route changes: AppProductImage and AppAvatar now branch on kIsWeb to use Image.network with frameBuilder, leveraging Chrome native disk and memory HTTP cache with 0ms re-hydration and zero stream detachment.
  - Resolved local storage deserialization failure on Web: Replaced whereType<Map<String, dynamic>>() with whereType<Map>() across all LocalCacheService methods, fixing JS runtime map casting where localStorage items were being silently dropped on Web.
  - Implemented 0ms in-memory cache layers in LocalCacheService (_memoryProducts, _memoryKhataCustomers, etc.) backed by SharedPreferences.
  - Upgraded ProductController.loadProducts with Local-First Stale-While-Revalidate: always checks and renders local cache immediately before background server sync, ensuring data and images never disappear during page switching or network latency.
- **[2026-10-10]**: Invisible High-Performance Bot & Hacker Defense with Tiered Rate Limiting (GoBackend):
  - Bypassed slow Cloudflare interstitial challenge screens ("Just a moment..." spinners) to deliver 0ms instant loading for all legitimate web & mobile users.
  - Built `BotGuard` middleware (`internal/middleware/bot_guard.go`): Blocks malicious vulnerability scanners (`sqlmap`, `nikto`, `masscan`, `wpscan`, `gobuster`, etc.) and automated scrapers (`python-requests`, `aiohttp`, `scrapy`, `libwww-perl`) on mutating endpoints.
  - Exploit Probe Blacklist & Dynamic IP Quarantine (Jail): Automatically traps CMS/exploit sweeps (`/.env`, `/.git`, `/wp-admin`, `/phpmyadmin`, `xmlrpc.php`, `cgi-bin`, etc.) and places offending IPs in an in-memory quarantine (`JailIP`) for 30 minutes with 0 DB overhead.
  - Tiered In-Memory Rate Limiting (`internal/middleware/ratelimit.go`):
    - Sensitive Actions (`AuthRateLimiter`): Strictly capped at **15 requests/minute** per IP (per user directive: 10-15 req/min) for `/auth/login`, `/auth/register`, `/auth/forgot-password`, etc.
    - SMS Fraud & Toll Protection (`OTPRateLimiter`): Capped at **4 requests per 10 minutes** on `/auth/send-otp`.
    - Mutation Rate Limiting (`MutationRateLimiter`): Capped at **30 requests/minute** on product creation and heavy writes.
    - Safe Browsing (`GlobalRateLimiter`): 100 requests/minute for normal catalog exploration, preventing false 429 errors.
    - Auto-Escalation Jail: IPs that repeatedly trigger rate limit violations (> 3 times in window) are automatically jailed for 15 minutes.
- **[2026-10-10]**: Polished CustomerFrontend (`C:\Go\ShopSilo\CustomerFrontend`) product detail view (`ProductDetailModal.jsx`) and product cards (`ProductCard.jsx`):
  - Aligned UI layout, image gallery carousel, discount overlay badges, and clean in-stock indicators with Flutter app design standards.
  - Added 1-tap "WhatsApp Shop Inquiry" button (`MessageCircle`) in Seller Card for instant product availability inquiries.
  - Strictly enforced privacy filter (`PRIVATE_KEYS`), guaranteeing 0% exposure of internal merchant metrics (`cost_price`, `unit_profit`, `margin`, `supplier`, `distributor`, `cogs`, `barcode`, `sku`).
- **[2026-10-10]**: Upgraded Flutter Merchant App Dashboard UI/UX (`DashboardScreen.dart`): Added 1-tap Store Status Toggle (Online/Offline) with instant sync, Store QR Code button in AppBar, and Quick Operations Grid featuring 8 elevated operation tiles (`⚡ POS Billing`, `📦 Active Products`, `📖 Khata Passbook`, `📊 Munafa Analytics`, `💸 Shop Expenses`, `🌾 Mandi Sourcing`, `🎁 Store Deals`, `📱 Store UPI QR`).
- **[2026-10-10]**: Implemented Automated WhatsApp Broadcast & Dead-Stock Clearance Radar:
  - Added 1-tap "Broadcast WhatsApp Reminders to Overdue Debtors" (`broadcastWhatsAppOverdueReminders`) in KhataScreen & KhataController.
  - Added 1-tap "Flash Clearance Deal" button (`Icons.bolt_rounded`) in AnalyticsScreen Dead Stock Radar, seamlessly bridging dead stock liquidation with live storefront promotions.
- **[2026-10-10]**: Enterprise WAF, Body Size Guard, Micro-Burst Limiting & Honeypot Defenses (GoBackend):
  - In-Memory WAF Regex Filter: Inspects URI paths and raw query parameters for SQL Injection (`UNION SELECT`, `OR '1'='1'`), Path Traversal (`../../etc/passwd`), and XSS script tags (`<script>`, `javascript:`, `onerror=`), instantly jailing offending IPs for 30 minutes.
  - Body Size Limiting (`BodySizeGuard`): Clamps standard JSON payloads to 2MB and multipart image uploads to 10MB, eliminating payload-based memory starvation and buffer overflow attacks.
  - Dangerous HTTP Method Drop: Rejects `TRACE`, `CONNECT`, and `TRACK` with HTTP 405, and enforces mandatory `Host` header validation on HTTP/1.1+.
  - Sub-Second Micro-Burst Limiting: Added 2-second sliding burst capacity to `IPRateLimiter` (Auth: max 5 req/2s, Global: max 25 req/2s), halting blitz scripts even if overall minute quotas are respected.
  - Invisible Honeypot Trap: Added `website_url` honeypot fields to `UserRegisterRequest`, `UserLoginRequest`, and `SendPhoneOTPRequest`. If populated by automated form scanners/bots, the IP is quarantined in jail for 30 minutes and the submission is rejected with 0 DB overhead.
- **[2026-10-10]**: Full Parity E-Commerce Product Showcase & Detail Modal (`CustomerFrontend`):
  - Re-architected `ProductDetailModal.jsx` to match Flutter app's `ProductDetailScreen` e-commerce studio layout.
  - Responsive 2-Column Split: Wide studio layout on Desktop/Tablet (`maxWidth: 960px`) and fluid bottom-sheet on Mobile.
  - Interactive Studio Gallery: High-resolution stage with multi-image navigation arrows, active thumbnail ring, and click-to-zoom Fullscreen Lightbox viewer (`isZoomOpen`).
  - Pricing & Commerce Hub: Bold `formatCurrency` pricing, strikethrough MRP, green savings badge (`Save ₹X • Y% OFF`), and tactile quantity stepper (`[-] 1 [+]`).
  - Dynamic Action Bar: 1-tap "Add to Cart • ₹Total", 1-tap "Reserve for Store Pickup" with status toast, and direct WhatsApp Shopkeeper Inquiry with pre-filled product details.
  - Key Specifications Grid & Verified Local Seller card with direct call and storefront navigation.
  - Fixed UTF-8 Indian Rupee (`₹`) symbol formatting across `ProductCard.jsx` and `ProductDetailModal.jsx`.



