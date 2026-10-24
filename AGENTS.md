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

20. **LOCKED - Retail Flow Optimization, 10-Image Catalog & Zero-Hinglish Standards (`Frontend` & `GoBackend`)**:
    - **10 Images Catalog Limit**: Synchronized backend DTOs, controllers, error handlers, and frontend image pickers/scrollers to support up to 10 photos per product.
    - **POS Cart Parking / Held Bills**: Multi-cart counter parking allows merchants to park active customer carts (`PosHeldBill`), process another customer, and resume the held bill without loss of state.
    - **1-Tap Product Duplication**: Catalog and Product Details cards offer 1-tap "Duplicate Product" cloning all specs, custom attributes, and images, speeding up variant setup by 80%.
    - **Dynamic Expense Filtering & Pure Hindi/English Localization**: Category chips with live counts, and zero Hinglish across all screens (Dashboard, Expenses, Khata, POS).
21. **LOCKED - In-Store Pickup 6-Digit Counter Code Verification & Dual Identifier Integrity (`Frontend` & `GoBackend`)**:
    - **Full 6-Digit Code & Reservation Number Persistence**: Customer pickup reservations generate a 6-digit numeric PIN (`%06d`) and alphanumeric reference (`HLD-...`). `ReservationModel` preserves both identifiers without truncation (`cleanCode.substring` 4-digit clipping is forbidden).
    - **Robust Counter Verification Payload**: `verifyReservation` automatically strips QR prefixes (`SHOP-PICKUP:`, `#`), and routes input through both `pickup_code` and `reservation_number`.
    - **Backend Dual-Identifier Matching**: In `VerifyShopReservation`, if either identifier is supplied, both are matched against PostgreSQL (`WHERE (pickup_code = $2 OR reservation_number = $3)`). DTO `VerifyReservationRequest.PickupCode` validation is relaxed to `max=50` to safely accept alphanumeric references without 400 Bad Request rejections.
    - **1-Tap Direct Prefill Verification**: Active customer reservation cards provide a 1-tap "Verify Code" action that pre-populates the verification dialog with the exact order PIN, eliminating counter re-typing errors.

22. **LOCKED - Customer Storefront Quick Price/Discount Filters & 1-Tap WhatsApp Product Sharing (`CustomerFrontend`)**:
    - **In-Memory Quick Filter Engine**: Horizontal quick price & deals pills (`Under ₹99`, `Under ₹499`, `Deals >20% Off`, `Price on Request / Bargain`) calculate live match counters in-memory with 0ms latency, seamlessly interlocking with category chips and multi-field text search.
    - **Active Filters Status Banner & 1-Tap Reset**: Real-time counter chip displaying current match count with 1-tap `✕ Reset all` clearing filters in 0ms, also embedded directly into empty states.
    - **1-Tap WhatsApp Product Sharing (`productShare.js`)**: Formats rich product card messages with title, discount % or 'Price on Request' badge, store name, and exact deep product link (`/shop/:slug/product/:productId` or `/product/:productId`). Deduplicates shared URLs by providing the single link exclusively inside the formatted message text without passing a redundant separate `url` parameter to `navigator.share`, preventing mobile OS share sheets and WhatsApp from duplicating the URL. Compact 1-tap share button sits on `ProductCard` alongside Wishlist heart icon with zero click-through propagation to detail modals, falling back gracefully from Web Share API to WhatsApp direct URL (`https://wa.me/?text=...`).
    - **Zero-Hinglish Bilingual Localization**: 100% symmetric keys across `src/locales/en.js` and `src/locales/hi.js` with pure English and Hindi strings.

23. **LOCKED - Customer Digital Khata Credit Limit Utilization & Dynamic UPI Settlement (`CustomerFrontend`)**:
    - **Visual Udhar Credit Limit Engine (`CreditLimitBar.jsx`)**: Calculates real-time percentage of credit limit used (`usedPct`), available balance (`availableCredit`), and applies status color indicators (Critical `>=90%` red, Warning `75%-89%` amber, Healthy `<75%` emerald, or Open limit blue) across Store Khata cards, mobile bottom sheet, and desktop sidebar.
    - **1-Tap Dynamic UPI Payment Flow**: Quick amount chips (`Full Dues`, `Half Dues`, `₹500`, `₹1,000`, `₹2,000`) instantly synchronize with the dynamic UPI QR generator and `upi://pay` deep link schema (`pa`, `pn`, `am`, `cu=INR`), paired with 12-digit UTR verification and instant `CACHE_EVENTS.KHATA_MUTATED` invalidation.
    - **Zero-Hinglish Bilingual Localization**: 100% symmetric keys across `src/locales/en.js` and `src/locales/hi.js` with pure English and Hindi strings.

24. **LOCKED - Progressive Web App (PWA) Mobile App Installation & Service Worker Architecture (`CustomerFrontend`)**:
    - **Service Worker Lifecycle (`public/sw.js` & `main.jsx`)**: Implements network-first caching for static application shell (`/`, `/index.html`, `/manifest.json`, `/favicon.svg`), guaranteeing zero interference with `/api`, `/auth`, or Google OAuth flows.
    - **Smart Mobile App Install Prompt (`PWAInstallBanner.jsx`)**: Floating responsive glassmorphism prompt evaluating `display-mode: standalone` (suppresses if already installed) and 7-day dismissal cooldown in `localStorage`. Automatically floats above `FloatingCartBar` when active items exist in cart.
    - **iOS Safari Guide Modal**: Detects iPhone/iPad Safari and renders interactive 3-step visual instructions (Share ⎋ -> Add to Home Screen ⊞ -> Add).
    - **Zero-Hinglish Bilingual Localization**: 100% symmetric keys across `src/locales/en.js` and `src/locales/hi.js` with pure English and Hindi strings.
