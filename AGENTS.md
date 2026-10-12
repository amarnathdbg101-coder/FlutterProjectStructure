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
8. **LOCKED - Instant Non-Blocking Product Creation & Background Processing**:
   - In Add Product and Edit Product flows, all input validation (name, selling price, MRP, cost price, floor price, stock) must run synchronously upfront.
   - Once validation passes, the modal/sheet MUST close immediately (`Navigator.pop`) with an instant success confirmation toast.
   - The user must NEVER be blocked by spinners or network waiting times.
   - The product is immediately added/updated in the local inventory catalog with 0ms optimistic UI.
   - Image uploading, SKU sync, and backend API persistence execute silently in the background. In case of server error, optimistic items are cleanly reverted with an unobtrusive error alert.
9. **LOCKED - Canonical Category Name Display & Bidirectional Mapping**:
   - Products must ALWAYS display clean, human-readable Category Title Names (e.g., "Dairy, Bakery & Frozen", "Grocery & Staples") across all UI screens (Catalog, Details, POS, Edit sheets).
   - Raw backend category UUIDs, slugs (e.g. `dairy-breakfast`), and raw IDs must NEVER be shown to merchants.
   - When creating or editing products, embed `category_name` and `category` directly in `attributes` (JSONB) so PostgreSQL preserves the exact user-selected name across all queries.
   - CategoryRegistry maintains bidirectional mapping between backend UUIDs, API slugs, and Title Names, safely defaulting unknown UUIDs to 'General Store' instead of leaking raw hex strings.
10. **LOCKED - Complete Product Specifications & Dynamic Custom Attributes Persistence**:
   - All product specifications (Brand, Unit, Net Weight, SKU, Barcode, Floor Price, Bargain status, and all dynamic custom attributes like Size, Color, Flavor, Warranty, Model, etc.) must be 100% preserved and displayed across the entire lifecycle (Creation, Update, Retrieval, Inventory Catalog, Product Details Screen, and Edit Sheet).
   - GoBackend must unmarshal `attributesBytes` in `Create` and `Update`, and include `floor_price`, `allow_bargain`, and `is_price_public` in `FindAll`.
   - Frontend `ProductModel.fromJson` must parse stringified JSONB attributes, fallback attributes, and top-level spec keys. `toJson` and `ProductController` must merge and preserve all optimistic attributes so no merchant-entered data is ever lost.
11. **LOCKED - High-Resolution Image Upload Resilience & Non-Destructive Sync**:
   - GoBackend BodySizeGuard permits multipart/form-data payloads up to 40MB (`40 << 20`) to safely accommodate up to 4 high-resolution uncompressed smartphone photos (e.g. Vivo, Samsung, iPhone).
   - GoBackend automatically optimizes and downscales images to HD standard (1600px, JPEG quality 80) via `CompressImage` before saving to Cloudflare R2 storage.
   - GoBackend `UploadImage` supports MIME parameters, `image/x-png`, `image/pjpeg`, and magic byte sniffing with `http.DetectContentType` fallback.
   - In `ProductController`, background image uploads must never fail silently. If background image upload encounters an error, display an actionable warning toast and NEVER overwrite existing product images on the server with an empty list.
   - Frontend `isLocalFilePath` identifies `content://`, `file://`, and device sandbox paths. `isServerImageUrl` strictly matches real remote CDN/backend URLs (`https://`, `http://`, `/images/`, `/uploads/`), preventing local filenames from being prematurely treated as server URLs.
12. **LOCKED - Real Hardware GPS Location Capture & Sanitized Store Updates**:
   - Store GPS detection must ALWAYS query physical device hardware GPS (via `geolocator` high-accuracy position and last known position fallback). Never use regional IP lookups (`ipapi.co`, etc.) which misroute North Bihar/UP cell networks to Darbhanga / Patna regional telecom towers.
   - Live GPS button must NEVER short-circuit or re-extract stale coordinates from pre-filled Google Maps text fields.
   - When saving store location (`/shops/me`), only include non-empty trimmed strings for `address`, `city`, and `pincode` to satisfy backend `min=1` validation. Send parsed numeric doubles for `latitude` and `longitude`.
   - `AuthController.updateShop` updates `latitude`, `longitude`, and `googleMapsUrl` in optimistic `copyWith` state and re-fetches details on success.
