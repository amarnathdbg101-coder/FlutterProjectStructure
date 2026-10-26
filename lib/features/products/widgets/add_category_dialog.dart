import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../controllers/category_controller.dart';
import '../models/category_model.dart';

class AddCategoryDialog extends StatefulWidget {
  final String? initialName;

  const AddCategoryDialog({super.key, this.initialName});

  static Future<CategoryItemModel?> show(BuildContext context, {String? initialName}) {
    return showDialog<CategoryItemModel>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddCategoryDialog(initialName: initialName),
    );
  }

  @override
  State<AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<AddCategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  final TextEditingController _descCtrl = TextEditingController();
  
  // Non-vegetable professional icon presets
  static const List<String> _presetIcons = [
    '📦', '🛒', '🥛', '🏷️', '⚡', '☕', 
    '🧼', '🍞', '🍬', '🧹', '👕', '👟', 
    '💊', '🔧', '🎯', '🧴', '🎧', '📱'
  ];

  String _selectedIcon = '📦';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    final catCtrl = context.read<CategoryController>();

    final created = await catCtrl.createCategory(
      name: _nameCtrl.text.trim(),
      icon: _selectedIcon,
      description: _descCtrl.text.trim(),
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (created != null) {
        Navigator.of(context).pop(created);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: theme.colorScheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _selectedIcon,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Nayi Custom Category',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Apni shop ke hisaab se category banayein',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Category Name Input
                  Text(
                    'Category Ka Naam *',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _nameCtrl,
                    autofocus: widget.initialName == null,
                    decoration: InputDecoration(
                      hintText: 'Jaise: Paan Masala, Namkeen, Dairy Specials...',
                      prefixIcon: const Icon(Icons.label_outline, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Kripya category ka naam likhein';
                      }
                      if (val.trim().length < 2) {
                        return 'Naam kam se kam 2 characters ka hona chahiye';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Icon Picker
                  Text(
                    'Category Icon Chunein',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _presetIcons.map((icon) {
                      final isSelected = _selectedIcon == icon;
                      return InkWell(
                        onTap: _isSubmitting ? null : () => setState(() => _selectedIcon = icon),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 42,
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary.withOpacity(0.2)
                                : theme.colorScheme.surfaceVariant.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Text(icon, style: const TextStyle(fontSize: 20)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Description Input (Optional)
                  Text(
                    'Description (Optional)',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _descCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Thoda vivaran ya details...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _submit,
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check, size: 18),
                        label: Text(_isSubmitting ? 'Bana rahe hain...' : 'Save Category'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
