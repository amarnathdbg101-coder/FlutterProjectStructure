import 'language_controller.dart';

class AppTranslations {
  static const Map<String, Map<String, String>> _keys = {
    // Navigation / Shell
    'nav_home': {
      'en': 'Dashboard',
      'hi': 'डैशबोर्ड',
    },
    'nav_billing': {
      'en': 'POS Billing',
      'hi': 'काउंटर बिलिंग',
    },
    'nav_inventory': {
      'en': 'Inventory',
      'hi': 'इन्वेंटरी स्टॉक',
    },
    'nav_khata': {
      'en': 'Credit',
      'hi': 'उधार',
    },
    'nav_expenses': {
      'en': 'Expenses',
      'hi': 'दुकान ख़र्चे',
    },
    'nav_settings': {
      'en': 'Store Settings',
      'hi': 'स्टोर सेटिंग्स',
    },

    // Language Settings
    'settings_language_title': {
      'en': 'App Language',
      'hi': 'ऐप की भाषा',
    },
    'settings_language_subtitle': {
      'en': 'Choose between English and Hindi',
      'hi': 'अंग्रेज़ी या हिन्दी में से चुनें',
    },
    'lang_english': {
      'en': 'English',
      'hi': 'English',
    },
    'lang_english_sub': {
      'en': 'Default language',
      'hi': 'डिफ़ॉल्ट भाषा',
    },
    'lang_hindi': {
      'en': 'हिन्दी (Hindi)',
      'hi': 'हिन्दी',
    },
    'lang_hindi_sub': {
      'en': 'Use app in Hindi',
      'hi': 'ऐप को हिन्दी में चलाएं',
    },
    'lang_updated_toast': {
      'en': 'Language changed to English',
      'hi': 'भाषा बदलकर हिन्दी कर दी गई है',
    },

    // Theme Settings
    'settings_theme_title': {
      'en': 'App Theme',
      'hi': 'ऐप थीम',
    },
    'settings_theme_subtitle': {
      'en': 'Choose Light, Dark, or System mode',
      'hi': 'लाइट, डार्क या सिस्टम मोड चुनें',
    },
    'theme_light': {
      'en': 'Light Mode',
      'hi': 'लाइट मोड',
    },
    'theme_light_sub': {
      'en': 'Classic clean appearance',
      'hi': 'साफ़ और उज्ज्वल रूप',
    },
    'theme_dark': {
      'en': 'Dark Mode',
      'hi': 'डार्क मोड',
    },
    'theme_dark_sub': {
      'en': 'Relaxing for eyes at night',
      'hi': 'रात में आँखों के लिए आरामदायक',
    },
    'theme_system': {
      'en': 'System Default',
      'hi': 'सिस्टम डिफ़ॉल्ट',
    },
    'theme_system_sub': {
      'en': 'Follows device theme settings',
      'hi': 'डिवाइस की सेटिंग अनुसार',
    },
    'theme_updated_toast': {
      'en': 'Theme updated successfully',
      'hi': 'थीम सफलतापूर्वक बदल दी गई है',
    },

    // Commercial & Profit Margins Visibility
    'settings_profit_margins_title': {
      'en': 'Show Profit & Cost Margins',
      'hi': 'उत्पाद मुनाफ़ा और लागत मार्जिन दिखाएं',
    },
    'settings_profit_margins_subtitle': {
      'en': 'Display purchase price and profit hubs in products. Turn off for customer-safe counter view.',
      'hi': 'उत्पादों में खरीद मूल्य और लाभ मार्जिन दिखाएं। ग्राहकों के सामने काउंटर मोड के लिए इसे बंद करें।',
    },

    // Common Buttons & Actions
    'btn_save': {
      'en': 'Save',
      'hi': 'सहेजें',
    },
    'btn_cancel': {
      'en': 'Cancel',
      'hi': 'रद्द करें',
    },
    'btn_close': {
      'en': 'Close',
      'hi': 'बंद करें',
    },
    'btn_copy': {
      'en': 'Copy',
      'hi': 'कॉपी करें',
    },
    'btn_edit': {
      'en': 'Edit',
      'hi': 'संपादित करें',
    },
    'btn_updating': {
      'en': 'Saving...',
      'hi': 'सहेजा जा रहा है...',
    },
    'btn_logout': {
      'en': 'Logout from Account',
      'hi': 'खाते से लॉगआउट करें',
    },
    'btn_back': {
      'en': 'Back',
      'hi': 'वापस',
    },

    // Store Profile & Settings (Strict Hindi & English)
    'profile_title': {
      'en': 'Store Profile & Settings',
      'hi': 'दुकान प्रोफाइल एवं सेटिंग्स',
    },
    'profile_store_info_section': {
      'en': 'Store Details',
      'hi': 'दुकान का विवरण',
    },
    'profile_owner_section': {
      'en': 'Owner Information',
      'hi': 'मालिक की जानकारी',
    },
    'profile_edit_store': {
      'en': 'Edit Store Details',
      'hi': 'दुकान विवरण बदलें',
    },
    'profile_edit_owner': {
      'en': 'Edit Owner Profile',
      'hi': 'मालिक प्रोफाइल बदलें',
    },
    'profile_timings_section': {
      'en': 'Operating Timings & Payment',
      'hi': 'खुलने का समय एवं भुगतान',
    },
    'profile_store_name': {
      'en': 'Store Name',
      'hi': 'दुकान का नाम',
    },
    'profile_store_category': {
      'en': 'Store Category',
      'hi': 'दुकान की श्रेणी',
    },
    'profile_store_address': {
      'en': 'Store Address',
      'hi': 'दुकान का पता',
    },
    'profile_store_city': {
      'en': 'City',
      'hi': 'शहर',
    },
    'profile_store_pincode': {
      'en': 'Pincode',
      'hi': 'पिनकोड',
    },
    'profile_store_phone': {
      'en': 'Contact Phone',
      'hi': 'संपर्क फ़ोन',
    },
    'profile_store_whatsapp': {
      'en': 'WhatsApp Number',
      'hi': 'व्हाट्सएप नंबर',
    },
    'profile_store_description': {
      'en': 'Store Description',
      'hi': 'दुकान का विवरण',
    },
    'profile_store_upi': {
      'en': 'UPI ID (VPA for QR)',
      'hi': 'यूपीआई आईडी (क्यूआर हेतु वीपीए)',
    },
    'profile_opening_time': {
      'en': 'Opening Time',
      'hi': 'खुलने का समय',
    },
    'profile_closing_time': {
      'en': 'Closing Time',
      'hi': 'बंद होने का समय',
    },
    'profile_weekly_off': {
      'en': 'Weekly Holiday',
      'hi': 'साप्ताहिक अवकाश',
    },
    'profile_status_open': {
      'en': 'Store Open',
      'hi': 'दुकान खुली है',
    },
    'profile_status_closed': {
      'en': 'Store Closed',
      'hi': 'दुकान बंद है',
    },
    'profile_status_toggle_hint': {
      'en': 'Toggle to show whether your store is accepting customers',
      'hi': 'ग्राहक स्वीकार करने हेतु स्थिति बदलें',
    },
    'profile_owner_name': {
      'en': 'Owner Full Name',
      'hi': 'मालिक का पूरा नाम',
    },
    'profile_owner_email': {
      'en': 'Email Address',
      'hi': 'ईमेल पता',
    },
    'profile_owner_phone': {
      'en': 'Owner Phone',
      'hi': 'मालिक का फ़ोन',
    },
    'profile_storefront_link': {
      'en': 'Online Storefront & QR Standee',
      'hi': 'ऑनलाइन दुकान लिंक एवं क्यूआर स्टैंडी',
    },
    'profile_storefront_help': {
      'en': 'Scan QR to view digital catalog & send order directly to your counter',
      'hi': 'डिजिटल कैटलॉग देखने और काउंटर पर ऑर्डर भेजने के लिए स्कैन करें',
    },
    'profile_link_copied': {
      'en': 'Storefront link copied to clipboard',
      'hi': 'दुकान का लिंक कॉपी हो गया है',
    },
    'profile_cashier_title': {
      'en': 'Cashier Terminal Mode',
      'hi': 'कैशियर टर्मिनल मोड',
    },
    'profile_cashier_sub': {
      'en': 'Switch to staff billing session with 4-digit PIN',
      'hi': '4-अंकीय पिन से स्टाफ बिलिंग सत्र में स्विच करें',
    },
    'profile_cashier_btn': {
      'en': 'Open Cashier Terminal',
      'hi': 'कैशियर टर्मिनल खोलें',
    },
    'profile_store_updated': {
      'en': 'Store details updated successfully!',
      'hi': 'दुकान का विवरण सफलतापूर्वक अपडेट हो गया!',
    },
    'profile_owner_updated': {
      'en': 'Owner profile updated successfully!',
      'hi': 'मालिक प्रोफाइल सफलतापूर्वक अपडेट हो गया!',
    },
    'profile_status_updated': {
      'en': 'Store status updated',
      'hi': 'दुकान की स्थिति अपडेट हो गई',
    },
    'profile_rating_label': {
      'en': 'Customer Rating',
      'hi': 'ग्राहक रेटिंग',
    },
    'profile_active_badge': {
      'en': 'Verified Merchant',
      'hi': 'सत्यापित दुकानदार',
    },
    'profile_store_logo': {
      'en': 'Store Logo',
      'hi': 'दुकान का लोगो',
    },
    'profile_owner_photo': {
      'en': 'Owner Profile Photo',
      'hi': 'दुकानदार प्रोफाइल फोटो',
    },
    'profile_upload_logo': {
      'en': 'Upload Store Logo',
      'hi': 'दुकान का लोगो अपलोड करें',
    },
    'profile_upload_avatar': {
      'en': 'Upload Profile Photo',
      'hi': 'प्रोफाइल फोटो अपलोड करें',
    },
    'profile_change_photo': {
      'en': 'Change Photo',
      'hi': 'फोटो बदलें',
    },
    'profile_choose_gallery': {
      'en': 'Choose from Gallery',
      'hi': 'गैलरी से चुनें',
    },
    'profile_take_camera': {
      'en': 'Take Photo with Camera',
      'hi': 'कैमरे से फोटो लें',
    },
    'profile_uploading_photo': {
      'en': 'Uploading photo...',
      'hi': 'फोटो अपलोड हो रही है...',
    },
    'profile_photo_updated': {
      'en': 'Photo updated successfully',
      'hi': 'फोटो सफलतापूर्वक अपडेट हो गई',
    },
    'profile_photo_error': {
      'en': 'Failed to upload photo',
      'hi': 'फोटो अपलोड करने में विफल',
    },

    // Auth - Login
    'login_title': {
      'en': 'Merchant Login',
      'hi': 'दुकानदार लॉगिन',
    },
    'login_subtitle': {
      'en': 'ShopSilo Partner - Store Billing & Inventory Management',
      'hi': 'शॉपसिलो पार्टनर - बिलिंग एवं इन्वेंटरी प्रबंधन',
    },
    'login_email_label': {
      'en': 'Email or Mobile Number',
      'hi': 'ईमेल या मोबाइल नंबर',
    },
    'login_email_hint': {
      'en': 'e.g. 9876543210 or your@email.com',
      'hi': 'उदा. 9876543210 या aapka@email.com',
    },
    'login_password_label': {
      'en': 'Password',
      'hi': 'पासवर्ड',
    },
    'login_btn_submit': {
      'en': 'Sign In',
      'hi': 'लॉगिन करें',
    },
    'login_staff_btn': {
      'en': 'Cashier 4-Digit PIN Terminal',
      'hi': 'कैशियर 4-अंकीय पिन टर्मिनल',
    },
    'login_staff_btn_sub': {
      'en': 'Fast counter sales & checkout access',
      'hi': 'तेज़ काउंटर बिक्री और बिलिंग टर्मिनल',
    },
    'login_divider_or': {
      'en': 'OR',
      'hi': 'या',
    },
    'login_badge_merchant': {
      'en': 'STORE OWNER PORTAL',
      'hi': 'दुकानदार पोर्टल',
    },
    'login_new_account_prompt': {
      'en': 'Need a new merchant account? ',
      'hi': 'नया खाता बनाना चाहते हैं? ',
    },
    'login_register_link': {
      'en': 'Register Store',
      'hi': 'दुकान पंजीकृत करें',
    },

    // Auth - Register
    'register_title': {
      'en': 'Register Your Store',
      'hi': 'अपनी दुकान पंजीकृत करें',
    },
    'register_subtitle': {
      'en': 'Digitize and manage your retail business in 2 minutes',
      'hi': 'अपनी दुकान को 2 मिनट में डिजिटल बनाएं',
    },
    'register_name_label': {
      'en': 'Full Name / Owner Name',
      'hi': 'पूरा नाम / दुकानदार का नाम',
    },
    'register_name_hint': {
      'en': 'e.g. Ramesh Kumar',
      'hi': 'उदा. रमेश कुमार',
    },
    'register_phone_label': {
      'en': 'Mobile Phone Number',
      'hi': 'मोबाइल नंबर',
    },
    'register_phone_hint': {
      'en': 'e.g. 9876543210',
      'hi': 'उदा. 9876543210',
    },
    'register_email_label': {
      'en': 'Email Address',
      'hi': 'ईमेल पता',
    },
    'register_email_hint': {
      'en': 'merchant@shopsilo.in',
      'hi': 'merchant@shopsilo.in',
    },
    'register_password_label': {
      'en': 'Password',
      'hi': 'पासवर्ड',
    },
    'register_password_hint': {
      'en': 'Minimum 6 characters',
      'hi': 'कम से कम 6 अक्षर',
    },
    'register_btn_submit': {
      'en': 'Register & Start Store',
      'hi': 'पंजीकृत करें और दुकान शुरू करें',
    },
    'register_existing_prompt': {
      'en': 'Already have an account? ',
      'hi': 'क्या आपका पहले से खाता है? ',
    },
    'register_login_link': {
      'en': 'Sign In',
      'hi': 'लॉगिन करें',
    },

    // Form Validations
    'val_name_required': {
      'en': 'Please enter full name',
      'hi': 'कृपया पूरा नाम दर्ज करें',
    },
    'val_phone_required': {
      'en': 'Please enter valid 10-digit mobile number',
      'hi': 'कृपया वैध 10-अंकों का मोबाइल नंबर दर्ज करें',
    },
    'val_email_required': {
      'en': 'Please enter email or mobile number',
      'hi': 'कृपया ईमेल या मोबाइल नंबर दर्ज करें',
    },
    'val_email_invalid': {
      'en': 'Please enter a valid email or 10-digit mobile number',
      'hi': 'कृपया मान्य ईमेल या 10-अंकों का मोबाइल नंबर दर्ज करें',
    },
    'val_password_required': {
      'en': 'Please enter password',
      'hi': 'कृपया पासवर्ड दर्ज करें',
    },
    'val_password_short': {
      'en': 'Password must be at least 6 characters',
      'hi': 'पासवर्ड कम से कम 6 अक्षरों का होना चाहिए',
    },

    // Dashboard
    'dash_store_qr_tooltip': {
      'en': 'View Customer QR Standee',
      'hi': 'ग्राहक क्यूआर कोड देखें',
    },
    'dash_status_open': {
      'en': 'Store is Open (Accepting Orders)',
      'hi': 'दुकान खुली है (ऑनलाइन)',
    },
    'dash_status_closed': {
      'en': 'Store is Closed (Offline)',
      'hi': 'दुकान बंद है (ऑफ़लाइन)',
    },
    'dash_section_summary': {
      'en': "Today's Business Summary",
      'hi': 'आज का व्यापार सारांश',
    },
    'dash_kpi_sales': {
      'en': "Today's Sales",
      'hi': 'आज की बिक्री',
    },
    'dash_kpi_bills': {
      'en': 'Bills Generated',
      'hi': 'कुल बिल',
    },
    'dash_kpi_udhar': {
      'en': 'Market Credit (Udhar)',
      'hi': 'बाज़ार बकाया उधार',
    },
    'dash_kpi_debtors': {
      'en': 'Debtor Customers',
      'hi': 'उधारी ग्राहक',
    },
    'dash_kpi_catalog': {
      'en': 'Active Products',
      'hi': 'सक्रिय उत्पाद',
    },
    'dash_kpi_low_stock': {
      'en': 'Low Stock Alert',
      'hi': 'कम स्टॉक अलर्ट',
    },
    'dash_kpi_reorder_needed': {
      'en': 'Items need restock',
      'hi': 'पुनर्प्राप्ति आवश्यक सामान',
    },
    'dash_section_actions': {
      'en': 'Quick Actions',
      'hi': 'त्वरित कार्य',
    },
    'dash_action_pos': {
      'en': 'POS Billing',
      'hi': 'काउंटर बिलिंग',
    },
    'dash_action_pos_sub': {
      'en': 'Generate customer receipt',
      'hi': 'नया ग्राहक बिल बनाएं',
    },
    'dash_action_product': {
      'en': 'Add Product',
      'hi': 'उत्पाद जोड़ें',
    },
    'dash_action_product_sub': {
      'en': 'Add to inventory stock',
      'hi': 'स्टॉक में नया सामान जोड़ें',
    },
    'dash_action_khata': {
      'en': 'Credit Ledger',
      'hi': 'उधार खाता',
    },
    'dash_action_khata_sub': {
      'en': 'Customer credit ledger',
      'hi': 'ग्राहक उधारी विवरण',
    },
    'dash_action_expense': {
      'en': 'Store Expenses',
      'hi': 'दुकान ख़र्चे',
    },
    'dash_action_expense_sub': {
      'en': 'Record daily operational costs',
      'hi': 'दैनिक ख़र्च दर्ज करें',
    },
    'dash_dialog_qr_title': {
      'en': 'Digital Storefront QR',
      'hi': 'डिजिटल स्टोर क्यूआर',
    },
    'dash_dialog_qr_sub': {
      'en': 'Customers can scan this to view your active price list and products',
      'hi': 'ग्राहक इसे स्कैन करके आपकी मूल्य सूची और उत्पाद देख सकते हैं',
    },

    'staff_owner_login': {
      'en': 'Owner Password Login',
      'hi': 'मालिक पासवर्ड लॉगिन',
    },

    // Customer Public Storefront
    'storefront_customer_view': {
      'en': 'Customer Storefront',
      'hi': 'ग्राहक स्टोर',
    },
    'storefront_order_whatsapp': {
      'en': 'Order on WhatsApp',
      'hi': 'व्हाट्सएप पर ऑर्डर करें',
    },
    'storefront_call_shop': {
      'en': 'Call Store',
      'hi': 'दुकान पर कॉल करें',
    },
    'storefront_pay_upi': {
      'en': 'Pay with UPI',
      'hi': 'यूपीआई भुगतान',
    },
    'storefront_search_hint': {
      'en': 'Search products in this store...',
      'hi': 'इस दुकान के उत्पाद खोजें...',
    },
    'storefront_no_products': {
      'en': 'No products listed yet',
      'hi': 'अभी कोई उत्पाद उपलब्ध नहीं है',
    },
    'storefront_order_prompt': {
      'en': 'Contact store directly to place your order',
      'hi': 'ऑर्डर करने के लिए सीधे दुकानदार से संपर्क करें',
    },
    'storefront_qr_dialog_scan': {
      'en': 'Scan to view digital catalog & send order directly to store',
      'hi': 'डिजिटल कैटलॉग देखने और सीधे ऑर्डर करने के लिए स्कैन करें',
    },
    'storefront_preview_btn': {
      'en': 'Preview Customer Store',
      'hi': 'ग्राहक स्टोर देखें',
    },
    'storefront_share_btn': {
      'en': 'Share Store',
      'hi': 'दुकान शेयर करें',
    },

    // POS Counter Billing
    'pos_title': {
      'en': 'POS Counter Billing',
      'hi': 'काउंटर बिलिंग',
    },
    'pos_search_hint': {
      'en': 'Search product name or barcode...',
      'hi': 'उत्पाद का नाम या बारकोड खोजें...',
    },
    'pos_empty_products': {
      'en': 'No products found. Search or add a new product.',
      'hi': 'कोई उत्पाद नहीं मिला। खोजें या नया उत्पाद जोड़ें।',
    },
    'pos_clear_cart_tooltip': {
      'en': 'Clear Cart',
      'hi': 'कार्ट खाली करें',
    },
    'pos_items_count': {
      'en': 'Items',
      'hi': 'सामान',
    },
    'pos_btn_checkout': {
      'en': 'Proceed to Checkout',
      'hi': 'चेकआउट करें',
    },
    'pos_cart_heading': {
      'en': 'Current Bill Items',
      'hi': 'वर्तमान बिल विवरण',
    },
    'pos_cart_empty': {
      'en': 'Cart is empty. Tap a product to add.',
      'hi': 'कार्ट खाली है। उत्पाद जोड़ने के लिए टैप करें।',
    },
    'pos_subtotal': {
      'en': 'Subtotal',
      'hi': 'उप-कुल',
    },
    'pos_discount': {
      'en': 'Discount',
      'hi': 'छूट',
    },
    'pos_grand_total': {
      'en': 'Grand Total',
      'hi': 'कुल राशि',
    },
    'pos_dialog_checkout_title': {
      'en': 'Counter Checkout',
      'hi': 'काउंटर चेकआउट',
    },
    'pos_customer_phone_label': {
      'en': 'Customer Mobile (Required for Udhar)',
      'hi': 'ग्राहक मोबाइल नंबर (उधार के लिए आवश्यक)',
    },
    'pos_customer_phone_hint': {
      'en': 'e.g. 9876543210',
      'hi': 'उदा. 9876543210',
    },
    'pos_payment_mode_label': {
      'en': 'Select Payment Mode',
      'hi': 'भुगतान का माध्यम चुनें',
    },
    'pos_payment_cash': {
      'en': 'Cash',
      'hi': 'नकद',
    },
    'pos_payment_upi': {
      'en': 'UPI QR',
      'hi': 'यूपीआई क्यूआर',
    },
    'pos_payment_khata': {
      'en': 'Store Credit',
      'hi': 'उधार खाता',
    },
    'pos_complete_sale': {
      'en': 'Complete Bill',
      'hi': 'बिल पूरा करें',
    },
    'pos_bill_success_title': {
      'en': 'Bill Created Successfully!',
      'hi': 'बिल सफलतापूर्वक बन गया!',
    },
    'pos_bill_number': {
      'en': 'Bill #',
      'hi': 'बिल संख्या #',
    },
    'pos_next_bill_btn': {
      'en': 'Create Next Bill',
      'hi': 'अगला बिल बनाएं',
    },

    // Inventory & Catalog
    'inv_title': {
      'en': 'Active Products',
      'hi': 'एक्टिव प्रोडक्ट्स (Active Products)',
    },
    'inv_search_hint': {
      'en': 'Search product name or barcode...',
      'hi': 'उत्पाद का नाम या बारकोड खोजें...',
    },
    'inv_add_btn': {
      'en': 'Add Product',
      'hi': 'उत्पाद जोड़ें',
    },
    'inv_refresh_tooltip': {
      'en': 'Refresh Catalog',
      'hi': 'कैटलॉग रीफ्रेश करें',
    },
    'inv_empty_title': {
      'en': 'No products found',
      'hi': 'कोई उत्पाद नहीं मिला',
    },
    'inv_add_dialog_title': {
      'en': 'Add New Product',
      'hi': 'नया उत्पाद जोड़ें',
    },
    'inv_field_name': {
      'en': 'Product Name *',
      'hi': 'उत्पाद का नाम *',
    },
    'inv_field_name_hint': {
      'en': 'e.g. Aashirvaad Atta 5kg',
      'hi': 'उदा. आशीर्वाद आटा 5 किग्रा',
    },
    'inv_field_selling_price': {
      'en': 'Selling Price (₹) *',
      'hi': 'बिक्री मूल्य (₹) *',
    },
    'inv_field_cost_price': {
      'en': 'Purchase Cost (₹)',
      'hi': 'खरीद मूल्य (₹)',
    },
    'inv_field_stock': {
      'en': 'Stock Quantity *',
      'hi': 'स्टॉक मात्रा *',
    },
    'inv_field_unit': {
      'en': 'Unit',
      'hi': 'इकाई',
    },
    'inv_field_category': {
      'en': 'Category',
      'hi': 'श्रेणी',
    },
    'inv_field_category_hint': {
      'en': 'e.g. Grocery / Snacks',
      'hi': 'उदा. किराना / स्नैक्स',
    },
    'inv_field_barcode': {
      'en': 'Barcode / SKU (Optional)',
      'hi': 'बारकोड / SKU (वैकल्पिक)',
    },
    'inv_unit_piece': {
      'en': 'Piece',
      'hi': 'नग (Piece)',
    },
    'inv_unit_kg': {
      'en': 'Kg',
      'hi': 'किलो (Kg)',
    },
    'inv_unit_gm': {
      'en': 'Gram',
      'hi': 'ग्राम (Gm)',
    },
    'inv_unit_litre': {
      'en': 'Litre',
      'hi': 'लीटर (Litre)',
    },
    'inv_unit_packet': {
      'en': 'Packet',
      'hi': 'पैकेट (Packet)',
    },
    'inv_val_required': {
      'en': 'Please fill required fields (Name, Price, Stock)',
      'hi': 'कृपया आवश्यक फ़ील्ड भरें (नाम, मूल्य, स्टॉक)',
    },
    'inv_toast_added': {
      'en': 'Product added successfully!',
      'hi': 'उत्पाद सफलतापूर्वक जोड़ा गया!',
    },
    'inv_toast_updated': {
      'en': 'Product updated successfully!',
      'hi': 'उत्पाद सफलतापूर्वक अपडेट हो गया!',
    },
    'inv_quick_restock': {
      'en': 'Quick Restock',
      'hi': 'त्वरित स्टॉक भरें',
    },
    'inv_fill_stock': {
      'en': 'Update Stock',
      'hi': 'स्टॉक अपडेट करें',
    },
    'inv_stock_updated': {
      'en': 'Stock quantity updated!',
      'hi': 'स्टॉक मात्रा अपडेट हो गई!',
    },
    'inv_edit_product': {
      'en': 'Edit Product',
      'hi': 'उत्पाद संपादित करें',
    },
    'inv_uploading_images': {
      'en': 'Uploading product photos...',
      'hi': 'उत्पाद की तस्वीरें अपलोड हो रही हैं...',
    },
    'inv_status_in_stock': {
      'en': 'in stock',
      'hi': 'स्टॉक में',
    },
    'inv_status_low_stock': {
      'en': 'Low Stock',
      'hi': 'कम स्टॉक',
    },
    'inv_status_out_of_stock': {
      'en': 'Out of Stock',
      'hi': 'स्टॉक समाप्त',
    },

    // Bulk Import Products
    'bulk_import_title': {
      'en': 'Bulk Import Products',
      'hi': 'एक साथ कई उत्पाद जोड़ें',
    },
    'bulk_import_subtitle': {
      'en': 'Import hundreds of products instantly using Excel (.xlsx) or CSV',
      'hi': 'एक्सेल (.xlsx) या सीएसवी से सैकड़ों उत्पाद एक साथ जोड़ें',
    },
    'bulk_import_step_template': {
      'en': '1. Download Sample Template',
      'hi': '१. नमूना प्रारूप (टेम्पलेट) डाउनलोड करें',
    },
    'bulk_import_step_template_desc': {
      'en': 'Download our pre-formatted file with sample items, fill in your catalog details, and save.',
      'hi': 'नमूना उत्पादों वाली हमारी तैयार फ़ाइल डाउनलोड करें, अपने उत्पाद भरें और सुरक्षित करें।',
    },
    'bulk_import_download_excel': {
      'en': 'Download Excel (.xlsx)',
      'hi': 'एक्सेल (.xlsx) डाउनलोड करें',
    },
    'bulk_import_download_csv': {
      'en': 'Download CSV (.csv)',
      'hi': 'सीएसवी (.csv) डाउनलोड करें',
    },
    'bulk_import_step_upload': {
      'en': '2. Select Your File',
      'hi': '२. अपनी फ़ाइल चुनें',
    },
    'bulk_import_step_upload_desc': {
      'en': 'Choose the completed .xlsx, .xls, or .csv file from your device.',
      'hi': 'अपने डिवाइस से भरी हुई .xlsx, .xls या .csv फ़ाइल चुनें।',
    },
    'bulk_import_btn_browse': {
      'en': 'Browse File',
      'hi': 'फ़ाइल चुनें',
    },
    'bulk_import_file_selected': {
      'en': 'File selected',
      'hi': 'फ़ाइल चुनी गई',
    },
    'bulk_import_update_existing_title': {
      'en': 'Update existing products if SKU matches',
      'hi': 'यदि बारकोड/SKU पहले से मौजूद है तो अपडेट करें',
    },
    'bulk_import_update_existing_subtitle': {
      'en': 'Updates price, cost, and stock without creating duplicate items.',
      'hi': 'नया उत्पाद बनाने के बजाय मूल्य और स्टॉक अपडेट करेगा।',
    },
    'bulk_import_btn_start': {
      'en': 'Start Bulk Import',
      'hi': 'उत्पाद जोड़ना शुरू करें',
    },
    'bulk_import_processing': {
      'en': 'Importing products in background...',
      'hi': 'उत्पाद जोड़े जा रहे हैं...',
    },
    'bulk_import_validating': {
      'en': 'Validating rows, barcodes, and prices...',
      'hi': 'विवरण, बारकोड एवं मूल्यों की जांच हो रही है...',
    },
    'bulk_import_success_title': {
      'en': 'Bulk Import Completed!',
      'hi': 'उत्पाद सफलतापूर्वक जुड़ गए!',
    },
    'bulk_import_stat_total': {
      'en': 'Total Rows',
      'hi': 'कुल पंक्तियाँ',
    },
    'bulk_import_stat_imported': {
      'en': 'New Added',
      'hi': 'नए जुड़े',
    },
    'bulk_import_stat_updated': {
      'en': 'Updated',
      'hi': 'अपडेट हुए',
    },
    'bulk_import_stat_skipped': {
      'en': 'Skipped',
      'hi': 'छोड़े गए',
    },
    'bulk_import_errors_heading': {
      'en': 'Row Issues / Skipped Details',
      'hi': 'छोड़े गए उत्पादों का विवरण',
    },
    'bulk_import_close_btn': {
      'en': 'Done',
      'hi': 'पूर्ण',
    },
    'bulk_import_choose_file_hint': {
      'en': 'Please select an Excel or CSV file first',
      'hi': 'कृपया पहले एक्सेल या सीएसवी फ़ाइल चुनें',
    },
    'bulk_import_open_dialog_btn': {
      'en': 'Bulk Import (Excel / CSV)',
      'hi': 'एक्सेल/सीएसवी से जोड़ें',
    },

    // Store Expenses
    'exp_title': {
      'en': 'Daily Store Expenses',
      'hi': 'दैनिक दुकान ख़र्चे',
    },
    'exp_banner_title': {
      'en': 'Total Spent (Expenses)',
      'hi': 'कुल ख़र्च राशि',
    },
    'exp_add_btn': {
      'en': 'Record Expense',
      'hi': 'ख़र्च जोड़ें',
    },
    'exp_empty_title': {
      'en': 'No expenses recorded. Add your first expense.',
      'hi': 'कोई ख़र्च दर्ज नहीं है। नया ख़र्च जोड़ें।',
    },
    'exp_dialog_title': {
      'en': 'Record New Expense',
      'hi': 'नया ख़र्च दर्ज करें',
    },
    'exp_field_category': {
      'en': 'Expense Category',
      'hi': 'ख़र्च की श्रेणी',
    },
    'exp_field_amount': {
      'en': 'Amount (₹) *',
      'hi': 'ख़र्च राशि (₹) *',
    },
    'exp_field_notes': {
      'en': 'Notes / Details (Optional)',
      'hi': 'विवरण (वैकल्पिक)',
    },
    'exp_field_payment_mode': {
      'en': 'Payment Source',
      'hi': 'भुगतान का स्रोत',
    },
    'exp_cat_tea': {
      'en': '☕ Tea & Snacks',
      'hi': '☕ चाय एवं नाश्ता',
    },
    'exp_cat_electricity': {
      'en': '⚡ Electricity Bill',
      'hi': '⚡ बिजली बिल',
    },
    'exp_cat_rent': {
      'en': '🏢 Store Rent',
      'hi': '🏢 दुकान किराया',
    },
    'exp_cat_salary': {
      'en': '👨‍💼 Staff Salary',
      'hi': '👨‍💼 कर्मचारी वेतन',
    },
    'exp_cat_packaging': {
      'en': '📦 Packaging & Bags',
      'hi': '📦 पैकेजिंग सामग्री',
    },
    'exp_cat_maintenance': {
      'en': '🔧 Repair & Cleaning',
      'hi': '🔧 मरम्मत एवं सफ़ाई',
    },
    'exp_cat_other': {
      'en': '📝 Other Expense',
      'hi': '📝 अन्य ख़र्च',
    },
    'exp_mode_cash': {
      'en': 'Cash (From Drawer)',
      'hi': 'नकद (गल्ले से)',
    },
    'exp_mode_online': {
      'en': 'Online / UPI',
      'hi': 'ऑनलाइन / यूपीआई',
    },
    'exp_toast_saved': {
      'en': 'Expense recorded successfully!',
      'hi': 'ख़र्च सफलतापूर्वक दर्ज किया गया!',
    },

    // Additional Storefront & Catalog Action Keys
    'storefront_call_store': {
      'en': 'Call Store',
      'hi': 'दुकान पर कॉल करें',
    },
    'storefront_order_btn': {
      'en': 'Order',
      'hi': 'ऑर्डर',
    },
    'storefront_direct_order_title': {
      'en': 'Direct Orders Available!',
      'hi': 'सीधे ऑर्डर उपलब्ध हैं!',
    },
    'storefront_direct_order_sub': {
      'en': 'The digital catalog is being updated by the store. You can still order any item directly via WhatsApp or phone call!',
      'hi': 'डिजिटल कैटलॉग अपडेट किया जा रहा है। आप अभी भी व्हाट्सएप या फोन कॉल द्वारा कोई भी सामान सीधे ऑर्डर कर सकते हैं!',
    },
    'storefront_send_list_wa': {
      'en': 'Send Order List on WhatsApp',
      'hi': 'व्हाट्सएप पर ऑर्डर लिस्ट भेजें',
    },
    'storefront_powered_by': {
      'en': 'Powered by ShopSilo Digital Retail Network',
      'hi': 'शॉपसाइलो डिजिटल रिटेल नेटवर्क द्वारा संचालित',
    },

    // Shop Showcase Banners Management
    'shop_banners_title': {
      'en': 'Shop Showcase Banners',
      'hi': 'दुकान के प्रचार बैनर',
    },
    'shop_banners_subtitle': {
      'en': 'Showcase Banners Uploaded',
      'hi': 'प्रचार बैनर अपलोड किए गए',
    },
    'shop_banners_edit': {
      'en': 'Edit Banners',
      'hi': 'बैनर बदलें',
    },
    'shop_banners_source_title': {
      'en': 'Select Shop Banner Image Source',
      'hi': 'दुकान बैनर फ़ोटो का स्रोत चुनें',
    },
    'shop_banners_source_gallery': {
      'en': 'Choose from Gallery / Photos',
      'hi': 'गैलरी / फ़ोटो से चुनें',
    },
    'shop_banners_source_camera': {
      'en': 'Take Photo with Camera',
      'hi': 'कैमरा से फ़ोटो खींचें',
    },
    'shop_banners_add': {
      'en': 'Add Banner',
      'hi': 'बैनर जोड़ें',
    },
    'shop_banners_save': {
      'en': 'Save Shop Banners',
      'hi': 'बैनर सुरक्षित करें',
    },
    'shop_banners_updated': {
      'en': 'Shop showcase banners updated successfully!',
      'hi': 'दुकान के बैनर सफलतापूर्वक सुरक्षित कर दिए गए हैं!',
    },
    'shop_banners_upload_failed': {
      'en': 'Failed to upload banner images. Please try again.',
      'hi': 'बैनर इमेज अपलोड करने में समस्या आई। कृपया पुनः प्रयास करें।',
    },
    'shop_banners_save_failed': {
      'en': 'Failed to update shop banners',
      'hi': 'दुकान के बैनर अपडेट करने में असमर्थ',
    },
    'shop_banners_limit_hint': {
      'en': 'Upload up to 2 promotional banners to showcase your store offerings.',
      'hi': 'अपनी दुकान के प्रचार के लिए अधिकतम 2 बैनर जोड़ें।',
    },

    // Customer Khata & Credit Ledger Module
    'khata_title': {
      'en': 'Customer Credit Ledger',
      'hi': 'ग्राहक उधार खाता',
    },
    'khata_add_btn': {
      'en': 'Record Entry',
      'hi': 'प्रविष्टि दर्ज करें',
    },
    'khata_banner_title': {
      'en': 'Total Market Receivables',
      'hi': 'कुल बाजार उधारी',
    },
    'khata_search_hint': {
      'en': 'Search customer name or mobile number...',
      'hi': 'ग्राहक का नाम या मोबाइल नंबर खोजें...',
    },
    'khata_empty_title': {
      'en': 'No customer khata records found',
      'hi': 'कोई उधार खाता रिकॉर्ड नहीं मिला',
    },
    'khata_dialog_give_credit': {
      'en': 'Give Credit (Udhar Diya)',
      'hi': 'उधार दिया (क्रेडिट)',
    },
    'khata_dialog_receive_payment': {
      'en': 'Receive Payment (Jama Kiya)',
      'hi': 'जमा प्राप्त किया (पेमेंट)',
    },
    'khata_field_customer_name': {
      'en': 'Customer Name',
      'hi': 'ग्राहक का नाम',
    },
    'khata_field_customer_phone': {
      'en': 'Mobile Number',
      'hi': 'मोबाइल नंबर',
    },
    'khata_field_amount': {
      'en': 'Amount (₹)',
      'hi': 'राशि (₹)',
    },
    'khata_field_notes': {
      'en': 'Notes / Item Description',
      'hi': 'विवरण / सामान की सूची',
    },
    'khata_field_bill_no': {
      'en': 'Bill / Invoice Number (Optional)',
      'hi': 'बिल / इनवॉइस नंबर (वैकल्पिक)',
    },
    'khata_field_payment_mode': {
      'en': 'Payment Mode',
      'hi': 'भुगतान का माध्यम',
    },
    'khata_toast_saved': {
      'en': 'Transaction recorded successfully',
      'hi': 'लेन-देन सफलतापूर्वक दर्ज हो गया',
    },
    'khata_toast_limit_saved': {
      'en': 'Credit limit updated successfully',
      'hi': 'उधार सीमा सुरक्षित कर दी गई',
    },
    'khata_toast_promise_saved': {
      'en': 'Promise date saved successfully',
      'hi': 'भुगतान वादा तारीख दर्ज कर दी गई',
    },
    'khata_toast_reversed': {
      'en': 'Transaction reversed successfully',
      'hi': 'प्रविष्टि सफलतापूर्वक रद्द कर दी गई',
    },
    'khata_statement_dues': {
      'en': 'Net Pending Dues',
      'hi': 'कुल शेष बकाया',
    },
    'khata_history_title': {
      'en': 'Transaction Passbook',
      'hi': 'लेन-देन पासबुक',
    },
    'khata_history_empty': {
      'en': 'No transaction history found',
      'hi': 'कोई लेन-देन विवरण उपलब्ध नहीं है',
    },
    'khata_kpi_total_receivables': {
      'en': 'Total Receivables',
      'hi': 'कुल बकाया राशि',
    },
    'khata_kpi_debtors': {
      'en': 'Debtors',
      'hi': 'बकायादार ग्राहक',
    },
    'khata_kpi_overdue': {
      'en': 'Overdue Accounts',
      'hi': 'अतिदेय खाते',
    },
    'khata_kpi_aging_title': {
      'en': 'Aging Breakdown',
      'hi': 'उधारी अवधि विवरण',
    },
    'khata_aging_0_30': {
      'en': '0-30 Days',
      'hi': '0-30 दिन',
    },
    'khata_aging_31_60': {
      'en': '31-60 Days',
      'hi': '31-60 दिन',
    },
    'khata_aging_60_plus': {
      'en': '60+ Days',
      'hi': '60+ दिन',
    },
    'khata_tab_all': {
      'en': 'All Customers',
      'hi': 'सभी ग्राहक',
    },
    'khata_tab_dues': {
      'en': 'Pending Dues',
      'hi': 'बकाया उधारी',
    },
    'khata_tab_overdue': {
      'en': 'Overdue (30+ Days)',
      'hi': 'समय सीमा समाप्त (30+ दिन)',
    },
    'khata_tab_settled': {
      'en': 'Settled (₹0)',
      'hi': 'चुकता खाते',
    },
    'khata_btn_whatsapp_reminder': {
      'en': 'WhatsApp Reminder',
      'hi': 'व्हाट्सएप तकाजा',
    },
    'khata_btn_download_pdf': {
      'en': 'PDF Statement',
      'hi': 'पीडीएफ पासबुक',
    },
    'khata_btn_set_promise': {
      'en': 'Payment Promise Date',
      'hi': 'भुगतान वादा तारीख',
    },
    'khata_btn_credit_limit': {
      'en': 'Credit Limit',
      'hi': 'उधार सीमा',
    },
    'khata_btn_reverse': {
      'en': 'Reverse Entry',
      'hi': 'प्रविष्टि रद्द करें',
    },
    'khata_reverse_confirm': {
      'en': 'Are you sure you want to reverse this transaction?',
      'hi': 'क्या आप इस लेन-देन को रद्द करना चाहते हैं?',
    },
    'khata_reverse_reason': {
      'en': 'Reason for reversal (e.g. Wrong entry)',
      'hi': 'रद्द करने का कारण (उदा. गलत प्रविष्टि)',
    },
    'khata_promise_label': {
      'en': 'Promise Date',
      'hi': 'भुगतान का वादा',
    },
    'khata_credit_limit_label': {
      'en': 'Credit Limit',
      'hi': 'उधार सीमा',
    },
    'khata_trust_score_label': {
      'en': 'Customer Trust Score',
      'hi': 'ग्राहक साख स्कोर',
    },
    'khata_trust_reliable': {
      'en': 'Highly Reliable',
      'hi': 'अति विश्वसनीय',
    },
    'khata_trust_normal': {
      'en': 'Average',
      'hi': 'सामान्य',
    },
    'khata_trust_caution': {
      'en': 'Caution Advised',
      'hi': 'सावधानी बरतें',
    },
    'khata_mode_cash': {
      'en': 'Cash',
      'hi': 'नकद',
    },
    'khata_mode_upi': {
      'en': 'UPI / Online',
      'hi': 'यूपीआई / ऑनलाइन',
    },
    'khata_mode_cheque': {
      'en': 'Cheque / Bank',
      'hi': 'चेक / बैंक',
    },
    'khata_customer_passbook': {
      'en': 'Customer Passbook Ledger',
      'hi': 'ग्राहक पासबुक बहीखाता',
    },
    'khata_limit_used': {
      'en': 'Limit Utilized',
      'hi': 'उपयोग की गई सीमा',
    },
    'khata_limit_exceeded': {
      'en': 'Limit Exceeded!',
      'hi': 'उधार सीमा पार!',
    },
    'khata_status_settled': {
      'en': 'Settled',
      'hi': 'चुकता',
    },
    'khata_status_due': {
      'en': 'Pending Due',
      'hi': 'बकाया',
    },
    'khata_status_advance': {
      'en': 'Advance Deposit',
      'hi': 'अग्रिम जमा',
    },
    'khata_whatsapp_not_installed': {
      'en': 'Unable to open WhatsApp on this device',
      'hi': 'इस डिवाइस पर व्हाट्सएप खोलने में असमर्थ',
    },
    'khata_no_phone': {
      'en': 'Customer mobile number is missing',
      'hi': 'ग्राहक का मोबाइल नंबर उपलब्ध नहीं है',
    },
    'khata_select_date': {
      'en': 'Select Payment Promise Date',
      'hi': 'भुगतान वादा तारीख चुनें',
    },
    'khata_enter_credit_limit': {
      'en': 'Set Credit Limit (₹)',
      'hi': 'उधार सीमा दर्ज करें (₹)',
    },
    'khata_recent_customers': {
      'en': 'Recent Customers',
      'hi': 'हाल के ग्राहक',
    },
    'khata_new_customer': {
      'en': '+ New Customer',
      'hi': '+ नया ग्राहक',
    },
    'khata_existing_customer': {
      'en': 'Existing Customer',
      'hi': 'मौजूदा ग्राहक',
    },
    'khata_quick_presets': {
      'en': 'Quick Amount',
      'hi': 'त्वरित राशि',
    },
    'pos_product_not_found': {
      'en': 'Product not found. Please choose from catalog or add a custom item.',
      'hi': 'उत्पाद नहीं मिला। कृपया सूची से चुनें या कस्टम आइटम जोड़ें।',
    },
    'pos_val_price': {
      'en': 'Please enter a valid price',
      'hi': 'कृपया मान्य मूल्य दर्ज करें',
    },
    'exp_val_amount': {
      'en': 'Please enter a valid expense amount',
      'hi': 'कृपया मान्य खर्च राशि दर्ज करें',
    },
    'inv_val_name': {
      'en': 'Please enter product name',
      'hi': 'कृपया उत्पाद का नाम दर्ज करें',
    },
    'inv_val_selling_price': {
      'en': 'Please enter a valid selling price (> 0)',
      'hi': 'कृपया मान्य विक्रय मूल्य (> 0) दर्ज करें',
    },
    'inv_val_mrp_less': {
      'en': 'MRP / Compare Price cannot be less than Selling Price',
      'hi': 'अधिकतम खुदरा मूल्य (MRP) विक्रय मूल्य से कम नहीं हो सकता',
    },
    'inv_val_cost_more': {
      'en': 'Cost Price cannot be greater than Selling Price',
      'hi': 'लागत मूल्य विक्रय मूल्य से अधिक नहीं हो सकता',
    },
    'inv_val_floor_more': {
      'en': 'Minimum bargain price cannot be greater than Selling Price',
      'hi': 'न्यूनतम सौदा मूल्य विक्रय मूल्य से अधिक नहीं हो सकता',
    },
    'inv_val_image_failed': {
      'en': 'Failed to upload product images. Please try again.',
      'hi': 'उत्पाद छवियां अपलोड करने में विफल। कृपया पुनः प्रयास करें।',
    },
    'proc_val_name': {
      'en': 'Please enter item name',
      'hi': 'कृपया आइटम का नाम दर्ज करें',
    },
    'today_sales_title': {
      'en': "Today's Sales (24 Hours)",
      'hi': 'आज की बिक्री (24 घंटे)',
    },
    'today_sales_subtitle': {
      'en': 'Products sold and revenue generated',
      'hi': 'बिके हुए उत्पाद और कुल आमदनी',
    },
    'today_sales_total_rev': {
      'en': 'Total Revenue',
      'hi': 'कुल बिक्री',
    },
    'today_sales_total_bills': {
      'en': 'Total Bills',
      'hi': 'कुल बिल',
    },
    'today_sales_items_sold': {
      'en': 'Products Sold',
      'hi': 'बिका सामान',
    },
    'today_sales_empty_title': {
      'en': 'No sales recorded in the last 24 hours',
      'hi': 'पिछले 24 घंटों में कोई बिक्री दर्ज नहीं हुई',
    },
    'today_sales_empty_sub': {
      'en': 'Counter sales created in POS will appear here automatically',
      'hi': 'POS में बनाए गए बिल यहाँ अपने आप दिखाई देंगे',
    },
    'today_sales_open_pos': {
      'en': 'Open POS Counter',
      'hi': 'POS काउंटर खोलें',
    },
    'today_sales_products_header': {
      'en': 'Products Sold (Last 24 Hours)',
      'hi': 'बिके हुए सामान की सूची (24 घंटे)',
    },
    'today_sales_recent_bills_header': {
      'en': 'Recent Completed Bills',
      'hi': 'हाल के पूर्ण बिल',
    },

    // Enhanced POS & Checkout Extensions
    'pos_bill_copied': {
      'en': 'Receipt copied to clipboard',
      'hi': 'रसीद क्लिपबोर्ड पर कॉपी हो गई',
    },
    'pos_btn_copy_bill': {
      'en': 'Copy Bill Receipt',
      'hi': 'बिल रसीद कॉपी करें',
    },
    'pos_upi_qr_title': {
      'en': 'Scan & Pay via UPI',
      'hi': 'UPI से स्कैन और भुगतान करें',
    },
    'pos_upi_qr_subtitle': {
      'en': 'Scan with Google Pay, PhonePe, Paytm, or BHIM',
      'hi': 'Google Pay, PhonePe, Paytm या BHIM से स्कैन करें',
    },
    'pos_upi_enter_id': {
      'en': 'Enter Shop UPI ID / VPA',
      'hi': 'दुकान की UPI ID / VPA दर्ज करें',
    },
    'pos_upi_save_id': {
      'en': 'Save UPI ID',
      'hi': 'UPI ID सहेजें',
    },
    'pos_show_upi_qr': {
      'en': 'Show UPI QR Code',
      'hi': 'UPI QR कोड दिखाएं',
    },
    'pos_upi_not_configured': {
      'en': 'Set your UPI ID to generate payment QR code',
      'hi': 'भुगतान QR कोड बनाने के लिए अपनी UPI ID सेट करें',
    },
    'pos_whatsapp_receipt_sent': {
      'en': 'Opening WhatsApp...',
      'hi': 'व्हाट्सएप खुल रहा है...',
    },

    // Enhanced Inventory & Quick Stock
    'inv_quick_stock_title': {
      'en': 'Quick Stock Adjuster',
      'hi': 'त्वरित स्टॉक समायोजन',
    },
    'inv_quick_stock_sub': {
      'en': 'Quickly update available stock units',
      'hi': 'उपलब्ध स्टॉक इकाइयों को तुरंत अपडेट करें',
    },
    'inv_quick_stock_saved': {
      'en': 'Stock updated successfully',
      'hi': 'स्टॉक सफलतापूर्वक अपडेट किया गया',
    },
    'inv_stock_low_badge': {
      'en': 'Low Stock',
      'hi': 'कम स्टॉक',
    },
    'inv_stock_in_stock': {
      'en': 'In Stock',
      'hi': 'स्टॉक में',
    },
    'inv_stock_units': {
      'en': 'Units',
      'hi': 'इकाइयाँ',
    },

    // Enhanced Khata & Digital Ledger
    'khata_copied_summary': {
      'en': 'Khata statement copied to clipboard',
      'hi': 'खाता विवरण क्लिपबोर्ड पर कॉपी हो गया',
    },
    'khata_btn_copy_summary': {
      'en': 'Copy Summary',
      'hi': 'खाता कॉपी करें',
    },
    'khata_share_whatsapp_title': {
      'en': 'Share on WhatsApp',
      'hi': 'व्हाट्सएप पर भेजें',
    },
  };

  static String get(String key, AppLanguage language) {
    final langCode = language == AppLanguage.hindi ? 'hi' : 'en';
    final entry = _keys[key];
    if (entry != null) {
      return entry[langCode] ?? entry['en'] ?? key;
    }
    return key;
  }
}
