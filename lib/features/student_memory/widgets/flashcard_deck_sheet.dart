import 'package:flutter/material.dart';
import '../../../core/widgets/custom_snackbar.dart';
import '../models/flashcard_model.dart';
import '../services/flashcard_service.dart';
import 'flip_flashcard_widget.dart';

/// Full-Featured Spaced Repetition 3D Flashcard Deck Sheet with History & Flexible AI Generation
class FlashcardDeckSheet extends StatefulWidget {
  final String? initialTopic;
  final String? initialContent;
  final String? initialDeckId;

  const FlashcardDeckSheet({
    super.key,
    this.initialTopic,
    this.initialContent,
    this.initialDeckId,
  });

  static Future<void> show(
    BuildContext context, {
    String? topic,
    String? content,
    String? deckId,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FlashcardDeckSheet(
        initialTopic: topic,
        initialContent: content,
        initialDeckId: deckId,
      ),
    );
  }

  @override
  State<FlashcardDeckSheet> createState() => _FlashcardDeckSheetState();
}

class _FlashcardDeckSheetState extends State<FlashcardDeckSheet> {
  final FlashcardService _flashcardService = FlashcardService();

  FlashcardDeckModel? _currentDeck;
  List<FlashcardDeckModel> _historyDecks = [];
  int _currentIndex = 0;
  bool _isLoading = false;
  bool _isLoadingHistory = false;
  bool _showHistoryView = false;

  @override
  void initState() {
    super.initState();
    _initializeDeck();
  }

