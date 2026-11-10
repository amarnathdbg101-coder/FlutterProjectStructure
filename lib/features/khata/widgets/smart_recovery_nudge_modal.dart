import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/whatsapp_share_helper.dart';
import '../../pos/controllers/ai_features_controller.dart';

class SmartRecoveryNudgeModal {
  static void show({
    required BuildContext context,
    required String customerName,
    required String customerPhone,
    required double totalDebt,
    int daysOverdue = 0,
    double dailyMicroAmount = 100.0,
  }) {
    // Generate AI Nudge immediately upon opening
    context.read<AIFeaturesController>().generateRecoveryNudge(
          customerName: customerName,
          customerPhone: customerPhone,
          totalDebt: totalDebt,
          daysOverdue: daysOverdue,
          dailyMicroAmount: dailyMicroAmount,
        );

    showDialog(
      context: context,
      builder: (dialogCtx) => Consumer<AIFeaturesController>(
        builder: (ctx, aiCtrl, _) {
          final nudge = aiCtrl.lastRecoveryNudge;
          final isGenerating = aiCtrl.isGeneratingNudge;

          Future<void> sendWhatsApp(String text) async {
            await WhatsAppShareHelper.shareToWhatsApp(
              context: dialogCtx,
              phone: customerPhone,
              message: text,
            );
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.psychology_rounded, color: AppColors.primary, size: 26),
                SizedBox(width: 8),
                Text('Smart WhatsApp Recovery Nudges', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI generates 3 psychology-based reminder scripts with dynamic UPI link for $customerName (Debt: ₹${totalDebt.toStringAsFixed(0)}):',
                      style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 16),

                    if (isGenerating) ...[
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 10),
                              Text('AI crafting respectful Hinglish payment reminders...', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ] else if (nudge != null) ...[
                      // 1. Gentle Nudge Card
                      _buildNudgeCard(
                        title: '🌟 Gentle & Respectful Nudge',
                        subtitle: 'Best for regular customers (0-15 days)',
                        badgeColor: const Color(0xFF16A34A),
                        message: nudge.gentleNudge,
                        onSend: () => sendWhatsApp(nudge.gentleNudge),
                      ),
                      const SizedBox(height: 12),

                      // 2. Micro-Plan Nudge Card
                      _buildNudgeCard(
                        title: '🪙 Micro-Plan Chillar Option',
                        subtitle: 'Invites daily ₹50-₹100 payments without pressure',
                        badgeColor: const Color(0xFF2563EB),
                        message: nudge.microPlanNudge,
                        onSend: () => sendWhatsApp(nudge.microPlanNudge),
                      ),
                      const SizedBox(height: 12),

                      // 3. Formal Statement Notice
                      _buildNudgeCard(
                        title: '⚖️ Formal Accounting Statement',
                        subtitle: 'Clear balance notice for overdue debts (>30 days)',
                        badgeColor: const Color(0xFFD97706),
                        message: nudge.formalNotice,
                        onSend: () => sendWhatsApp(nudge.formalNotice),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  aiCtrl.clearRecoveryNudge();
                  Navigator.pop(dialogCtx);
                },
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  static Widget _buildNudgeCard({
    required String title,
    required String subtitle,
    required Color badgeColor,
    required String message,
    required VoidCallback onSend,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle),
              ),
            ],
          ),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Text(
              message,
              style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 18, color: Color(0xFF64748B)),
                tooltip: 'Copy Message',
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: message));
                },
              ),
              const SizedBox(width: 6),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: onSend,
                icon: const Icon(Icons.send_rounded, size: 14),
                label: const Text('Send WhatsApp', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