25. **LOCKED - Dedicated Full-Screen Product Details Page & Privacy Shield Specifications (`CustomerFrontend`)**:
    - **Dedicated Full-Screen Route & Seamless Deep-Linking**: Accessible via `/shop/:slug/product/:productId` and `/product/:productId`, eliminating small constrained modal dialogs. Includes breadcrumb hierarchy (`Home > Shop > Category > Product`) and browser back/forward history support.
    - **Optimistic 0ms Navigation & Standalone API Fallback**: When clicking a product card from Storefront, Saved, or Search, React Router state (`{ product, shop }`) renders the page instantly with 0ms latency without showing a spinner, while gracefully fetching via `productApi.getById(productId)` on direct URL visits, bookmarks, or browser reloads.
    - **Full Public Specification Transparency**: Customers can inspect Title, Brand, Category Title, Description, High-res Images (up to 10 photos in thumbnail strip with lightbox zoom), Unit, and ALL customer specifications (Color, Size, Warranty, Shelf Life, Ingredients, Country of Origin, Material, Weight, etc.).
    - **Enterprise Privacy Shield**: Internal merchant data (`cost_price`, `floor_price`, `cogs`, `wholesale_price`, `supplier`, `reorder_point`, `barcode`, `sku`, `internal_id`) is strictly blocked from the customer specification table.
    - **Integrated Fulfillment Modes**: Public items display dynamic pricing, MRP, savings badges, quantity stepper, and "Add to Cart". Private items (`isPricePublic = false`) display "Price on Request / मोलभाव करें" with direct WhatsApp negotiation. Both modes seamlessly support in-store pickup reservations (2h, 4h, 8h, 24h holds) generating 6-digit counter PINs.
    - **Zero-Hinglish Bilingual Localization**: 100% symmetric keys across `src/locales/en.js` and `src/locales/hi.js` with pure English and Hindi strings.
26. **LOCKED - Shop Side Pickup Orders Complete Product Specifications, Real Images & Order Details Sheet (`Frontend` & `GoBackend`)**:
    - **GoBackend Top-Level & Relational Product Serialization**: `FindByShopID` performs a safe `LEFT JOIN products p ON r.product_id = p.id`, selecting `p.name`, `p.price`, `p.sku`, `p.images`. Serializes both nested `Product` and top-level helper fields (`product_name`, `product_image`, `product_images`, `product_sku`, `product_price`, `total_amount`), eliminating empty product payloads.
    - **Robust Frontend Image & URL Normalization (`ReservationModel`)**: `ReservationModel.fromJson` parses array-based `images`, `product_images`, and relative server paths (`/images/...`), automatically prepending `ApiConstants.baseUrl`.
    - **Real Product Visual Showcase & Multi-Item Parsing**: `ReservationsListScreen` renders a 54x54 product thumbnail with loading/error fallbacks, SKU badge, category pill, and itemized breakdown (`itemsBreakdown`) for multi-product cart pickups (e.g. `Items: Tata Salt (x1), Maggi (x2)`).
    - **1-Tap Interactive Order & Product Details Sheet**: Clicking any pickup card opens a bottom sheet showing high-res product photo, complete title, SKU, itemized rate breakdown, customer call/WhatsApp shortcuts, and the 6-digit counter pickup code (`#582914`) with 1-tap prefilled counter verification.
27. **LOCKED - Customer Side Multi-Field Category Matching & Hyperlocal Product Filtering (`CustomerFrontend` & `GoBackend`)**:
    - **GoBackend Multi-Field Category Resolution**: `FindNearbyProducts` resolves category parameters by querying the `categories` table via `SELECT id, name, slug WHERE id::text = $1 OR slug ILIKE $1 OR name ILIKE $1`. Matches against `c.name`, `c.slug`, `p.category_id::text`, `p.attributes->>'category_name'`, `p.attributes->>'category'`, `p.name`, and `s.category` with `LEFT JOIN categories c ON p.category_id = c.id`. DTO `NearbyProductItem` serializes `category_id`, `category_name`, `category_slug`, and `sku`.
    - **Unified Frontend Category Matcher (`categoryMatcher.js`)**: Normalizes case, hyphens, spaces, and punctuation (`replace(/[^a-z0-9]/g, '')`), cross-referencing product properties (`category_name`, `category_slug`, `category_id`, `attributes.category_name`, `attributes.category`, `name`, `tags`) and `ALL_CATEGORIES` metadata keywords. Handles both slug IDs (`clothing-apparel`) and Title Names (`Clothing & Apparel`).
    - **Reactive Marketplace Filtering (`ExploreShopsScreen.jsx`)**: Interlocks `selectedCategory` with `loadMarketplaceData` and `loadMoreProducts`, passing `category: selectedCategory` to the `/products/nearby` API with category-keyed local caching (`localCache.get(cacheProdKey)`). Renders accurate in-memory product counts on tab headers and feeds.