  Future<void> _initializeDeck() async {
    setState(() => _isLoading = true);

    if (widget.initialDeckId != null && widget.initialDeckId!.isNotEmpty) {
      final loaded = await _flashcardService.getDeck(widget.initialDeckId!);
      if (loaded != null && mounted) {
        setState(() {
          _currentDeck = loaded;
          _isLoading = false;
        });
        _loadHistory();
        return;
      }
    }

    final topic = widget.initialTopic ?? 'Operating Systems Deadlocks';
    final deck = await _flashcardService.generateDeck(
      topic: topic,
      content: widget.initialContent,
      cardCount: 5,
      difficulty: 'medium',
      saveDeck: true,
    );

    if (mounted) {
      setState(() {
        _currentDeck = deck;
        _isLoading = false;
      });
      _loadHistory();
    }
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoadingHistory = true);
    final list = await _flashcardService.listDecks();
    if (mounted) {
      setState(() {
        _historyDecks = list;
        _isLoadingHistory = false;
      });
    }
  }

  void _onEvaluateCard(String rating) {
    if (_currentDeck == null || _currentDeck!.cards.isEmpty) return;

    final cards = List<FlashcardModel>.from(_currentDeck!.cards);
    final card = cards[_currentIndex];

    final isMastered = rating == 'easy';
    cards[_currentIndex] = card.copyWith(
      difficulty: rating,
      isMastered: isMastered,
      isReviewed: true,
      lastReviewedAt: DateTime.now(),
    );

    final newMasteredCount = cards.where((c) => c.isMastered).length;
    final updatedDeck = _currentDeck!.copyWith(
      cards: cards,
      masteredCount: newMasteredCount,
      updatedAt: DateTime.now(),
    );

    setState(() {
      _currentDeck = updatedDeck;
    });

    _flashcardService.updateDeckProgress(updatedDeck);

    if (_currentIndex < cards.length - 1) {
      setState(() => _currentIndex++);
    } else {
      _showDeckCompletedDialog(newMasteredCount, cards.length);
    }
  }

  void _showDeckCompletedDialog(int mastered, int total) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.workspace_premium_rounded, color: Color(0xFFF59E0B)),
            SizedBox(width: 8),
            Text('Deck Completed! 🎯', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You mastered $mastered out of $total cards!'),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: total > 0 ? (mastered / total) : 0,
                minHeight: 8,
                backgroundColor: Colors.grey.withValues(alpha: 0.2),
                color: const Color(0xFF10B981),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${((mastered / (total > 0 ? total : 1)) * 100).toInt()}% Conceptual Retention',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _currentIndex = 0);
            },
            child: const Text('Restart Deck'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('New Deck'),
            onPressed: () {
              Navigator.pop(ctx);
              _showCreateDeckDialog();
            },
          ),
        ],
      ),
    );
  }

  void _showCreateDeckDialog() {
    final topicCtrl = TextEditingController(text: _currentDeck?.topic ?? '');
    final notesCtrl = TextEditingController();
    int cardCount = 5;
    String difficulty = 'medium';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.auto_awesome, color: Color(0xFF6366F1), size: 20),
                SizedBox(width: 8),
                Text('Generate AI 3D Deck', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Topic / Concept to Drill:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: topicCtrl,
                    decoration: InputDecoration(
                      hintText: 'Enter concept or topic to drill...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Optional Notes / Equations:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Paste excerpts from textbook or lecture...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Card Count:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      DropdownButton<int>(
                        value: cardCount,
                        items: [3, 5, 8, 10, 15]
                            .map((c) => DropdownMenuItem(value: c, child: Text('$c Cards')))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setDialogState(() => cardCount = v);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Exam Rigor Level:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildDifficultyChip('easy', '🟢 Fundamental', difficulty, (val) {
                          setDialogState(() => difficulty = val);
                        }),
                        const SizedBox(width: 6),
                        _buildDifficultyChip('medium', '🟡 Standard', difficulty, (val) {
                          setDialogState(() => difficulty = val);
                        }),
                        const SizedBox(width: 6),
                        _buildDifficultyChip('hard', '🔴 Exam Rigor', difficulty, (val) {
                          setDialogState(() => difficulty = val);
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.bolt, size: 16),
                label: const Text('Synthesize Deck'),
                onPressed: () {
                  final topic = topicCtrl.text.trim();
                  final notes = notesCtrl.text.trim();
                  Navigator.pop(ctx);
                  if (topic.isNotEmpty) {
                    _executeDeckGeneration(topic, notes.isNotEmpty ? notes : null, cardCount, difficulty);
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDifficultyChip(String value, String label, String current, ValueChanged<String> onSelected) {
    final isSelected = value == current;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : null)),
      selected: isSelected,
      selectedColor: const Color(0xFF6366F1),
      visualDensity: VisualDensity.compact,
      onSelected: (_) => onSelected(value),
    );
  }

  Future<void> _executeDeckGeneration(String topic, String? content, int count, String difficulty) async {
    setState(() {
      _isLoading = true;
      _showHistoryView = false;
    });

    try {
      final deck = await _flashcardService.generateDeck(
        topic: topic,
        content: content,
        cardCount: count,
        difficulty: difficulty,
        saveDeck: true,
      );

      if (!mounted) return;
      setState(() {
        _currentDeck = deck;
        _currentIndex = 0;
        _isLoading = false;
      });
      _loadHistory();
      CustomSnackbar.showSuccess(context, 'Synthesized ${deck.cards.length} active recall cards! ⚡');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      CustomSnackbar.showError(context, 'Failed to generate cards: $e');
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.style_rounded, color: Color(0xFF6366F1), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentDeck?.title ?? 'AI 3D Active Recall Flashcards',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _showHistoryView
                            ? 'Saved Flashcard Decks (${_historyDecks.length})'
                            : (_currentDeck != null && _currentDeck!.cards.isNotEmpty
                                ? 'Card ${_currentIndex + 1} of ${_currentDeck!.cards.length} • Spaced Repetition'
                                : 'Synthesizing Flashcards...'),
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),

                // History Toggle Button
                IconButton(
                  tooltip: _showHistoryView ? 'View Cards' : 'Saved Decks History',
                  icon: Icon(
                    _showHistoryView ? Icons.style_rounded : Icons.history_rounded,
                    color: const Color(0xFF6366F1),
                    size: 22,
                  ),
                  onPressed: () {
                    setState(() => _showHistoryView = !_showHistoryView);
                    if (_showHistoryView) _loadHistory();
                  },
                ),

                // New Deck Button
                IconButton(
                  tooltip: 'Create New Deck',
                  icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF4F46E5), size: 22),
                  onPressed: _showCreateDeckDialog,
                ),

                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Body Content (History View vs Active Deck View)
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(strokeWidth: 2.5),
                        SizedBox(height: 16),
                        Text(
                          'Synthesizing active recall cards with Gemini AI...',
                          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  )
                : _showHistoryView
                    ? _buildHistoryView(isDark)
                    : _buildActiveDeckView(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveDeckView(bool isDark) {
    if (_currentDeck == null || _currentDeck!.cards.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.layers_clear_rounded, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('No cards available in this deck'),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _showCreateDeckDialog,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create New Deck'),
            ),
          ],
        ),
      );
    }

    final cards = _currentDeck!.cards;
    final card = cards[_currentIndex];

    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          // Header Stats Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _currentDeck!.topic,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_outline_rounded, size: 14, color: Color(0xFF10B981)),
                  const SizedBox(width: 4),
                  Text(
                    '${_currentDeck!.masteredCount} / ${cards.length} Mastered',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Linear Progress Line
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_currentIndex + 1) / cards.length,
              backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              color: const Color(0xFF6366F1),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 18),

          // 3D Flip Card Widget
          Expanded(
            child: FlipFlashcardWidget(
              key: ValueKey(card.id),
              flashcard: card,
              isDark: isDark,
            ),
          ),
          const SizedBox(height: 18),

          // Active Recall Spaced Repetition Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.close_rounded, size: 15),
                  label: const Text('🔴 Hard', style: TextStyle(fontSize: 12)),
                  onPressed: () => _onEvaluateCard('hard'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.thumb_up_alt_rounded, size: 15),
                  label: const Text('🟡 Good', style: TextStyle(fontSize: 12)),
                  onPressed: () => _onEvaluateCard('medium'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.check_circle_rounded, size: 15),
                  label: const Text('🟢 Easy', style: TextStyle(fontSize: 12)),
                  onPressed: () => _onEvaluateCard('easy'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryView(bool isDark) {
    if (_isLoadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_historyDecks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.history_edu_rounded, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('No saved flashcard decks found.'),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _showCreateDeckDialog,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Generate First Deck'),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _historyDecks.length,
      separatorBuilder: (ctx, idx) => const SizedBox(height: 10),
      itemBuilder: (ctx, index) {
        final deck = _historyDecks[index];
        final isCurrent = deck.id == _currentDeck?.id;

        return Card(
          elevation: isCurrent ? 3 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: isCurrent ? const Color(0xFF6366F1) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              width: isCurrent ? 1.5 : 1,
            ),
          ),
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.15),
              child: const Icon(Icons.style_rounded, color: Color(0xFF6366F1), size: 20),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    deck.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                      color: isCurrent ? const Color(0xFF6366F1) : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isCurrent)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Active', style: TextStyle(fontSize: 9.5, color: Color(0xFF6366F1), fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  '${deck.topic} • ${deck.cardCount} Cards • ${deck.masteredCount} Mastered',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: deck.masteryPercentage,
                    minHeight: 4,
                    backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                    color: const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.grey, size: 20),
              onPressed: () async {
                await _flashcardService.deleteDeck(deck.id);
                _loadHistory();
              },
            ),
            onTap: () async {
              setState(() => _isLoading = true);
              final fullDeck = await _flashcardService.getDeck(deck.id) ?? deck;
              if (mounted) {
                setState(() {
                  _currentDeck = fullDeck;
                  _currentIndex = 0;
                  _showHistoryView = false;
                  _isLoading = false;
                });
              }
            },
          ),
        );
      },
    );
  }
}
