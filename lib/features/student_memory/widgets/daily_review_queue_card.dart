import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../services/spaced_repetition_service.dart';
import 'spaced_review_session_sheet.dart';

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
    final reviewedToday = _service.reviewedTodayCount;

    // Collect unique topics due
    final topics = _dueItems.map((item) => item.card.topic).toSet().take(3).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: dueCount > 0
              ? [const Color(0xFF4F46E5), const Color(0xFF6366F1)]
              : [const Color(0xFF059669), const Color(0xFF10B981)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (dueCount > 0 ? const Color(0xFF4F46E5) : const Color(0xFF059669)).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _launchReviewSession,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Badge & Stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bolt, color: Colors.amber, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'SM-2 SPACCED REPETITION',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (reviewedToday > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '🎉 $reviewedToday reviewed today',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),

                // Main Due Text
                if (_isLoading)
                  const Row(
                    children: [
                      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                      SizedBox(width: 10),
                      Text('Calculating Memory Decay Curves...', style: TextStyle(color: Colors.white, fontSize: 13)),
                    ],
                  )
                else if (dueCount > 0) ...[
                  Text(
                    '⚡ $dueCount Cards Due Today',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    topics.isNotEmpty
                        ? 'Topics: ${topics.join(" • ")}'
                        : 'Review active recall cards before memory retention fades.',
                    style: const TextStyle(
                      color: Color(0xE6FFFFFF),
                      fontSize: 12.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ] else ...[
                  const Text(
                    '🎉 All Caught Up For Today!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Great job! All active recall cards are scheduled for future intervals.',
                    style: TextStyle(
                      color: Color(0xE6FFFFFF),
                      fontSize: 12,
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Primary Action Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: dueCount > 0 ? const Color(0xFF4F46E5) : const Color(0xFF059669),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    icon: Icon(dueCount > 0 ? Icons.play_arrow_rounded : Icons.history_edu_rounded, size: 20),
                    label: Text(
                      dueCount > 0 ? 'Start Review Queue ($dueCount)' : 'Practice Any Deck',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                    onPressed: _launchReviewSession,
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