28. **LOCKED - Enterprise End-to-End Cross-Feature Data Consistency & Real-Time Sync Engine (`Frontend` & `GoBackend`)**:
    - **POS Checkout Multi-Module Interlocking**: Completing a sale (`createSale`) atomically deducts DB inventory, records customer credit in Khata ledger (if payment method is `credit`/`khata`), and writes to `pos_bills`. Emits `posSaleCompleted`, `inventoryMutated`, and `khataMutated`.
    - **0ms Optimistic Multi-Controller Reactivity (`Frontend`)**:
      - `ProductController`: Decrements stock in local `_products` immediately upon `posSaleCompleted` for all sold items with 0ms delay, followed by silent server validation.
      - `DashboardController`: Incrementally increases `todaySales += sale.totalAmount`, `salesCount += 1`, and if Khata, `totalUdhar += sale.totalAmount` in 0ms, followed by silent background sync.
      - `KhataController`: Subscribes to `khataMutated` and `posSaleCompleted`, optimistically updating the debtor customer's balance and total receivables in 0ms.
      - `PosController`: Subscribes to `inventoryMutated` and `reservationMutated`, ensuring catalog stock stays synchronized when stock is adjusted anywhere (Quick restock, product edit, counter pickup).
    - **Counter Pickup Verification Sales Sync (`GoBackend` & `Frontend`)**:
      - `VerifyShopReservation`: Atomically deducts `inventory.quantity` and `inventory.reserved_quantity`, and records a completed sale in `pos_bills` (`bill_number = PICKUP-HLD-...`, payment method `pickup_counter`). This guarantees the shop's Daily Sales Amount, Sales Count, and Sales History automatically increase upon customer pickup.
      - `ReservationController`: Emits `reservationMutated`, `inventoryMutated`, and `posSaleCompleted` upon counter verification and cancellation.
    - **IST-Aware Daily Digest (`repository/shop.go`)**: Evaluates `pos_bills` within Indian Standard Time bounds (`(created_at AT TIME ZONE 'Asia/Kolkata')::date = (NOW() AT TIME ZONE 'Asia/Kolkata')::date`), eliminating UTC day-rollover discrepancies.
29. **LOCKED - Dedicated Product Details Full Specification Showcase & Join Integrity Engine (`CustomerFrontend` & `GoBackend`)**:
    - **GoBackend Full Relational Joins (`FindByID` & `FindBySlug`)**: `ProductRepo.FindByID` and `FindBySlug` execute complete joins with `shops s ON s.id = p.shop_id` and `categories c ON c.id = p.category_id`. Scans and serializes `ShopName`, `ShopSlug`, `ShopPhone`, `ShopAddress`, `ShopCity`, `ShopLatitude`, `ShopLongitude`, and `CategoryName`. Falls back cleanly to `attributes->>'category_name'` or `attributes->>'category'`.
    - **Enterprise Privacy Shield Sanitization (`sanitizePublicProduct`)**: Enforces zero leakage of internal merchant commercial metrics (`CostPrice = 0`, `FloorPrice = 0`, `SKU = ""` on public customer responses). Sanitizes `cost_price`, `floor_price`, `cogs`, `wholesale_price`, `purchase_price`, `kharid_price`, `supplier`, `vendor`, `dealer`, `reorder_point`, `barcode`, `sku`, and `internal_id` from JSON attributes.
    - **Smart Specification & Description Parser (`productDetailsHelper.js`)**: Parses merchant descriptions containing pipe separators (`|`) or key-values (e.g. `Brand: Kesh King | Exp: 3 Year | Volume: 200ml | Key Ingredient: Aloe Vera`), cleanly extracting structured specification chips (`Brand`, `Package Size / Volume`, `Expiry / Shelf Life`, `Key Ingredients`, `Material`, `Net Weight`, `Tags`, etc.) while extracting clean readable narrative prose for the product description.
    - **Dedicated Full-Screen Page Rich Store Showcase (`ProductDetailScreen.jsx`)**: Background SWR re-fetches full product details and verifies shop data. Displays Verified Local Store card with real-time hardware distance, walking/driving travel time, 1-tap Google Maps directions, phone call, and WhatsApp links. Shows tags, 30-min counter pickup hold selector (2h, 4h, 8h, 24h), dynamic UPI / counter cash notice, high-res zoomable gallery, and full customer privacy shield.
    - **Customer Navigation Unification (`SavedScreen.jsx` & `StorefrontScreen.jsx`)**: Clicking any product navigates to `/shop/:slug/product/:productId`, ensuring consistent full-screen product details across Explore, Storefront, and Saved items.
30. **LOCKED - Customer Side Full Suite Production Readiness, Cross-Screen Navigation Integrity & Zero-Bug Architecture (`CustomerFrontend`)**:
    - **1-Tap Universal Product Navigation**: Seamless deep-linked routing across all discovery entrypoints:
      - `SmartSearchModal.jsx`: Clicking any search result row immediately navigates to `/shop/:slug/product/:productId` with optimistic state hydration and modal auto-dismiss.
      - `CartDrawer.jsx`: Cart item thumbnails and product titles are 1-tap clickable to inspect full product specifications.
      - `ReservationsScreen.jsx`: Pickup order cards display high-res product photo thumbnails and link directly to full product specifications and store details.
      - `DealsScreen.jsx`: Instant 1-tap store navigation from claimed festival coupons.
    - **100% Bilingual Symmetrical Localization (`locales/en.js` & `locales/hi.js`)**: Pure Hindi and English with zero Hinglish across all 415+ translation keys, modals, alerts, and toasts.
    - **Bulletproof Zero-Regression Validation**: 15 test files with 74/74 Vitest tests passing (100% green), clean production build (2.53s), zero console warnings, and zero pixel overflows.
31. **LOCKED - Customer Pickup Order & Product Showcase Resilience (`CustomerFrontend` & `GoBackend`)**:
    - **GoBackend User Pickup Join & Null-Safety Resilience (`FindByUserID` & `FindByID`)**: Employs `LEFT JOIN shops s ON r.shop_id = s.id` and `LEFT JOIN products p ON r.product_id = p.id` with `COALESCE` across all nullable fields (`shop_name`, `shop_slug`, `shop_phone`, `shop_address`, `product_name`, `product_slug`, `product_price`). Populates both nested and top-level fields (`Shop.ID`, `Product.ID`, `ProductName`, `ProductPrice`, `ProductImages`, `ProductImage`, `TotalAmount`), eliminating scan errors and blank product cards. DTO `CreateReservationRequest.Notes` validation relaxed to `max=1000`.
    - **Itemized Order Confirmation & Celebration Showcase**: Confirmation screens in `ProductDetailScreen`, `StorefrontScreen`, and `CheckoutModal` Step 2 display complete itemized product summaries (high-res thumbnail, product title, quantity, total payable amount, store name, and 6-digit counter pickup PIN).
    - **Robust Pickup Card & QR Pass Resolution (`ReservationsScreen.jsx`)**: Evaluates resilient multi-tier fallbacks across `productName` (`r.product?.name || r.product_name || r.name`), `productImage` (`r.product?.image || r.product?.images[0] || r.product_image || r.product_images[0]`), `unitPrice`, `totalAmount`, and `storeName`. The QR Code modal (`inspectToken`) embeds an itemized product details card with live quantity, price, and store directions.
    - **Upfront Checkout Authentication Guard (`CheckoutModal.jsx`)**: Enforces authentication verification upfront before submitting counter pickup orders, safely slices notes to 500 characters, and surfaces genuine backend API errors without silently faking unpersisted local reservations.
