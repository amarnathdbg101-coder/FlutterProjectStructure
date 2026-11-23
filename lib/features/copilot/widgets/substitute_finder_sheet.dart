import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/language_controller.dart';
import '../../../core/constants/app_colors.dart';
import '../../pos/controllers/pos_controller.dart';
import '../../products/models/product_model.dart';
import '../controllers/copilot_controller.dart';
import '../models/copilot_model.dart';

/// Bottom sheet for Natural Language & Domain-aware Substitute Finding on POS Counter.
class SubstituteFinderSheet extends StatefulWidget {
  final PosController pos;
  final String? initialQuery;

  const SubstituteFinderSheet({
    super.key,
    required this.pos,
    this.initialQuery,
  });

  static Future<void> show({
    required BuildContext context,
    required PosController pos,
    String? initialQuery,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SubstituteFinderSheet(pos: pos, initialQuery: initialQuery),
    );
  }

  @override
  State<SubstituteFinderSheet> createState() => _SubstituteFinderSheetState();
}

class _SubstituteFinderSheetState extends State<SubstituteFinderSheet> {
  late TextEditingController _searchCtrl;
  String _selectedCategory = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(text: widget.initialQuery ?? '');
    if (_searchCtrl.text.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _performSearch();
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _performSearch() {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;
    context.read<CopilotController>().searchSubstitutes(
      query: q,
      category: _selectedCategory,
    );
  }

  @override
  Widget build(BuildContext context) {
    final copilot = context.watch<CopilotController>();
    final substitutes = copilot.substitutes;
    final isLoading = copilot.isSearchingSubstitutes;
    final isHindi = context.isHindi;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.swap_horiz_rounded, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isHindi ? 'स्मार्ट सब्स्टीट्यूट व विकल्प खोज' : 'Smart Substitute & Alternative Finder',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        isHindi
                            ? 'कपड़े व सौंदर्य प्रसाधन के सटीक विकल्प खोजें'
                            : 'Match exact customer intent for clothes & cosmetics',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Search Field & Category quick filter
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: isHindi
                        ? 'उदा. "हल्दी कॉटन कुर्ती 800 तक" या "ऑयली स्किन क्रीम"'
                        : 'e.g. "Haldi yellow cotton kurti" or "Oily skin face wash"',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.arrow_forward_rounded, color: AppColors.primary),
                      onPressed: _performSearch,
                    ),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onSubmitted: (_) => _performSearch(),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildCategoryChip(isHindi ? 'सभी' : 'All', ''),
                    const SizedBox(width: 8),
                    _buildCategoryChip(isHindi ? 'कपड़े / गारमेंट्स' : 'Clothing', 'Clothing'),
                    const SizedBox(width: 8),
                    _buildCategoryChip(isHindi ? 'सौंदर्य / कॉस्मेटिक्स' : 'Cosmetics', 'Cosmetics'),
                  ],
                ),
              ],
            ),
          ),

          // Content List
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : substitutes.isEmpty
                    ? Center(
                        child: Text(
                          isHindi
                              ? 'ग्राहक की मांग लिखें और खोजें'
                              : 'Type customer requirement and tap search',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        itemCount: substitutes.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final sub = substitutes[index];
                          return _SubstituteCard(
                            sub: sub,
                            onAddToCart: () {
                              final dummyProduct = ProductModel(
                                id: sub.productId,
                                name: sub.productName,
                                sku: 'SUB_${sub.productId}',
                                barcode: '',
                                price: sub.offerPrice,
                                category: sub.categoryName,
                                stock: sub.currentStock,
                              );
                              widget.pos.addToCart(dummyProduct);
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isHindi
                                        ? '${sub.productName} बिल में जोड़ा गया!'
                                        : '${sub.productName} added to bill!',
                                  ),
                                  duration: const Duration(seconds: 2),
                                  backgroundColor: const Color(0xFF10B981),
                                ),
                              );
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String label, String value) {
    final isSelected = _selectedCategory == value;
    return InkWell(
      onTap: () {
        setState(() => _selectedCategory = value);
        _performSearch();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : AppColors.primary,
          ),
        ),
      ),
    );
  }
}

class _SubstituteCard extends StatelessWidget {
  final SubstituteRecommendationModel sub;
  final VoidCallback onAddToCart;

  const _SubstituteCard({
    required this.sub,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    final isHindi = context.isHindi;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: sub.isExactMatch
              ? const Color(0xFF10B981).withValues(alpha: 0.5)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (sub.isExactMatch)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isHindi ? 'सटीक स्टॉक' : 'Exact Match',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isHindi ? 'उत्तम विकल्प' : 'Best Substitute',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ),
              Expanded(
                child: Text(
                  sub.productName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '₹${sub.offerPrice.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                '${sub.categoryName} • ${isHindi ? "स्टॉक" : "Stock"}: ${sub.currentStock}',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const Spacer(),
              if (sub.shopProfitMargin > 0)
                Text(
                  '${sub.shopProfitMargin.toStringAsFixed(0)}% ${isHindi ? "मार्जिन" : "Margin"}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF10B981),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.record_voice_over_outlined, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${isHindi ? "ग्राहकों को यह बताएं:" : "Selling pitch:"} "${sub.salesPitchScript}"',
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: onAddToCart,
              icon: const Icon(Icons.add_shopping_cart_rounded, size: 14),
              label: Text(
                isHindi ? 'बिल में जोड़ें' : 'Add to Bill',
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
