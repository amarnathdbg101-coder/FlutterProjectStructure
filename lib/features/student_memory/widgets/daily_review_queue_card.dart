import 'package:flutter/material.dart';
import '../services/spaced_repetition_service.dart';
import 'spaced_review_session_sheet.dart';

/// Compact & Luxury Active Recall Daily Queue Capsule
/// Features clean horizontal layout, subtle glassmorphic glow,
/// and instant 1-tap review trigger without consuming excessive vertical space.
class DailyReviewQueueCard extends StatefulWidget {
  const DailyReviewQueueCard({super.key});

  @override
  State<DailyReviewQueueCard> createState() => _DailyReviewQueueCardState();
}

class _DailyReviewQueueCardState extends State<DailyReviewQueueCard> {
  final SpacedRepetitionService _service = SpacedRepetitionService();
  bool _isLoading = true;
  List<DueCardWithDeck> _dueItems = [];

  @override
  void initState() {
    super.initState();
    _loadDueQueue();
    _service.addListener(_onQueueUpdated);
  }

  @override
  void dispose() {
    _service.removeListener(_onQueueUpdated);
    super.dispose();
  }

  void _onQueueUpdated() {
    if (mounted) {
      _loadDueQueue();
    }
  }

  Future<void> _loadDueQueue() async {
    final due = await _service.getDueReviewCards();
    if (mounted) {
      setState(() {
        _dueItems = due;
        _isLoading = false;
      });
    }
  }

  void _launchReviewSession() {
    SpacedReviewSessionSheet.show(context).then((_) => _loadDueQueue());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dueCount = _dueItems.length;

    const activeColor = Color(0xFF6366F1);
    const completeColor = Color(0xFF10B981);
    final themeColor = dueCount > 0 ? activeColor : completeColor;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: themeColor.withValues(alpha: isDark ? 0.35 : 0.22),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: themeColor.withValues(alpha: isDark ? 0.12 : 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.02),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _launchReviewSession,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Glowing Icon Avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        themeColor.withValues(alpha: isDark ? 0.25 : 0.14),
                        themeColor.withValues(alpha: isDark ? 0.10 : 0.04),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: themeColor.withValues(alpha: isDark ? 0.4 : 0.25),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: _isLoading
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: themeColor,
                            ),
                          )
                        : Icon(
                            dueCount > 0 ? Icons.bolt_rounded : Icons.check_circle_outline_rounded,
                            color: themeColor,
                            size: 22,
                          ),
                  ),
                ),
                const SizedBox(width: 13),

                // Title & Subtitle Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            dueCount > 0 ? '$dueCount Cards Due' : 'All Caught Up',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: themeColor.withValues(alpha: isDark ? 0.18 : 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'SM-2',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: themeColor,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        dueCount > 0
                            ? 'Review before forgetting curve decay'
                            : 'Daily spaced recall completed today',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Sleek Pill Button
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: themeColor,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: themeColor.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        dueCount > 0 ? Icons.play_arrow_rounded : Icons.replay_rounded,
                        size: 15,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        dueCount > 0 ? 'Review' : 'Practice',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