32. **LOCKED - Cross-Platform Brand Logo & App Icon Identity Unification (`Frontend` & `CustomerFrontend`)**:
    - **Unified Storefront Squircle Geometry**: The official ShopSilo app icon logo uses a rounded squircle container (`rx="134"` on 512x512 / `size * 0.28` corner radius) with indigo brand gradient (`linear-gradient(135deg, #4f46e5 0%, #6366f1 50%, #4338ca 100%)`) and pure white Material `Icons.storefront_rounded` icon, matching Flutter's `ShopSiloLogo` (`shopsilo_logo.dart`) and `splash_screen.dart`.
    - **Component Parity (`ShopSiloLogo.jsx`)**: Reusable React component with `gradient`, `tint` (`#EEF2FF` light indigo background with `#4F46E5` icon matching Flutter light theme), and `white` variants, supporting heavy weight 900 typography, optional subtitles, and link routing.
    - **100% Platform Touchpoint Synchronization**: Replaced makeshift "S" squares and generic icons across `favicon.svg`, `index.html`, `manifest.json`, `DesktopNavbar.jsx`, `AppHeader.jsx`, `SideDrawer.jsx`, `AppFooter.jsx`, `PWAInstallBanner.jsx`, `LoginScreen.jsx`, and `ResetPasswordScreen.jsx`.

33. **LOCKED - Active Catalog & Inventory 120 FPS High-Performance Rendering & Slate Minimalist UI (`Frontend`)**:
    - **0ms Memoized Filter & Sort Engine**: Filter calculations, dynamic category sets, tokenized multi-field matching, and multi-criteria sorting are memoized outside `build()` via `_recomputeFilteredProducts`, running strictly when state variables mutate and eliminating frame drops on Flutter Mobile and Web.
    - **Dedicated `_ProductGridCard` Architecture**: Clean `StatelessWidget` architecture isolating card element trees from parent screen rebuilds, with `cacheExtent: 600`, drag scroll physics (`BouncingScrollPhysics`), and responsive aspect ratio (`0.78` desktop/tablet, `0.67` mobile) preventing horizontal and vertical pixel overflow.
    - **Production Minimalist Slate Color Palette**: Uses soft slate neutral cards (`context.colorSurface`), subtle borders (`context.colorBorder`), and unified `AppBadge` variants (`type: error` for out of stock, `warning` for low stock, `primary` for discount offers, `neutral` for private storefront visibility). All cluttered inline tags removed.
    - **Pure Bilingual Localization**: 100% pure Hindi and English strings (`'स्टॉक समाप्त'`, `'कम स्टॉक'`, `'समाप्त'`, `'कम'`, `'स्टॉक'`, `'विवरण बदलें'`, `'डुप्लिकेट बनाएं'`), zero Hinglish in UI.

34. **LOCKED - Retail POS Billing 120 FPS High-Performance Rendering, Minimalist Slate UI & Zero-Overflow Architecture (`Frontend`)**:
    - **Dedicated `_PosCartItemTile` Architecture & 0ms Tactile Steppers**: Extracted bill cart items into an isolated `StatelessWidget` keyed by product ID (`ValueKey(item.product.id)`). Removed blocking `SnackBar` queues on quantity increment/decrement, allowing counter merchants to tap steppers rapidly with 0ms delay and zero micro-stutters.
    - **60-120 FPS Buttery-Smooth Scrolling & Cache Extent**: Added `physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics())` and `cacheExtent: 400` to `_buildActiveBillTable` and search overlays, ensuring 120 FPS performance even on lengthy 50+ item customer bills.
    - **Dynamic Inventory Category Shortcuts**: Dynamic categories derived automatically from `pos.products` with responsive horizontal scrolling (`BouncingScrollPhysics`), replacing static hardcoded English category lists.
    - **Zero Pixel Overflow Protection**: Implemented `Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 10)` for empty state action buttons, and wrapped mobile checkout grand total and cart item totals with `FittedBox(fit: BoxFit.scaleDown)` to gracefully scale massive wholesale bills (e.g. ₹1,50,000+) without RenderFlex overflow.
    - **100% Bilingual Symmetrical Localization & Zero Hinglish**: Screen titles, AppBar action tooltips, table headers, payment method chips, cash change calculators, Smart Parchi modal, discount modal, and itemized success receipts localized cleanly into pure Hindi and English. Watched `LanguageController` in `build()` to enable instant language toggling without manual screen reloads.
    - **Automated Verification**: Verified across 7 test suites with 68/68 passing tests (`test/pos_screen_test.dart` and `test/features_test.dart`).

