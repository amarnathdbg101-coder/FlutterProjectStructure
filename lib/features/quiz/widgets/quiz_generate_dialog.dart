import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../student_memory/services/student_memory_service.dart';

/// Clean, high-focus Generate Adaptive Quiz & Exam Dialog
class QuizGenerateDialog extends StatefulWidget {
  final String? initialTopic;
  final String? noteId;
  final String initialTestType;
  final Future<void> Function({
    required String topic,
    String? noteId,
    required String difficulty,
    required String testType,
    required int questionCount,
  }) onGenerate;

  const QuizGenerateDialog({
    super.key,
    this.initialTopic,
    this.noteId,
    this.initialTestType = 'mcq',
    required this.onGenerate,
  });

  static Future<void> show(
    BuildContext context, {
    String? initialTopic,
    String? noteId,
    String initialTestType = 'mcq',
    required Future<void> Function({
      required String topic,
      String? noteId,
      required String difficulty,
      required String testType,
      required int questionCount,
    }) onGenerate,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => QuizGenerateDialog(
        initialTopic: initialTopic,
        noteId: noteId,
        initialTestType: initialTestType,
        onGenerate: onGenerate,
      ),
    );
  }

  @override
  State<QuizGenerateDialog> createState() => _QuizGenerateDialogState();
}

class _QuizGenerateDialogState extends State<QuizGenerateDialog> {
  late final TextEditingController _topicController;
  late String _selectedTestType;
  String _selectedDifficulty = 'medium';
  int _questionCount = 5;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _topicController = TextEditingController(text: widget.initialTopic ?? '');
    _selectedTestType = widget.initialTestType;
  }

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: AppColors.getSurface(isDark),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.psychology_rounded, color: Color(0xFF2563EB), size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _isGenerating ? 'Designing Rigorous Exam...' : 'Create Academic Test',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: _isGenerating
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Color(0xFF2563EB), strokeWidth: 2.5),
                    const SizedBox(height: 18),
                    Text(
                      'AI is crafting $_questionCount $_selectedTestType questions with rigorous academic criteria for "${_topicController.text.trim()}"...',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _topicController,
                    style: TextStyle(fontSize: 14, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      labelText: 'Subject / Topic *',
                      hintText: 'e.g. Operating Systems, Thermodynamics',
                      prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF2563EB)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    autofocus: true,
                  ),
                  Builder(
                    builder: (context) {
                      final weak = StudentMemoryService.getCachedProfileSync()?.weakTopics ?? [];
                      if (weak.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Weak Topics to Reinforce:',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 5),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Row(
                                children: weak.map((t) {
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: InkWell(
                                      onTap: () {
                                        setState(() {
                                          _topicController.text = t;
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.bolt_rounded, size: 12, color: Color(0xFF2563EB)),
                                            const SizedBox(width: 4),
                                            Text(
                                              t,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF2563EB),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // 📝 Format Selector (MCQ vs Subjective vs Mixed)
                  Text(
                    'Test Format',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _buildFormatPill('mcq', 'MCQ', Icons.radio_button_checked_rounded, isDark),
                      const SizedBox(width: 8),
                      _buildFormatPill('subjective', 'Subjective', Icons.edit_note_rounded, isDark),
                      const SizedBox(width: 8),
                      _buildFormatPill('mixed', 'Mixed', Icons.shuffle_rounded, isDark),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 🎯 Difficulty Level
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _selectedDifficulty,
                    decoration: InputDecoration(
                      labelText: 'Difficulty Level',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'easy',
                        child: Text('🟢 Easy (Foundational Concepts)', overflow: TextOverflow.ellipsis),
                      ),
                      DropdownMenuItem(
                        value: 'medium',
                        child: Text('🟡 Medium (Multi-step & Application)', overflow: TextOverflow.ellipsis),
                      ),
                      DropdownMenuItem(
                        value: 'hard',
                        child: Text('🔴 Hard (Rigorous Derivations & Edge Cases)', overflow: TextOverflow.ellipsis),
                      ),
                      DropdownMenuItem(
                        value: 'adaptive',
                        child: Text('🔮 Adaptive (Reinforce Weak Areas)', overflow: TextOverflow.ellipsis),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedDifficulty = val);
                    },
                  ),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Question Count:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Text(
                        '$_questionCount Questions',
                        style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ],
                  ),
                  Slider(
                    value: _questionCount.toDouble(),
                    min: 3,
                    max: 15,
                    divisions: 12,
                    activeColor: const Color(0xFF2563EB),
                    label: '$_questionCount',
                    onChanged: (val) {
                      setState(() => _questionCount = val.round());
                    },
                  ),
                ],
              ),
      ),
      actions: _isGenerating
          ? null
          : [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('Start Test', style: TextStyle(fontWeight: FontWeight.w700)),
                onPressed: () async {
                  final topic = _topicController.text.trim();
                  if (topic.isEmpty) return;

                  setState(() => _isGenerating = true);
                  await widget.onGenerate(
                    topic: topic,
                    noteId: widget.noteId,
                    difficulty: _selectedDifficulty,
                    testType: _selectedTestType,
                    questionCount: _questionCount,
                  );
                },
              ),
            ],
    );
  }

  Widget _buildFormatPill(String type, String label, IconData icon, bool isDark) {
    final isSelected = _selectedTestType == type;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTestType = type),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF2563EB)
                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF2563EB)
                  : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF475569)),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF475569)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
