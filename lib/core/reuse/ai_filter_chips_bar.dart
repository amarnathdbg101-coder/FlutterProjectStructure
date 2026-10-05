import 'package:flutter/material.dart';

/// Reusable Horizontal Category & Filter Chips Bar
class AiFilterChipsBar extends StatelessWidget {
  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onSelected;
  final bool isDark;
  final Color activeColor;

  const AiFilterChipsBar({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onSelected,
    required this.isDark,
    this.activeColor = const Color(0xFF4F46E5),
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: categories.map((cat) {
          final isSelected = selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                cat,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white70 : const Color(0xFF475569)),
                ),
              ),
              selected: isSelected,
              selectedColor: activeColor,
              backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              side: BorderSide(
                color: isSelected
                    ? activeColor
                    : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              showCheckmark: false,
              onSelected: (selected) {
                if (selected) {
                  onSelected(cat);
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }
}
