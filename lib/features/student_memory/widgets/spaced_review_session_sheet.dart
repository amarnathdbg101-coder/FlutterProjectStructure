import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_snackbar.dart';
import '../models/flashcard_model.dart';
import '../services/spaced_repetition_service.dart';
import 'flip_flashcard_widget.dart';

class SpacedReviewSessionSheet extends StatefulWidget {
  const SpacedReviewSessionSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const SpacedReviewSessionSheet(),
    );
  }

  @override
  State<SpacedReviewSessionSheet> createState() => _SpacedReviewSessionSheetState();
}

class _SpacedReviewSessionSheetState extends State<SpacedReviewSessionSheet> {
  final SpacedRepetitionService _service = SpacedRepetitionService();
  bool _isLoading = true;
  List<DueCardWithDeck> _queue = [];
  int _currentIndex = 0;
  int _sessionReviewedCount = 0;

  @override
  void initState() {
    super.initState();
    _loadSessionQueue();
  }

  Future<void> _loadSessionQueue() async {
    final due = await _service.getDueReviewCards();
    if (mounted) {
      setState(() {
        _queue = due;
        _isLoading = false;
      });
    }
  }

  Future<void> _rateCard(ReviewRating rating) async {
    if (_currentIndex >= _queue.length) return;

    final item = _queue[_currentIndex];
    await _service.submitReview(
      deck: item.deck,
      card: item.card,
      rating: rating,
    );

    setState(() {
      _sessionReviewedCount++;
      _currentIndex++;
    });

    if (_currentIndex >= _queue.length) {
      if (mounted) {
        CustomSnackbar.showSuccess(context, '🎉 Daily Active Recall Queue Completed!');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Container(
      height: size.height * 0.88,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.bolt, color: Color(0xFF4F46E5), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Daily Spaced Repetition Session',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _queue.isNotEmpty && _currentIndex < _queue.length
                            ? 'Card ${_currentIndex + 1} of ${_queue.length} • ${_queue[_currentIndex].card.topic}'
                            : 'Review Session Completed',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Progress Bar
          if (_queue.isNotEmpty)
            LinearProgressIndicator(
              value: (_currentIndex / _queue.length).clamp(0.0, 1.0),
              backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
              minHeight: 4,
            ),

          // Main Body
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)))
                : (_queue.isEmpty || _currentIndex >= _queue.length)
                    ? _buildCompletionView(isDark)
                    : Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Expanded(
                              child: KeyedSubtree(
                                key: ValueKey(_queue[_currentIndex].card.id),
                                child: FlipFlashcardWidget(
                                  flashcard: _queue[_currentIndex].card,
                                  isDark: isDark,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Rating Action Bar
                            const Text(
                              'How well did you recall this concept?',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                            ),
                            const SizedBox(height: 10),

                            Row(
                              children: [
                                Expanded(
                                  child: _buildRatingButton(
                                    label: 'Again',
                                    subtext: '1d',
                                    color: const Color(0xFFEF4444),
                                    onPressed: () => _rateCard(ReviewRating.again),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildRatingButton(
                                    label: 'Hard',
                                    subtext: '1.2x',
                                    color: const Color(0xFFF59E0B),
                                    onPressed: () => _rateCard(ReviewRating.hard),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildRatingButton(
                                    label: 'Good',
                                    subtext: '2.5x',
                                    color: const Color(0xFF10B981),
                                    onPressed: () => _rateCard(ReviewRating.good),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildRatingButton(
                                    label: 'Easy',
                                    subtext: '3.5x',
                                    color: const Color(0xFF3B82F6),
                                    onPressed: () => _rateCard(ReviewRating.easy),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingButton({
    required String label,
    required String subtext,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.12),
        foregroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withValues(alpha: 0.3)),
        ),
      ),
      onPressed: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
          const SizedBox(height: 2),
          Text(subtext, style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8))),
        ],
      ),
    );
  }

  Widget _buildCompletionView(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0x1F10B981),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 54),
            ),
            const SizedBox(height: 20),
            const Text(
              '🎉 Session Complete!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'You reviewed $_sessionReviewedCount active recall cards today. Your memory retention curves have been updated!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.done_all_rounded, size: 18),
              label: const Text('Back to Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