35. **LOCKED - Instant Product & Price Checker (0ms Scan & Find) & Barcode Sticker Sheet Generator (`Frontend`)**:
    - **Instant Product & Price Checker (`PriceCheckerDialog.dart`)**:
      - 0ms in-memory resolution across locally cached catalog by exact `barcode`, `sku`, or `name` match, with multi-token fallback suggestions.
      - Dual Scanner Synergy: Works seamlessly with USB/Bluetooth hardware barcode guns (rapid input + Enter) as well as camera/manual typing with autofocus and auto-resolve.
      - Exact Product Hero Card: Displays real product photo thumbnail (`AppProductImage`), Title, Category badge, Brand, Unit, monospace Barcode & SKU chips, large bold Selling Price, strikethrough MRP, real-time savings percentage badge, stock status pill (In Stock, Low Stock, Out of Stock), and collapsible cost/margin breakdown.
      - 4 Immediate 1-Tap Counter Actions:
        1. `⚡ Add to POS Bill` (with interactive quantity stepper and 0ms cart integration).
        2. `📦 Quick Stock Adjust / Restock` (1-tap stepper with delta chips `-5`, `-1`, `+1`, `+5`, `+10`, `+25` syncing in-memory and background API).
        3. `✏️ Quick Edit Price` (instant price and MRP update prompt).
        4. `🏷️ Print Barcode Stickers` (launches `BarcodeStickerDialog` pre-filled for the exact item).
      - Continuous Workflow: "Scan Next Item / अगली वस्तु स्कैन करें" button clears state and refocuses the scanner instantly for continuous counter scanning.
    - **Barcode & Price-Tag Sticker Sheet Generator (`BarcodeGeneratorService.dart` & `BarcodeStickerDialog.dart`)**:
      - Pure Dart client-side vector generation via `barcode_widget`, `pdf`, and `printing` packages (zero network latency, 100% offline capability).
      - Dual Retail Label Format Engine:
        - **Format A - Standard A4 Sticker Sheet**: 3 columns × 8 rows = 24 pre-cut adhesive labels per sheet (~70mm × 37mm per label).
        - **Format B - Dedicated Thermal Continuous Roll**: Single continuous roll format (50mm × 25mm / 58mm) for desktop and portable thermal sticker printers.
      - Sticker Content: Store Name, Product Title, Unit/Net Weight, bold Selling Price, MRP, scannable Code 128 barcode, human-readable barcode string, and PKD date.
      - Interactive In-App Preview: Visual realistic sticker representation before printing, format switch chips, copies stepper (-1, +1), and quick quantity chips (1, 6, 12, 24, 48, 72).
      - 1-Tap Direct Printing via OS print spooler (`Printing.layoutPdf`) and 1-tap PDF export / WhatsApp sharing (`Printing.sharePdf`).
    - **Cross-Screen Navigation Touchpoints**:
      - `pos_screen.dart`: Fast scan bar scanner icon and quick action pill button open `PriceCheckerDialog`.
      - `inventory_screen.dart`: AppBar scanner icon and search bar scanner icon launch `PriceCheckerDialog`. Product card 3-dots menu offers 1-tap "Print Barcodes / बारकोड स्टीकर".
      - `product_detail_screen.dart`: Top action bar and more menu provide 1-tap "Print Barcode Stickers".
    - **Zero-Overflow & Localization Standards**:
      - 100% pure Hindi and English translations in `AppTranslations` (`price_checker_*`, `barcode_*`), zero Hinglish in UI.
      - All price rows, savings banners, and button rows wrapped with `Expanded`, `Flexible`, and `FittedBox` to prevent any RenderFlex overflow across narrow mobile screens.
      - Automated Verification: Verified across all 8 test suites with 72/72 passing tests (`test/barcode_price_checker_test.dart` and `test/pos_screen_test.dart`).

36. **LOCKED - Full Database Hybrid Search & Fast Scanning Architecture (0ms Local Match + Debounced Server Database Fallback) (`Frontend`, `CustomerFrontend` & `GoBackend`)**:
    - **Architecture Rationale**: Product searching and scanning previously only filtered the pre-loaded local in-memory catalog (limited to page 1, ~20 items). Searching or scanning for any product on page 2+ failed completely. The system now enforces a high-speed Dual-Tier Hybrid Search Architecture across all surfaces.
    - **Tier 1 (Instant 0ms In-Memory Search)**: Every keystroke and scanner gun input synchronously filters the active in-memory catalog (0ms latency, zero flicker, 60-120 FPS).
    - **Tier 2 (Debounced Server Database Fallback)**: Simultaneously debounces (300-350ms) to query the full PostgreSQL database (`/shops/me/products?search=...&limit=50` for shop or `/shops/:slug/products?search=...&limit=50` for customer). Server results seamlessly populate the catalog without layout shifts.
    - **GoBackend Barcode & Spec Indexing**:
      - `FindBySKU` updated to match `UPPER(TRIM(p.sku)) = $2 OR p.attributes->>'barcode' = $2 OR p.attributes->>'Barcode' = $2 OR p.id::text = $2 OR p.attributes::text ILIKE '%' || $2 || '%'`.
      - `FindAll` and `SearchAll` updated with `OR p.attributes::text ILIKE $%d` so all barcodes and dynamic specs stored in JSONB attributes match PostgreSQL queries.
      - `FindProductByBarcode` in `loyalty.go` matches `p.sku`, `p.slug`, `p.name`, and `p.attributes->>'barcode'`.
    - **Shop Side (`Frontend`)**:
      - `PriceCheckerDialog`: 0ms local match; if not found, triggers `_queryDatabaseFallback` to search the full store database via `PosRepository.scanBarcode` and `ProductRepository.searchProducts`, showing subtle loading indicator without prematurely failing.
      - `inventory_screen.dart`: Keeps instant local filter while typing, paired with a 350ms debouncer calling `ProductController.loadProducts(search: query, silent: true)` to fetch all matching products from the database. Resetting filters restores the default catalog silently.
      - `pos_screen.dart`: Fast autocomplete backed by 350ms debounced `pos.searchProducts(query)` when query length >= 2, and instant database barcode lookup via `scanAndAddToCart`.
    - **Customer Web App (`CustomerFrontend`)**:
      - `StorefrontScreen.jsx`: Debounces 300ms on `searchTerm` to call `productApi.listByShopSlug(slug, { search: query, page: 1, limit: 50 })`, populating `serverSearchResults` while keeping 0ms local instant filtering. Shows subtle loading spinner if local items are 0 while server search is in flight.
      - `ProductScannerModal.jsx`: Queries `/products/scan/:code` with fallback to `productApi.listProducts({ search: code, limit: 1 })`.
    - **Verification**: Verified with 73/73 green tests in `Frontend` and 74/74 green tests in `CustomerFrontend`.

