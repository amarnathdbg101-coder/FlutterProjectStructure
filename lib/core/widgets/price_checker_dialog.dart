import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../features/pos/controllers/pos_controller.dart';
import '../../features/pos/repositories/pos_repository.dart';
import '../../features/products/controllers/product_controller.dart';
import '../../features/products/models/product_model.dart';
import '../../features/products/repositories/product_repository.dart';
import '../../features/products/services/smart_barcode_catalog_service.dart';
import '../../features/products/screens/inventory_screen.dart';
import '../../features/products/widgets/barcode_sticker_dialog.dart';
import '../constants/app_colors.dart';
import '../localization/language_controller.dart';
import 'app_product_image.dart';

/// Instant Product Finder & Price Checker Dialog.
/// Allows cashiers & merchants to scan any barcode via hardware gun or camera,
/// or type SKU/Name, instantly revealing exact price, MRP savings, real-time stock,
/// and triggering 1-tap actions: Add to POS, Restock, Edit Price, Print Barcode Stickers.
class PriceCheckerDialog extends StatefulWidget {
  final String? initialQuery;

  const PriceCheckerDialog({
    super.key,
    this.initialQuery,
  });

  /// Universal static helper to display the Price Checker modal sheet
  static Future<void> show(BuildContext context, {String? initialQuery}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PriceCheckerDialog(initialQuery: initialQuery),
    );
  }

  @override
  State<PriceCheckerDialog> createState() => _PriceCheckerDialogState();
}

