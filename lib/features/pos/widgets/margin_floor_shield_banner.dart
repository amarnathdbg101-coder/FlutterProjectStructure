import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/hotkey_controller.dart';

class MarginFloorShieldBanner extends StatelessWidget {
  const MarginFloorShieldBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final hotkeyCtrl = context.watch<HotkeyController>();
    final marginResult = hotkeyCtrl.lastMarginCheck;

    if (marginResult == null) {
      return const SizedBox.shrink();
    }

    final isViolation = marginResult.criticalViolation || !marginResult.allowed;
    final isLowMargin = marginResult.netMarginPercentage < (marginResult.minFloorPercentage + 3.0);

    Color bg;
    Color border;
    Color textColor;
    IconData icon;
    String statusTitle;

    if (isViolation) {
      bg = const Color(0xFFFEF2F2);
      border = const Color(0xFFFCA5A5);
      textColor = const Color(0xFFDC2626);
      icon = Icons.gpp_bad_rounded;
      statusTitle = 'Margin Floor Violated (< ${marginResult.minFloorPercentage.toStringAsFixed(1)}%)';
    } else if (isLowMargin) {
      bg = const Color(0xFFFFFBEB);
      border = const Color(0xFFFCD34D);
      textColor = const Color(0xFFD97706);
      icon = Icons.warning_amber_rounded;
      statusTitle = 'Low Net Margin (${marginResult.netMarginPercentage.toStringAsFixed(1)}%)';
    } else {
      bg = const Color(0xFFF0FDF4);
      border = const Color(0xFF86EFAC);
      textColor = const Color(0xFF16A34A);
      icon = Icons.verified_user_rounded;
      statusTitle = 'Healthy Margin (${marginResult.netMarginPercentage.toStringAsFixed(1)}%)';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: textColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  statusTitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
              Text(
                'Profit: ₹${(marginResult.totalSale - marginResult.totalCost).toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ],
          ),
          if (marginResult.warnings.isNotEmpty) ...[
            const SizedBox(height: 4),
            ...marginResult.warnings.take(2).map(
                  (w) => Padding(
                    padding: const EdgeInsets.only(left: 26, top: 2),
                    child: Text(
                      '• $w',
                      style: TextStyle(fontSize: 10.5, color: textColor.withValues(alpha: 0.9)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}