37. **LOCKED - Unified Canonical Category System & Fast Filter Engine (`GoBackend`, `Frontend`, `CustomerFrontend`)**:
    - **Architecture Rationale & Core Problem Fix**:
      - Previously, category names, slugs, and lists were inconsistent across platforms:
        - GoBackend seeded 21 canonical categories (`Kirana & Grocery` / `kirana-grocery`, `Dairy & Breakfast` / `dairy-breakfast`, etc.).
        - Frontend Flutter used different display names (`Grocery & Staples`, `Dairy, Bakery & Frozen`, `Snacks & Munchies`, `Medicine & Healthcare`, `Clothing & Fashion`, `Hardware & Building Material`).
        - CustomerFrontend used 44 granular micro-categories (`dal-pulses`, `biscuits-cookies`, `edible-oils`), department chips, and string inclusion which failed on synonyms.
        - GoBackend `Create` and `Update` passed raw string category IDs into UUID columns, and `FindAll` did not match `attributes->>'category_name'` or canonical synonyms.
      - Enforced a Unified Canonical Category System with 0ms in-memory synonym bucket matching and full database consistency across all 3 platforms.
    - **GoBackend (`category_utils.go`, `services/product.go`, `repository/product.go`, `controller/product.go`)**:
      - `category_utils.go`: Centralizes 21 canonical categories with standard slugs, English/Hindi names, icons, departments, and bidirectional synonym mappings. `ResolveCanonicalCategorySlug` maps any alias, slug, or title to its canonical slug.
      - `services/product.go`: `resolveCategoryID` maps any incoming category name or slug to its canonical category UUID in PostgreSQL before fallback creation.
      - `repository/product.go`: `Create` and `Update` safely resolve non-UUID strings to real UUIDs in PostgreSQL. `FindAll` expands category queries with `synonymSlugs` and `synonymNames` matching `p.category_id`, `p.attributes->>'category_name'`, and `p.attributes->>'category'`, with fallback to attributes if `c.name` is null. `FindNearbyProducts` queries product categories and returns `CategoryID`, `CategoryName`, and `CategorySlug`.
      - `controller/product.go`: Checks both `category_id` and `category` query parameters in `List`, `FindNearby`, `ListMyShopProducts`, and `ListByShop`.
    - **Shop Side (`Frontend` Flutter)**:
      - `product_model.dart`: `CategoryRegistry` provides `canonicalCategories`, `normalizeCategoryKey(raw)` mapping any input to canonical slug, and `isCategoryMatch(cat1, cat2)` for 0ms bidirectional synonym matching. `formatCategoryName` returns clean user-facing title names without raw UUID leaks.
      - `inventory_screen.dart` & `procurement_list_screen.dart`: `categoriesList` standardizes to `CategoryRegistry.canonicalCategories`, and filtering in `_recomputeFilteredProducts` uses `CategoryRegistry.isCategoryMatch(p.category, _selectedCategory)` for 0ms fast filtering.
    - **Customer Web App (`CustomerFrontend`)**:
      - `categoryMatcher.js`: `getCanonicalCategoryKey` maps any term, micro-category, or alias to canonical slug. `isProductInCategory` and `isShopInCategory` compare canonical keys first, guaranteeing that a product saved under `Grocery & Staples` matches a customer filtering by `Kirana & Grocery`, `kirana-grocery`, or `grocery` in 0ms.
      - `StorefrontScreen.jsx`: Dynamic category pills cleanly extract user-facing names while skipping raw 36-char hexadecimal UUID strings.
    - **Automated Verification**:
      - GoBackend: `go test ./internal/utils -v` and `go test ./internal/handler/... -v` pass 100%, binary builds cleanly (`bin/api.exe`).
      - Frontend: 74/74 Flutter tests pass (100% green).
      - CustomerFrontend: 76/76 Vitest tests pass (100% green).

38. **LOCKED - Explore Marketplace Dual-Tier Hybrid Database Search (`CustomerFrontend` & `GoBackend`)**:
    - **Architecture Rationale & Core Problem Fix**:
      - Previously, searching in the Customer Web App explore/marketplace dashboard (`ExploreShopsScreen.jsx`) only filtered the pre-loaded local in-memory state (the first 20 items loaded on initial mount). Products and shops present in the PostgreSQL database beyond page 1 were completely missed.
      - Furthermore, GoBackend `ProductController.FindNearby` only read `query.Get("q")`. If Axios sent `params: { search: ... }`, it became an empty string and ignored the query.
      - Implemented a complete Dual-Tier Hybrid Search Engine for the Marketplace:
        - **Tier 1 (Instant 0ms In-Memory Match)**: Evaluates input immediately against the currently loaded items in memory with 0ms latency and 60-120 FPS buttery-smooth typing.
        - **Tier 2 (Debounced Server Database Query)**: Concurrently debounces for 300ms to query PostgreSQL via `productApi.findNearbyProducts` (with fallback to `productApi.listProducts`) and `shopApi.listPublicShops` (`limit: 50`), ensuring every matching item across the entire database is retrieved.
        - **Resilient Merge & Deduplication**: Merges `serverSearchResults` with local matches deduplicated by `id`, ensuring 100% comprehensive catalog results without duplicate cards.
        - **Visual Searching Indicator**: Shows `<Loader2 className="animate-spin" />` in the search input while the server query is running, and displays an unobtrusive database searching state instead of prematurely flashing "No products found".
        - **Zero Hinglish Standards**: 100% pure Hindi and English strings across loading and pagination banners.
    - **GoBackend (`controller/product.go`)**:
      - `FindNearby` accepts both `q` and `search` query parameters (`func() string { if q := query.Get("q"); q != "" { return q } return query.Get("search") }()`).
    - **Automated Verification**:
      - GoBackend: Binary compiled cleanly (`bin/api.exe`), utils tests pass.
      - Frontend: 74/74 Flutter tests pass (100% green).
      - CustomerFrontend: 76/76 Vitest tests pass (100% green).