class _PriceCheckerDialogState extends State<PriceCheckerDialog> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  ProductModel? _matchedProduct;
  List<ProductModel> _similarProducts = [];
  SmartCatalogItem? _masterCatalogMatch;
  bool _hasSearched = false;
  int _posQuantity = 1;
  bool _showCostMargin = false;
  bool _isSearchingDatabase = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchController.text = widget.initialQuery!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _resolveProduct(widget.initialQuery!);
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _resolveProduct(String query) async {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) {
      setState(() {
        _matchedProduct = null;
        _similarProducts = [];
        _hasSearched = false;
        _isSearchingDatabase = false;
      });
      return;
    }

    final allProducts = context.read<ProductController>().products;

    // 1. Exact Barcode Match (0ms)
    ProductModel? exact;
    for (final p in allProducts) {
      if (p.barcode.trim().toLowerCase() == clean) {
        exact = p;
        break;
      }
    }

    // 2. Exact SKU Match (0ms)
    if (exact == null) {
      for (final p in allProducts) {
        if (p.sku.trim().toLowerCase() == clean) {
          exact = p;
          break;
        }
      }
    }

    // 3. Exact Name Match (0ms)
    if (exact == null) {
      for (final p in allProducts) {
        if (p.name.trim().toLowerCase() == clean) {
          exact = p;
          break;
        }
      }
    }

    if (exact != null) {
      setState(() {
        _matchedProduct = exact;
        _similarProducts = [];
        _masterCatalogMatch = null;
        _hasSearched = true;
        _posQuantity = 1;
        _isSearchingDatabase = false;
      });
      return;
    }

    // 4. Multi-token partial matches from memory (0ms immediate optimistic feedback)
    final suggestions = allProducts.where((p) {
      final name = p.name.toLowerCase();
      final barcode = p.barcode.toLowerCase();
      final sku = p.sku.toLowerCase();
      final cat = p.category.toLowerCase();
      return name.contains(clean) || barcode.contains(clean) || sku.contains(clean) || cat.contains(clean);
    }).take(6).toList();

    // Check Global Master Catalog for barcode match
    final masterMatch = await SmartBarcodeCatalogService.lookup(query.trim());

    setState(() {
      _matchedProduct = suggestions.length == 1 ? suggestions.first : null;
      _similarProducts = suggestions;
      _masterCatalogMatch = masterMatch;
      _hasSearched = true;
      _posQuantity = 1;
    });

    // 5. Database Search Fallback (bypasses 20-item memory limit and searches full PostgreSQL database)
    _queryDatabaseFallback(clean);
  }

  Future<void> _queryDatabaseFallback(String clean) async {
    if (clean.isEmpty) return;
    setState(() => _isSearchingDatabase = true);

    try {
      // 1. Try POS Barcode/SKU scan endpoint first (exact matching)
      final posRepo = PosRepository();
      final scanRes = await posRepo.scanBarcode(clean);
      if (scanRes.success && scanRes.data != null && mounted) {
        final currentText = _searchController.text.trim().toLowerCase();
        if (currentText == clean) {
          setState(() {
            _matchedProduct = scanRes.data;
            _similarProducts = [];
            _hasSearched = true;
            _posQuantity = 1;
            _isSearchingDatabase = false;
          });
          return;
        }
      }

      // 2. Try general product search across full database
      final prodRepo = ProductRepository();
      final searchRes = await prodRepo.searchProducts(clean, limit: 10);
      if (searchRes.success && searchRes.data != null && searchRes.data!.isNotEmpty && mounted) {
        final currentText = _searchController.text.trim().toLowerCase();
        if (currentText == clean) {
          final list = searchRes.data!;
          ProductModel? dbExact;
          for (final p in list) {
            if (p.barcode.trim().toLowerCase() == clean ||
                p.sku.trim().toLowerCase() == clean ||
                p.name.trim().toLowerCase() == clean) {
              dbExact = p;
              break;
            }
          }

          setState(() {
            if (dbExact != null) {
              _matchedProduct = dbExact;
              _similarProducts = [];
            } else if (list.length == 1) {
              _matchedProduct = list.first;
              _similarProducts = [];
            } else {
              _matchedProduct = null;
              _similarProducts = list.take(6).toList();
            }
            _hasSearched = true;
            _posQuantity = 1;
          });
        }
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isSearchingDatabase = false);
      }
    }
  }

  void _onInputChanged(String val) {
    final clean = val.trim();
    // Fast check: if cashier scans barcode gun, it sends fast input
    if (clean.length >= 4) {
      final allProducts = context.read<ProductController>().products;
      final exact = allProducts.where(
        (p) => p.barcode.trim().toLowerCase() == clean.toLowerCase() ||
               p.sku.trim().toLowerCase() == clean.toLowerCase(),
      ).toList();

      if (exact.isNotEmpty) {
        setState(() {
          _matchedProduct = exact.first;
          _similarProducts = [];
          _hasSearched = true;
          _isSearchingDatabase = false;
          _posQuantity = 1;
        });
        return;
      }
    }

    _resolveProduct(val);
  }

  void _resetForNextScan() {
    _searchController.clear();
    setState(() {
      _matchedProduct = null;
      _similarProducts = [];
      _masterCatalogMatch = null;
      _hasSearched = false;
      _isSearchingDatabase = false;
      _posQuantity = 1;
    });
    _focusNode.requestFocus();
  }

  void _addToPosBill(ProductModel product) {
    try {
      final pos = context.read<PosController>();
      for (int i = 0; i < _posQuantity; i++) {
        pos.addToCart(product);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.isHindi
                ? '✓ ${product.name} (x$_posQuantity) काउंटर बिल में जोड़ दी गई!'
                : '✓ ${product.name} (x$_posQuantity) added to active POS bill!',
          ),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (_) {
      // In case POS controller isn't registered
    }
  }

  /// Quick 1-tap Stock Adjuster
  void _showQuickStockAdjustDialog(BuildContext context, ProductModel product) {
    int currentStock = product.stock;
    final stockCtrl = TextEditingController(text: currentStock.toString());

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Row(
              children: [
                const Icon(Icons.inventory_2_rounded, color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ctx.tr('inv_quick_stock_title'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline_rounded, size: 28),
                      onPressed: () {
                        if (currentStock > 0) {
                          setDlgState(() {
                            currentStock--;
                            stockCtrl.text = currentStock.toString();
                          });
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 90,
                      child: TextField(
                        controller: stockCtrl,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                        decoration: const InputDecoration(border: OutlineInputBorder()),
                        onChanged: (val) {
                          final parsed = int.tryParse(val) ?? 0;
                          setDlgState(() => currentStock = parsed);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline_rounded, size: 28, color: AppColors.primary),
                      onPressed: () {
                        setDlgState(() {
                          currentStock++;
                          stockCtrl.text = currentStock.toString();
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [-5, -1, 1, 5, 10, 25].map((delta) {
                    return ActionChip(
                      label: Text('${delta > 0 ? "+$delta" : delta}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        setDlgState(() {
                          currentStock = (currentStock + delta).clamp(0, 99999);
                          stockCtrl.text = currentStock.toString();
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(ctx.isHindi ? 'रद्द करें' : 'Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await context.read<ProductController>().editProduct(
                    product.id,
                    {'stock': currentStock, 'stock_quantity': currentStock},
                  );
                  setState(() {
                    _matchedProduct = product.copyWith(stock: currentStock);
                  });
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(ctx.tr('inv_quick_stock_saved')),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                },
                child: Text(ctx.isHindi ? 'सुरक्षित करें' : 'Save', style: const TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Quick 1-tap Price Editor
  void _showQuickPriceEditDialog(BuildContext context, ProductModel product) {
    final priceCtrl = TextEditingController(text: product.price.toStringAsFixed(0));
    final mrpCtrl = TextEditingController(text: product.comparePrice > 0 ? product.comparePrice.toStringAsFixed(0) : '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.currency_rupee_rounded, color: AppColors.primary, size: 22),
            const SizedBox(width: 8),
            Text(
              ctx.tr('price_checker_btn_edit'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              product.name,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: ctx.tr('price_checker_selling_price'),
                prefixText: '₹ ',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: mrpCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: ctx.tr('price_checker_mrp'),
                prefixText: '₹ ',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.isHindi ? 'रद्द करें' : 'Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              final newPrice = double.tryParse(priceCtrl.text.trim()) ?? product.price;
              final newMrp = double.tryParse(mrpCtrl.text.trim()) ?? product.comparePrice;
              Navigator.pop(ctx);
              await context.read<ProductController>().editProduct(
                product.id,
                {
                  'price': newPrice,
                  'compare_price': newMrp,
                  'mrp': newMrp,
                },
              );
              setState(() {
                _matchedProduct = product.copyWith(price: newPrice, comparePrice: newMrp);
              });
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ctx.isHindi ? 'मूल्य अपडेट हो गया!' : 'Price updated successfully!'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
            child: Text(ctx.isHindi ? 'अपडेट करें' : 'Update', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: BoxDecoration(
        color: context.colorSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 14,
        left: 18,
        right: 18,
        bottom: MediaQuery.of(context).viewInsets.bottom + 18,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: context.colorBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Modal Top Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.colorPrimaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('price_checker_title'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: context.colorTextPrimary,
                      ),
                    ),
                    Text(
                      context.tr('price_checker_sub'),
                      style: TextStyle(fontSize: 11, color: context.colorTextMuted),
                    ),
                  ],
                ),
              ),
              if (_matchedProduct != null || _hasSearched)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    backgroundColor: context.colorPrimaryLight,
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 14, color: AppColors.primary),
                  label: Text(
                    context.tr('price_checker_scan_again'),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                  onPressed: _resetForNextScan,
                ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 1. FAST SCANNER & SEARCH INPUT BAR
          Container(
            height: 46,
            decoration: BoxDecoration(
              color: context.colorSurfaceSubtle,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.colorBorder),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Icon(Icons.barcode_reader, size: 22, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _focusNode,
                    autofocus: true,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.colorTextPrimary),
                    decoration: InputDecoration(
                      hintText: context.tr('price_checker_input_hint'),
                      hintStyle: TextStyle(fontSize: 12.5, color: context.colorTextMuted),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onChanged: _onInputChanged,
                    onSubmitted: _resolveProduct,
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  GestureDetector(
                    onTap: _resetForNextScan,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: context.colorBorder,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close_rounded, size: 14, color: context.colorTextMuted),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 2. MAIN RESULTS DISPLAY (FLEXIBLE & SCROLLABLE)
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: _buildMainContent(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(BuildContext context) {
    if (_matchedProduct != null) {
      return _buildExactProductCard(context, _matchedProduct!);
    }

    if (_isSearchingDatabase && _similarProducts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
            ),
            const SizedBox(height: 14),
            Text(
              context.isHindi
                  ? 'पूरे डेटाबेस में उत्पाद खोजा जा रहा है...'
                  : 'Searching store database for product...',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.colorTextPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_hasSearched && _similarProducts.isNotEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isSearchingDatabase)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  backgroundColor: context.colorPrimaryLight,
                  color: AppColors.primary,
                  minHeight: 2,
                ),
              ),
            ),
          _buildSimilarMatchesList(context),
        ],
      );
    }

    if (_hasSearched && _similarProducts.isEmpty && !_isSearchingDatabase) {
      return _buildNotFoundState(context);
    }

    // Default Waiting/Ready for scan state
    return _buildIdleReadyState(context);
  }

  Widget _buildIdleReadyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: context.colorPrimaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.qr_code_scanner_rounded, size: 54, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            context.isHindi
                ? 'हार्डवेयर बारकोड गन या कैमरा स्कैनर तैयार है'
                : 'Hardware Barcode Gun or Camera Scanner Ready',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: context.colorTextPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            context.isHindi
                ? 'उत्पाद का बारकोड स्कैन करें या ऊपर नाम / SKU लिखकर खोजें।\nसटीक मूल्य और स्टॉक तुरंत दिखाई देगा।'
                : 'Scan any product barcode or type SKU/Name above.\nExact price & stock will be resolved in 0ms.',
            style: TextStyle(fontSize: 11.5, color: context.colorTextMuted, height: 1.4),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNotFoundState(BuildContext context) {
    final queryCode = _searchController.text.trim();
    if (_masterCatalogMatch != null) {
      final m = _masterCatalogMatch!;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: context.colorSurfaceSubtle,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.isHindi ? '⚡ ग्लोबल मास्टर कैटलॉग में मिला' : '⚡ Found in Global Master Catalog',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                        Text(
                          '${context.isHindi ? "बारकोड" : "Barcode"}: $queryCode',
                          style: TextStyle(fontSize: 11, color: context.colorTextMuted, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                m.name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: context.colorTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (m.brand.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: context.colorSurface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: context.colorBorder),
                      ),
                      child: Text(
                        'Brand: ${m.brand}',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.colorTextPrimary),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: context.colorSurface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: context.colorBorder),
                    ),
                    child: Text(
                      'Category: ${m.category}',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.colorTextPrimary),
                    ),
                  ),
                  if (m.unit.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: context.colorSurface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: context.colorBorder),
                      ),
                      child: Text(
                        'Unit: ${m.unit}',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.colorTextPrimary),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (m.mrp > 0) ...[
                    Text(
                      'MRP: ₹${m.mrp.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 13,
                        decoration: TextDecoration.lineThrough,
                        color: context.colorTextMuted,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  if (m.sellingPrice > 0)
                    Text(
                      'Price: ₹${m.sellingPrice.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: AppColors.success,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                label: Text(
                  context.isHindi ? '+ स्टोर इन्वेंटरी में जोड़ें (ऑटो-फिल)' : '+ Add to Store Inventory (Auto-Fill)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  showAddProductDialog(context, initialBarcode: queryCode);
                },
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.search_off_rounded, size: 48, color: AppColors.error),
          ),
          const SizedBox(height: 14),
          Text(
            context.tr('price_checker_not_found'),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: context.colorTextPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Query: "$queryCode"',
            style: TextStyle(fontSize: 12, color: context.colorTextMuted, fontFamily: 'monospace'),
          ),
          if (queryCode.isNotEmpty) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.add_rounded, size: 18, color: AppColors.primary),
              label: Text(
                context.isHindi ? '+ इस बारकोड से उत्पाद जोड़ें' : '+ Add Product with this Barcode',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary),
              ),
              onPressed: () {
                Navigator.pop(context);
                showAddProductDialog(context, initialBarcode: queryCode);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSimilarMatchesList(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            context.isHindi ? 'मिलते-जुलते उत्पाद (${_similarProducts.length})' : 'Matching Products (${_similarProducts.length})',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: context.colorTextSecondary),
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _similarProducts.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (ctx, idx) {
            final p = _similarProducts[idx];
            return Container(
              decoration: BoxDecoration(
                color: context.colorSurfaceSubtle,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.colorBorder),
              ),
              child: ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: context.colorSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.colorBorder),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: AppProductImage(
                    imageUrl: p.imageUrl,
                    width: 44,
                    height: 44,
                    expand: true,
                    fit: BoxFit.cover,
                    borderRadius: BorderRadius.circular(8),
                    fallbackIcon: Icons.inventory_2_outlined,
                    fallbackIconSize: 20,
                  ),
                ),
                title: Text(p.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: context.colorTextPrimary)),
                subtitle: Text(
                  '${p.category} • SKU: ${p.sku.isNotEmpty ? p.sku : (p.barcode.isNotEmpty ? p.barcode : "N/A")}',
                  style: TextStyle(fontSize: 11, color: context.colorTextMuted),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '₹${p.price.toStringAsFixed(0)}',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: context.colorTextPrimary),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      onPressed: () {
                        setState(() {
                          _matchedProduct = p;
                        });
                      },
                    ),
                  ],
                ),
                onTap: () {
                  setState(() {
                    _matchedProduct = p;
                  });
                },
              ),
            );
          },
        ),
      ],
    );
  }

  /// EXACT PRODUCT HERO CARD
  Widget _buildExactProductCard(BuildContext context, ProductModel product) {
    final double savings = product.comparePrice > product.price ? product.comparePrice - product.price : 0;
    final double discountPct = product.comparePrice > product.price && product.comparePrice > 0
        ? ((product.comparePrice - product.price) / product.comparePrice) * 100
        : 0;

    final isLowStock = product.stock <= product.lowStockThreshold && product.stock > 0;
    final isOutOfStock = product.stock <= 0;

    final costPrice = product.costPrice;
    final profit = product.price - costPrice;
    final profitMarginPct = costPrice > 0 ? (profit / product.price) * 100 : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. PRODUCT DETAILS HEADER TILE
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.colorSurfaceSubtle,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.colorBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: context.colorSurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: context.colorBorder),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: AppProductImage(
                      imageUrl: product.imageUrl,
                      width: 68,
                      height: 68,
                      expand: true,
                      fit: BoxFit.cover,
                      borderRadius: BorderRadius.circular(10),
                      fallbackIcon: Icons.inventory_2_outlined,
                      fallbackIconSize: 30,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: context.colorTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: context.colorPrimaryLight,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                product.category,
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ),
                            if (product.unit.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Text(
                                '• ${product.unit}',
                                style: TextStyle(fontSize: 11, color: context.colorTextMuted),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          children: [
                            if (product.barcode.isNotEmpty)
                              Text(
                                'BARCODE: ${product.barcode}',
                                style: TextStyle(fontSize: 9.5, color: context.colorTextMuted, fontFamily: 'monospace'),
                              ),
                            if (product.sku.isNotEmpty && product.sku != product.barcode)
                              Text(
                                'SKU: ${product.sku}',
                                style: TextStyle(fontSize: 9.5, color: context.colorTextMuted, fontFamily: 'monospace'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),

              // 2. HERO PRICE & SAVINGS ROW
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('price_checker_selling_price'),
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: context.colorTextMuted),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '₹${product.price.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: context.colorTextPrimary,
                                ),
                              ),
                              if (savings > 0) ...[
                                const SizedBox(width: 8),
                                Text(
                                  'MRP: ₹${product.comparePrice.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: context.colorTextMuted,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Stock Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isOutOfStock
                          ? AppColors.error.withValues(alpha: 0.12)
                          : isLowStock
                              ? AppColors.warning.withValues(alpha: 0.12)
                              : AppColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isOutOfStock
                            ? AppColors.error.withValues(alpha: 0.4)
                            : isLowStock
                                ? AppColors.warning.withValues(alpha: 0.4)
                                : AppColors.success.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isOutOfStock
                              ? Icons.cancel_outlined
                              : isLowStock
                                  ? Icons.warning_amber_rounded
                                  : Icons.check_circle_outline_rounded,
                          size: 14,
                          color: isOutOfStock
                              ? AppColors.error
                              : isLowStock
                                  ? AppColors.warning
                                  : AppColors.success,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isOutOfStock
                              ? (context.isHindi ? 'आउट ऑफ स्टॉक' : 'Out of Stock')
                              : '${product.stock} ${context.tr("inv_stock_units")}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: isOutOfStock
                                ? AppColors.error
                                : isLowStock
                                    ? AppColors.warning
                                    : AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Customer Savings Banner
              if (savings > 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.savings_outlined, size: 14, color: AppColors.success),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '${context.tr("price_checker_you_save")}: ₹${savings.toStringAsFixed(0)} (${discountPct.toStringAsFixed(0)}% OFF)',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.success),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Cost & Margin (Collapsible)
              if (costPrice > 0) ...[
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => setState(() => _showCostMargin = !_showCostMargin),
                  child: Row(
                    children: [
                      Icon(
                        _showCostMargin ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 14,
                        color: context.colorTextMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _showCostMargin
                            ? '${context.tr("price_checker_cost")}: ₹${costPrice.toStringAsFixed(0)} • ${context.tr("price_checker_margin")}: ₹${profit.toStringAsFixed(0)} (${profitMarginPct.toStringAsFixed(1)}%)'
                            : (context.isHindi ? 'लागत व मार्जिन देखें' : 'View Cost & Margin'),
                        style: TextStyle(fontSize: 10.5, color: context.colorTextMuted, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 3. POS QUANTITY & ADD TO BILL SECTION
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: context.colorPrimaryLight.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              // Quantity Stepper
              Container(
                decoration: BoxDecoration(
                  color: context.colorSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.colorBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_rounded, size: 16),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        if (_posQuantity > 1) {
                          setState(() => _posQuantity--);
                        }
                      },
                    ),
                    Text(
                      '$_posQuantity',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: context.colorTextPrimary),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_rounded, size: 16, color: AppColors.primary),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        setState(() => _posQuantity++);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Add to POS Cart Button
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size(0, 42),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.shopping_cart_checkout_rounded, size: 16, color: Colors.white),
                  label: Text(
                    context.tr('price_checker_btn_pos'),
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  onPressed: isOutOfStock ? null : () => _addToPosBill(product),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 4. QUICK ACTIONS ROW (Restock, Edit Price, Print Barcode Stickers)
        Row(
          children: [
            // Quick Stock Adjuster
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  side: BorderSide(color: context.colorBorder),
                ),
                icon: const Icon(Icons.inventory_2_rounded, size: 14, color: AppColors.primary),
                label: Text(
                  context.tr('price_checker_btn_stock'),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: context.colorTextPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onPressed: () => _showQuickStockAdjustDialog(context, product),
              ),
            ),
            const SizedBox(width: 8),

            // Quick Edit Price
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  side: BorderSide(color: context.colorBorder),
                ),
                icon: const Icon(Icons.edit_outlined, size: 14, color: AppColors.primary),
                label: Text(
                  context.tr('price_checker_btn_edit'),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: context.colorTextPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onPressed: () => _showQuickPriceEditDialog(context, product),
              ),
            ),
            const SizedBox(width: 8),

            // Print Barcode Stickers
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colorSurfaceSubtle,
                  foregroundColor: context.colorTextPrimary,
                  elevation: 0,
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: context.colorBorder),
                  ),
                ),
                icon: const Icon(Icons.qr_code_2_rounded, size: 15, color: AppColors.primary),
                label: Text(
                  context.tr('price_checker_btn_labels'),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: context.colorTextPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onPressed: () => BarcodeStickerDialog.show(context, product),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
