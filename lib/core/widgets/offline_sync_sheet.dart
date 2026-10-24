import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../localization/language_controller.dart';
import '../services/offline_sync_service.dart';

class OfflineSyncSheet {
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => const _OfflineSyncSheetContent(),
    );
  }
}

class _OfflineSyncSheetContent extends StatefulWidget {
  const _OfflineSyncSheetContent();

  @override
  State<_OfflineSyncSheetContent> createState() => _OfflineSyncSheetContentState();
}

class _OfflineSyncSheetContentState extends State<_OfflineSyncSheetContent> {
  final _syncService = OfflineSyncService.instance;
  bool _isProcessing = false;

  IconData _getActionIcon(SyncActionType action) {
    switch (action) {
      case SyncActionType.posSale:
        return Icons.point_of_sale_rounded;
      case SyncActionType.expenseCreate:
        return Icons.receipt_long_rounded;
      case SyncActionType.khataEntry:
        return Icons.menu_book_rounded;
      case SyncActionType.stockAdjust:
        return Icons.inventory_2_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _syncService.queue;
    final pendingCount = _syncService.pendingCount;

    return Container(
      decoration: BoxDecoration(
        color: context.colorSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 20,
        left: 20,
        right: 20,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
          maxWidth: 600,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: context.colorBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: pendingCount > 0 ? context.colorWarningLight : context.colorPrimaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    pendingCount > 0 ? Icons.cloud_upload_rounded : Icons.cloud_done_rounded,
                    color: pendingCount > 0 ? AppColors.warning : AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              context.tr('sync_sheet_title'),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                                color: context.colorTextPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: pendingCount > 0 ? AppColors.warning : AppColors.success,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              pendingCount > 0 ? '$pendingCount' : '✓',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        context.tr('sync_sheet_subtitle'),
                        style: TextStyle(fontSize: 11.5, color: context.colorTextSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: context.colorTextSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Divider(height: 24, color: context.colorBorder),

            // Queue List
            Flexible(
              child: items.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 36),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_done_outlined, size: 48, color: AppColors.success),
                          const SizedBox(height: 12),
                          Text(
                            context.tr('sync_empty'),
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: context.colorTextPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (ctx, index) {
                        final item = items[index];
                        final isCompleted = item.status == SyncStatus.completed;
                        final isSyncing = item.status == SyncStatus.syncing;

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isCompleted
                                ? context.colorSurfaceSubtle.withValues(alpha: 0.5)
                                : context.colorSurfaceSubtle,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isCompleted
                                  ? context.colorBorder.withValues(alpha: 0.5)
                                  : (item.status == SyncStatus.failed
                                      ? AppColors.error.withValues(alpha: 0.5)
                                      : context.colorBorder),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: isCompleted
                                      ? context.colorSuccessLight
                                      : context.colorPrimaryLight,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  _getActionIcon(item.action),
                                  size: 18,
                                  color: isCompleted ? AppColors.success : AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: isCompleted
                                            ? context.colorTextSecondary
                                            : context.colorTextPrimary,
                                        decoration: isCompleted ? TextDecoration.lineThrough : null,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${item.createdAt.hour.toString().padLeft(2, '0')}:${item.createdAt.minute.toString().padLeft(2, '0')} • ${item.action.name.toUpperCase()}',
                                      style: TextStyle(fontSize: 11, color: context.colorTextMuted),
                                    ),
                                  ],
                                ),
                              ),
                              if (item.amount > 0) ...[
                                Text(
                                  '₹${item.amount.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.5,
                                    color: context.colorTextPrimary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              if (isSyncing)
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              else if (isCompleted)
                                const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18)
                              else if (item.status == SyncStatus.failed)
                                const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18)
                              else
                                const Icon(Icons.schedule_rounded, color: AppColors.warning, size: 18),
                            ],
                          ),
                        );
                      },
                    ),
            ),

            const SizedBox(height: 16),

            // Bottom Action Buttons
            Row(
              children: [
                if (items.any((i) => i.status == SyncStatus.completed)) ...[
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () async {
                        await _syncService.removeCompleted();
                        setState(() {});
                      },
                      child: Text(
                        context.isHindi ? 'पूर्ण साफ़ करें' : 'Clear Done',
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.sync_rounded, color: Colors.white, size: 18),
                    label: Text(
                      _isProcessing ? context.tr('sync_status_syncing') : context.tr('sync_btn_sync_now'),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    onPressed: _isProcessing
                        ? null
                        : () async {
                            final currentCtx = context;
                            setState(() => _isProcessing = true);
                            final success = await _syncService.processQueue(context: currentCtx);
                            if (mounted) {
                              setState(() => _isProcessing = false);
                              if (currentCtx.mounted) {
                                ScaffoldMessenger.of(currentCtx).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      success
                                          ? currentCtx.tr('sync_toast_synced')
                                          : currentCtx.tr('sync_toast_offline'),
                                    ),
                                    backgroundColor: success ? AppColors.success : AppColors.warning,
                                  ),
                                );
                              }
                            }
                          },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