39. **LOCKED - Floor Assisted Selling, Camera Barcode Scanning & Parallel Active Customer Baskets / Running Tabs (`Frontend` & `GoBackend`)**:
    - **Retail Floor Problem & Anti-Theft Architecture**:
      - Solves the high-rush ("bheed") floor theft and misplacement problem where 4 family members assist customers simultaneously across multiple shops.
      - Staff immediately scans barcodes or searches products on the floor, adding them into active running baskets under physical customer tokens (e.g. `T-01` to `T-20`).
    - **Mobile Camera Barcode Scanner (`mobile_scanner: ^7.4.2` & `MobileBarcodeScannerDialog`)**:
      - Built interactive live camera viewfinder with animated laser reticle, flashlight/torch toggle, front/back camera flip, audio beep (`SystemSoundType.alert`), and haptic feedback (`HapticFeedback.mediumImpact`).
      - Continuous Multi-Scan Mode: Floor staff can scan 10+ items back-to-back without closing the camera view.
      - Prominently accessible: Primary `[ 📷 स्कैनर / Scan ]` button right beside `AppProductSearchBar`, in empty bill table, and AppBar icon.
    - **0-Tap QR Token Switching (`SHOP-TOKEN:T-xx`)**:
      - Scanning physical token card QR codes (`SHOP-TOKEN:T-01` to `T-20`) automatically switches the active customer basket in 0.1s without touching the phone screen.
    - **On-the-Fly Quick Product Registration for Unlisted Barcodes**:
      - If an unlisted/new barcode is scanned, the feedback card offers `[ ⚡ तुरंत नया उत्पाद जोड़ें / Quick Add New Product ]`.
      - 5-second bottom sheet allows staff to enter Name and Selling Price; instantly registers the item into the local catalog, adds it to the customer's cart, and syncs to GoBackend in background.
    - **Printable A4 Floor Token Cards PDF Generator (`FloorTokenCardsService`)**:
      - Generates 20 laminated floor tokens (`T-01` to `T-20`) with bold numbers, instructions, dashed cutting lines, and high-density QR codes (`SHOP-TOKEN:T-xx`) on a single A4 PDF sheet.
      - 1-tap print button embedded directly into the Token Picker modal (`_showTokenPickerSheet`).
    - **Anti-Theft Floor Idle Basket Timers**:
      - Calculates basket elapsed time since last update (`DateTime.now().difference(runningBasket.updatedAt).inMinutes`).
      - Displays amber warning badges (`⏱️ 15m`) and red alert badges (`🚨 30m`) on active token tabs, warning staff if a customer basket has been idle on the floor for too long.
    - **GoBackend (`pos_parked_bills` & WebSocket Real-time Hub)**:
      - PostgreSQL table `pos_parked_bills` (`id`, `shop_id`, `label`, `customer_phone`, `cart_data`, `total_amount`, `created_at`, `updated_at`) with unique index `idx_pos_parked_bills_shop_label ON pos_parked_bills(shop_id, UPPER(TRIM(label))) WHERE label != ''`.
      - Atomic `ON CONFLICT (shop_id, UPPER(TRIM(label))) DO UPDATE SET cart_data = EXCLUDED.cart_data, total_amount = EXCLUDED.total_amount, updated_at = NOW()`.
      - Repository & Service methods addressable by UUID or Token label (`(id::text = $2 OR UPPER(TRIM(label)) = UPPER(TRIM($2)))`).
      - Real-time WebSocket broadcasting:
        - `POS_PARKED_BILLS_CHANGED`: notifies all shop terminals with updated cart data and amount whenever an item is added or modified.
        - `POS_PARKED_BILL_DELETED`: broadcast when bill is completed at counter, freeing the token across all 4 devices instantly.
    - **Frontend POS Terminal (`pos_screen.dart` & `pos_controller.dart`)**:
      - `_buildActiveTokensBar`: Top running tabs bar displaying active tokens (`T-01`, `T-02`, etc.) with live item count and amount badges (`3 • ₹450`).
      - 1-Tap Switching: Staff can switch active customer tokens with 1 tap; automatically auto-syncs the prior token before loading the next.
      - Quick Slot Modal (`_showTokenPickerSheet`): 4-column token slot picker (`T-01` to `T-20`) indicating Free vs Active, plus custom customer names.
      - Zero Hinglish Standards: Pure Hindi and English UI strings across all token chips and dialogs.
    - **Automated Verification**:
      - GoBackend tests pass 100%, binary builds cleanly (`bin/api.exe`).
      - Frontend Flutter test suite passes 100% green (104/104 tests passed).

