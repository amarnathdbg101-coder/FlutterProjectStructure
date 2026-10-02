import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_dialog.dart';
import '../../../core/widgets/custom_snackbar.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../controllers/__LOWER___controller.dart';

class __PASCAL__ListScreen extends StatefulWidget {
  const __PASCAL__ListScreen({super.key});

  @override
  State<__PASCAL__ListScreen> createState() => ___PASCAL__ListScreenState();
}

class ___PASCAL__ListScreenState extends State<__PASCAL__ListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<__PASCAL__Controller>().fetchAll();
    });
  }

  void _showAddDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add New __PASCAL__',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            CustomTextField(controller: titleCtrl, label: 'Title', hint: 'Enter title'),
            const SizedBox(height: 12),
            CustomTextField(controller: descCtrl, label: 'Description', hint: 'Enter description'),
            const SizedBox(height: 20),
            CustomButton(
              text: 'Save __PASCAL__',
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty) return;
                final ctrl = context.read<__PASCAL__Controller>();
                final navigator = Navigator.of(bottomSheetContext);

                final success = await ctrl.createItem(
                  titleCtrl.text.trim(),
                  descCtrl.text.trim(),
                );

                navigator.pop();

                if (success && mounted) {
                  CustomSnackbar.showSuccess(context, '__PASCAL__ added!');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(dynamic id) async {
    final confirm = await CustomDialog.confirm(
      context,
      title: 'Delete __PASCAL__',
      message: 'Are you sure you want to delete this __LOWER__?',
      confirmText: 'Delete',
      isDestructive: true,
    );

    if (confirm && mounted) {
      final success = await context.read<__PASCAL__Controller>().deleteItem(id);
      if (success && mounted) {
        CustomSnackbar.showSuccess(context, '__PASCAL__ deleted successfully');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<__PASCAL__Controller>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('__PASCAL__ List'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: ctrl.isLoading && ctrl.items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ctrl.hasError && ctrl.items.isEmpty
              ? ErrorStateWidget(
                  message: ctrl.errorMessage!,
                  onRetry: () => ctrl.fetchAll(),
                )
              : ctrl.items.isEmpty
                  ? EmptyStateWidget(
                      title: 'No __PLURAL__ Found',
                      message: 'Tap the + button below to create your first __LOWER__.',
                      actionLabel: 'Add __PASCAL__',
                      onAction: _showAddDialog,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: ctrl.items.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final item = ctrl.items[i];
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                    const SizedBox(height: 4),
                                    Text(item.description, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                                onPressed: () => _confirmDelete(item.id),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}