13. **LOCKED - Storefront Price Privacy & Hide Price (Bargain Protection)**:
   - Merchants can hide the online public price for any product (`isPricePublic = false`) from the Add/Edit Product Modal and Product Detail Screen.
   - For products with hidden price, public customer storefront (`CustomerShopScreen`) must NEVER leak or display numeric price, MRP, or discount percentage.
   - Public customer storefront cleanly displays a "Price on Request / मोलभाव करें" badge and adapts the WhatsApp contact button to "Ask Price" (inquires for best price so customer visits store or chats to negotiate).
   - In merchant inventory catalog and product details, the internal selling price is preserved for the shop owner with clear visual indicators (`[Price Hidden]` / `Hidden Online`), along with an instant 1-tap toggle.
   - `is_price_public` is serialized in top-level JSON and inside PostgreSQL's `attributes` JSONB map to guarantee 100% persistence across all backend versions.
14. **LOCKED - Shop Side Fast In-Memory Multi-Field Search & Comprehensive Sorting Engine**:
   - In `inventory_screen.dart`, product searching operates 100% in-memory across the locally cached catalog with 0ms latency, zero network round-trips per keystroke, and zero loading spinner flashes.
   - Search uses tokenized multi-field matching across `name`, `sku`, `barcode`, `category`, `brand`, and all dynamic custom `attributes`, allowing out-of-order terms (e.g. 'salt tata' matches 'Tata Salt Vacuum Evaporated 1kg').
   - Inventory sorting provides 9 merchant business modes: Newest First, Low Stock (Reorder First), High Stock, Price (High to Low / Low to High), Highest Profit Margin %, Name (A-Z / Z-A), and Hidden Price (Bargain Items First).
   - Horizontal quick filter pills (All, Low Stock, Hidden Price, On Sale, and dynamic inventory categories) allow 1-tap filtering with live count badges.
   - Results summary counter with 1-tap 'Reset All Filters' action, and distinct empty states for 'Empty inventory' vs 'No matching search/filter results'.
15. **LOCKED - Strict Separation of Merchant Flutter App & Customer Privacy Shield (Selective Visibility Engine)**:
   - **Flutter Merchant App Scope**: The Flutter application is strictly and exclusively the Merchant / Store Partner app. All customer-facing screens (`customer_shop_screen.dart`) and routes (`/shop/:slug`) are permanently purged. Never add customer browsing screens to this Flutter app.
   - **Customer Web App (`CustomerFrontend`)**: The React Vite application (`CustomerFrontend`) is the official public storefront for buyers.
   - **Full Public Specification Transparency**: Customers can see all legitimate product information uploaded by merchants: Title, Brand, Category Title, Description, High-res Images, Unit, and ALL dynamic specifications (Color, Size, Warranty, Shelf Life, Ingredients, Country of Origin, Material, Weight, etc.).
   - **Enterprise Privacy Shield (Blocklist)**: Strictly block internal merchant-only and sensitive commercial data at the GoBackend API level (`sanitizePublicProduct`) and CustomerFrontend modal (`PRIVATE_KEYS` / `CustomerPrivacyShield`):
     - Financials & Margins: `cost_price`, `cogs`, `unit_profit`, `profit_margin_pct`, `profit`, `margin`, `wholesale_price`, `purchase_price`, `kharid_price`.
     - Bargain Rules: `floor_price`, `min_price`, `bottom_price`, `allow_bargain`.
     - Procurement & Vendors: `supplier`, `distributor`, `vendor`, `dealer`, `procurement_cost`.
     - Inventory Thresholds: `reorder_point`, `low_stock_threshold`, `min_stock`.
     - Internal Barcodes & System IDs: `barcode`, `sku`, internal IDs.
     - System Flags: `is_price_public`, `hide_price`, `is_active`, `is_featured`, raw UUIDs.
   - **Price Privacy**: When `is_price_public` is false, CustomerFrontend hides numerical price/MRP/discounts, displays 'Price on Request / मोलभाव करें', and activates the WhatsApp 'Ask Price' negotiation flow.
16. **LOCKED - Enterprise Component Consolidation & Clean UI Architecture (`CustomerFrontend`)**:
   - Atomic design components centralized in `src/components/ui/` (`BaseModal`, `ModalHeader`, `ModalBody`, `ModalFooter`, `Button`, `Badge`, `Card`, `SectionHeader`, `QuantityStepper`, `RatingStars`, `SearchInput`, `FormField`, `Input`, `Textarea`, `AlertBanner`, `Skeleton`).
   - Standardized across 35+ modals, drawers, cards, and customer screens, eradicating duplicate inline modal headers, button styles, and badges.
   - Zero feature or translation deletions; 100% feature fidelity preserved.