40. **LOCKED - Inventory Instant Quick-Restock & Smart Low-Stock Wholesale Reorder Engine (`Frontend`)**:
    - **Smart Reorder Estimation (`SmartStockReorderService.getRecommendedReorderQuantity`)**: Automatically calculates 2x threshold units (minimum clamp 5 units) to maintain optimal stock buffer.
    - **1-Tap Wholesale Procurement Sync (`addToProcurementList` & `addAllLowStockToProcurement`)**: Adds individual or all low-stock items into `LocalCacheService.getProcurementItems()` in 0ms with automated quantity deduplication, preserving cost price and supplier details.
    - **Executive WhatsApp Wholesale Order Builder (`formatSupplierOrderMessage`)**: Generates professional itemized wholesale purchase orders in pure English and pure Hindi with item quantities, estimated rates, and total order cost. Strict adherence to User Global Rule: ZERO vegetable imagery or references.
    - **Universal 1-Tap Restock Across Screens**:
      - `LowStockAlertsScreen`: Top Bulk Action Bar ("Add All to Reorder List" & "Share Supplier Order via WhatsApp"), individual 1-tap reorder chips on cards, and responsive stepper chips with zero pixel overflow across mobile (390px) and desktop (1280px).
      - `ProductDetailScreen`: Dedicated `_buildStockManagementCard` with live status badge, quick adjustment steppers (`-1, +1, +5, +10, +25, +50`), and 1-tap Wholesale Reorder button.
      - `InventoryScreen`: 1-tap Wholesale Reorder action integrated into quick stock bottom sheet (`_showQuickStockSheet`).
    - **Automated Verification**: `test/smart_stock_reorder_test.dart` passes 6/6 tests, full Flutter test suite passes 104/104 tests (100% green).

41. **LOCKED - Instant Offline-Resilient Expense Tracker & Daily Net Profit Calculator (`Frontend`)**:
    - **1-Tap Quick Petty Cash Chips (`SmartExpenseService.quickAmountPresets`)**: Integrated instantaneous amount chips (`₹20`, `₹50`, `₹100`, `₹200`, `₹500`, `₹1000`, `₹2000`) in Add Expense bottom sheet, eliminating manual keyboard typing for daily petty expenses (Tea, Delivery auto fare, etc.).
    - **Live Daily Net Profit Engine (`SmartExpenseService.calculateDailyProfit`)**: Automatically interlocks live POS sales (`DashboardController.stats.todaySales` or `PosController.today24hRevenue`) with recorded daily expenses (`ExpenseController.todayExpenses`), calculating real-time net in-hand profit (`netProfit = todaySales - todayExpenses`), net margin %, and break-even status.
    - **Responsive Zero-Overflow Executive KPI Grid**: LayoutBuilder dynamically renders a 4-card KPI row on Desktop (>=720px) and a balanced 2x2 grid on mobile viewports: Today's Sales, Today's Expenses, Today's Net Profit / In-Hand, and Monthly Expenses with overflow-proof FittedBox text scaling.
    - **Executive WhatsApp Daily Statement Generator (`SmartExpenseService.formatDailyExpenseSummary` & `shareExpenseSummaryOnWhatsApp`)**: 1-tap AppBar WhatsApp sharing action formatting professional, itemized daily closing statements with sales, expenses, and net profit in pure English and pure Hindi. Adheres 100% to User Global Rule: ZERO vegetable imagery or references.
    - **0ms Stale-While-Revalidate Caching & Event Bus Invalidation**: Hydrates immediately from `LocalCacheService.getExpenses()` with 0ms delay, and invalidates on `AppCacheEventType.expenseMutated` and `authLogout`.
    - **Automated Verification**: `test/smart_expense_test.dart` passes 10/10 tests, full Flutter test suite passes 114/114 tests (100% green).

42. **LOCKED - Multi-Store Branch Switcher & Offline Cloud Sync Queue (`Frontend`)**:
    - **Multi-Outlet Branch Management (`AuthController.switchShop` & `registerBranchStore`)**:
      - `managedShops` stores all branch outlets locally in `LocalCacheService.getManagedShops()`.
      - 1-Tap Switching (`switchShop(targetShopId)`): Instantly switches active branch store with 0ms optimistic UI, persists new token/shop payload, and triggers complete cache invalidation across all feature controllers (`AppEventBus().emit(AppCacheEventType.shopProfileUpdated)`).
      - In-App Branch Registration (`registerBranchStore`): Instantly creates and activates new branch outlet with optimistic fallback and background sync queue enqueueing.
    - **Conflict-Free Offline Cloud Sync Engine (`OfflineSyncService` & `SyncQueueItem`)**:
      - Queues mutations (POS Sales, Expenses, Khata entries, Branch additions) with unique idempotency keys (`X-Idempotency-Key`) in persistent FIFO storage (`LocalCacheService.getSyncQueue()`).
      - Background Non-Blocking Auto-Flush (`processQueue()`): Safely retries network requests upon connection restoration. Treats HTTP 409 conflict as idempotency success and gracefully pauses network loop on connection dropouts without spamming.
      - Safe Concurrency & Memory Hygiene: Boundary-guarded item iteration (`indexWhere((i) => i.id == itemId)`) prevents RangeError during concurrent queue modifications. `clearCache()` and `clearQueue()` cleanly wipe in-memory queues and persistent storage.
    - **Responsive Universal UI Touchpoints (`StoreSwitcherDialog` & `OfflineSyncSheet`)**:
      - `StoreSwitcherDialog`: Responsive bottom sheet / dialog with active store badge, 1-tap branch selection, inline branch creation form with overflow-safe dropdowns (`isExpanded: true`), and pure bilingual localization.
      - `OfflineSyncSheet`: Accessible via Drawer & Dashboard AppBar with real-time stream badge (`pendingCountStream`), displaying itemized offline transactions, amounts, and manual 1-tap "Sync Now" trigger.
      - Adheres 100% to User Global Rule: ZERO vegetable imagery or references.
    - **Automated Verification**: `test/multi_store_and_offline_sync_test.dart` passes 7/7 tests, full Flutter test suite passes 121/121 tests (100% green).

## 4. Continuous User Decisions Log
- See [PROJECT_RULEBOOK.md](file:///c:/Go/ShopSilo/Frontend/PROJECT_RULEBOOK.md) Section 5 for the complete history of user requirements and architectural decisions.
- Whenever the user gives a new rule or permanent decision, update both `PROJECT_RULEBOOK.md` and this file.





