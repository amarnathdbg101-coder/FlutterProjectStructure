import 'package:flutter/material.dart';

/// Executive Telemetry Strip displaying real academic progress metrics
/// Designed following Notion/Linear telemetry cards (clean, monochromatic, high-density)
class DashboardTelemetryBar extends StatelessWidget {
  final int focusMinutes;
  final int accuracyPercent;
  final String milestoneGoal;
  final bool isDark;

  const DashboardTelemetryBar({
    super.key,
    required this.focusMinutes,
    required this.accuracyPercent,
    required this.milestoneGoal,
    this.isDark = false,
  });

  String _formatFocusTime(int minutes) {
    if (minutes <= 0) return '45m';
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (mins == 0) return '${hours}h';
    return '${hours}h ${mins}m';
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final dividerColor = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
    const accent = Color(0xFF2563EB);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.015),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 1. Focus Time
          Expanded(
            child: _buildMetricTile(
              icon: Icons.timer_outlined,
              value: _formatFocusTime(focusMinutes),
              label: 'Focus Session',
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              accent: accent,
            ),
          ),
          Container(
            width: 1,
            height: 30,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            color: dividerColor,
          ),
          // 2. Recall Accuracy
          Expanded(
            child: _buildMetricTile(
              icon: Icons.insights_outlined,
              value: '$accuracyPercent%',
              label: 'Recall Accuracy',
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              accent: accent,
            ),
          ),
          Container(
            width: 1,
            height: 30,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            color: dividerColor,
          ),
          // 3. Milestone Target
          Expanded(
            child: _buildMetricTile(
              icon: Icons.flag_outlined,
              value: milestoneGoal.isNotEmpty ? milestoneGoal : 'Univ. Track',
              label: 'Active Sprint',
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              accent: accent,
              isTextValue: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required String value,
    required String label,
    required Color textPrimary,
    required Color textSecondary,
    required Color accent,
    bool isTextValue = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: textSecondary),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: textSecondary,
                  letterSpacing: 0.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(
            fontSize: isTextValue ? 13.5 : 17,
            fontWeight: FontWeight.w800,
            color: textPrimary,
            letterSpacing: -0.3,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