17. **LOCKED - Stale-While-Revalidate (SWR) & Event-Driven Invalidation Engine (`CustomerFrontend`)**:
   - **Dual-Tier Synergy**: 0ms instant cache hydration via passive TTL caching (`src/utils/localCache.js`) combined with active event-driven invalidation via `CacheEventBus` (`src/utils/cacheEvents.js`).
   - **Synchronous Eviction on Emit**: `cacheEvents.emit(event, payload)` automatically evicts target cache keys from storage and memory before notifying listeners, guaranteeing that unmounted screens never hydrate stale data on next mount.
   - **Memory Leak & Quota Protection**: In-memory cache bounded to 100 entries with LRU eviction. Storage quota auto-evicts expired entries followed by oldest 25% on `QuotaExceededError`.
   - **Security & Privacy Shield**: On `AUTH_LOGOUT`, `localCache.clearUserData()` wipes all private customer passbooks (`shopsilo_cache_khata_`), reservations, profiles, and saved addresses from both browser storage and memory.
   - **In-Flight Request Deduplication & Smart Diffing**: `useSWR` deduplicates simultaneous identical API calls and performs deep JSON serialization comparison before triggering React state changes, eliminating flicker and layout shifts.
18. **LOCKED - Flutter Stale-While-Revalidate (SWR) & Event-Driven Invalidation Architecture (`Frontend`)**:
   - **Centralized Broadcast Event Bus (`AppEventBus`)**: Broadcast stream with synchronous targeted cache eviction on `emit()` across 9 mutation event types (`productsMutated`, `inventoryMutated`, `posSaleCompleted`, `khataMutated`, `expenseMutated`, `offerMutated`, `reservationMutated`, `shopProfileUpdated`, `authLogout`).
   - **Dual-Tier Cache Engine (`LocalCacheService`)**: Synchronous 0ms in-memory cache backing device persistent storage (`SharedPreferences`) across Products, Khata, Expenses, Offers, 24h Sales, Analytics, and Reservations.
   - **Leak & Security Guarantee on Logout**: `LocalCacheService.clearCache()` immediately wipes all static in-memory lists (`_memoryProducts`, `_memoryKhataCustomers`, `_memoryProcurementItems`, `_memoryExpenses`, `_memoryOffers`, `_memorySalesHistory`, `_memoryReservations`) and purges all device storage keys.
   - **Full Controller Interlocking**: 100% mutation wiring and subscription cleanup across `ProductController`, `DashboardController`, `KhataController`, `PosController`, `ExpenseController`, `ReservationController`, `OfferController`, `ProcurementController`, and `AuthController`.
19. **LOCKED - Retail POS Dynamic UPI, Executive Bills, Inventory Quick Stock & Digital Khata Suite (`Frontend`)**:
   - **Dynamic UPI QR Code (`dynamic_upi_qr_dialog.dart`)**: Scannable instant dynamic UPI QR generator (`upi://pay?pa=...&pn=...&am=...&cu=INR`) for PhonePe, Google Pay, Paytm, and BHIM with exact billing totals. Allows one-time UPI ID setup and background persistence via `AuthController.updateShop({'upi_id': ...})`.
   - **Executive Itemized WhatsApp Bill & 1-Tap Copy (`pos_screen.dart`)**: Formats professional retail receipts containing store name, address, contact, bill #, date, itemized list with line amounts, subtotal, discount, grand total, and thank-you message. Includes 1-tap "Copy Bill Receipt" button to clipboard.
   - **Inventory Stock Indicators & 1-Tap Quick Adjuster (`inventory_screen.dart`)**: Clean stock badges (Out of Stock, Low Stock, or In Stock) and quick-action bottom sheet with interactive stepper counter and delta chips (`-5`, `-1`, `+5`, `+10`, `+25`, `+50`) for immediate stock restock/adjustments via `editProduct`.
   - **Khata Ledger Summary Copy (`khata_screen.dart`)**: 1-tap "Copy Summary" button to copy customer credit ledger statement to clipboard.

## 4. Continuous User Decisions Log
- See [PROJECT_RULEBOOK.md](file:///c:/Go/ShopSilo/Frontend/PROJECT_RULEBOOK.md) Section 5 for the complete history of user requirements and architectural decisions.
- Whenever the user gives a new rule or permanent decision, update both `PROJECT_RULEBOOK.md` and this file.

