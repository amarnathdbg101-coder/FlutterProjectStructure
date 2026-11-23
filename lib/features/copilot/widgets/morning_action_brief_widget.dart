import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/localization/language_controller.dart';
import '../../../core/constants/app_colors.dart';
import '../controllers/copilot_controller.dart';
import '../models/copilot_model.dart';

/// Morning 3-Action Brief widget implementing the Cognitive Load Governor (CLG).
/// Gives the shopkeeper exactly 3 pre-calculated, 1-tap actionable decisions every morning.
class MorningActionBriefWidget extends StatefulWidget {
  const MorningActionBriefWidget({super.key});

  @override
  State<MorningActionBriefWidget> createState() => _MorningActionBriefWidgetState();
}

class _MorningActionBriefWidgetState extends State<MorningActionBriefWidget> {
  final Set<String> _executingIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final copilot = context.read<CopilotController>();
        if (copilot.prescriptions.isEmpty) {
          copilot.fetchDailyPrescriptions();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final copilot = context.watch<CopilotController>();
    final prescriptions = copilot.prescriptions;
    final isHindi = context.isHindi;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (prescriptions.isEmpty) {
      if (copilot.isLoading) {
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isHindi ? 'दुकान को-पायलट विश्लेषण लोड हो रहा है...' : 'Loading Store Co-Pilot analysis...',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
        );
      }

      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isHindi ? 'दुकान को-पायलट • सुबह के 3 जरूरी फैसले' : 'Store Co-Pilot • Morning 3-Actions',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isHindi
                        ? 'आज की बिक्री व स्टॉक का विश्लेषण तैयार करें'
                        : 'Generate today\'s velocity & stock action brief',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              onPressed: () => copilot.recalculateIntelligence(),
              child: Text(
                isHindi ? 'फैसले तैयार करें' : 'Generate Brief',
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }

    final activeCards = prescriptions.where((p) => !p.isExecuted).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isHindi ? 'दुकान को-पायलट • दैनिक 3 कार्य' : 'Store Co-Pilot • Morning 3-Actions',
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
                            ? 'निर्णय का तनाव खत्म: सिर्फ 1-टैप में फैसले लें'
                            : 'Zero decision fatigue: 1-Tap actionable decisions',
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: activeCards.isEmpty
                        ? const Color(0xFF10B981).withValues(alpha: 0.15)
                        : AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    activeCards.isEmpty
                        ? (isHindi ? 'सभी पूर्ण' : 'All Clear')
                        : '${activeCards.length} ${isHindi ? 'लंबित' : 'Pending'}',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: activeCards.isEmpty ? const Color(0xFF10B981) : AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Cards list
          if (activeCards.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isHindi
                          ? 'आज के सभी प्रमुख व्यापारिक निर्णय लागू हो चुके हैं!'
                          : 'All priority store decisions applied for today!',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              itemCount: activeCards.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final card = activeCards[index];
                return _PrescriptionItemTile(
                  card: card,
                  isExecuting: _executingIds.contains(card.id),
                  onExecute: () => _handleExecute(card),
                  onNavigate: () => _handleNavigate(card),
                );
              },
            ),
        ],
      ),
    );
  }

  Future<void> _handleExecute(DailyPrescriptionModel card) async {
    setState(() => _executingIds.add(card.id));
    final ok = await context.read<CopilotController>().executePrescription(card.id);
    if (mounted) {
      setState(() => _executingIds.remove(card.id));
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.isHindi ? 'कार्य सफलतापूर्वक लागू किया गया!' : 'Decision executed successfully!',
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    }
  }

  void _handleNavigate(DailyPrescriptionModel card) {
    if (card.category == 'DEAD_STOCK') {
      context.push('/merchant/inventory');
    } else if (card.category == 'REORDER') {
      context.push('/merchant/procurement');
    } else if (card.category == 'KHATA') {
      context.push('/merchant/khata');
    }
  }
}

class _PrescriptionItemTile extends StatelessWidget {
  final DailyPrescriptionModel card;
  final bool isExecuting;
  final VoidCallback onExecute;
  final VoidCallback onNavigate;

  const _PrescriptionItemTile({
    required this.card,
    required this.isExecuting,
    required this.onExecute,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final isHindi = context.isHindi;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color badgeColor;
    IconData badgeIcon;
    String badgeLabel;

    switch (card.urgencyTier) {
      case 'URGENT_CASH':
        badgeColor = const Color(0xFFEF4444);
        badgeIcon = Icons.savings_outlined;
        badgeLabel = isHindi ? 'अवरुद्ध नकदी' : 'Locked Cash';
        break;
      case 'STOCKOUT_CRITICAL':
        badgeColor = const Color(0xFFF59E0B);
        badgeIcon = Icons.inventory_2_outlined;
        badgeLabel = isHindi ? 'स्टॉकआउट चेतावनी' : 'Stockout Alert';
        break;
      default:
        badgeColor = const Color(0xFF3B82F6);
        badgeIcon = Icons.account_balance_wallet_outlined;
        badgeLabel = isHindi ? 'उधारी रिकवरी' : 'Khata Recovery';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(badgeIcon, color: badgeColor, size: 12),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          badgeLabel,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: badgeColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              if (card.financialImpactINR > 0)
                Text(
                  '₹${card.financialImpactINR.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            card.headline,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            card.explanation,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.35,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onNavigate,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Text(
                      isHindi ? 'विवरण देखें' : 'View Details',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              ElevatedButton(
                onPressed: isExecuting ? null : onExecute,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  minimumSize: const Size(0, 28),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                child: isExecuting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.flash_on_rounded, size: 13),
                          const SizedBox(width: 3),
                          Text(
                            isHindi ? 'लागू करें' : 'Apply Now',
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
