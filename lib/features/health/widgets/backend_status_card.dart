import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../controllers/health_controller.dart';

class BackendStatusCard extends StatelessWidget {
  const BackendStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    final health = context.watch<HealthController>();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: health.isConnected ? AppColors.success : AppColors.error,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    health.isConnected ? 'Go Backend: Online' : 'Go Backend: Offline',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: health.isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded, size: 20),
                onPressed: health.isLoading ? null : () => health.checkConnection(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Target: ${ApiConstants.baseUrl}',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          if (health.isConnected) ...[
            const SizedBox(height: 4),
            Text(
              'Database: ${health.databaseStatus} | Uptime: ${health.uptime}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ] else if (health.errorMessage != null) ...[
            const SizedBox(height: 4),
            Text(
              health.errorMessage!,
              style: const TextStyle(fontSize: 12, color: AppColors.error),
            ),
          ],
        ],
      ),
    );
  }
}
