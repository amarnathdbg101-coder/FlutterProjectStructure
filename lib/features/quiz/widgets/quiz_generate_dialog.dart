import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// Clean, high-focus Generate Adaptive Quiz Dialog
class QuizGenerateDialog extends StatefulWidget {
  final String? initialTopic;
  final String? noteId;
  final Future<void> Function({
    required String topic,
    String? noteId,
    required String difficulty,
    required int questionCount,
  }) onGenerate;

  const QuizGenerateDialog({
    super.key,
    this.initialTopic,
    this.noteId,
    required this.onGenerate,
  });

  static Future<void> show(
    BuildContext context, {
    String? initialTopic,
    String? noteId,
    required Future<void> Function({
      required String topic,
      String? noteId,
      required String difficulty,
      required int questionCount,
    }) onGenerate,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => QuizGenerateDialog(
        initialTopic: initialTopic,
        noteId: noteId,
        onGenerate: onGenerate,
      ),
    );
  }

  @override
  State<QuizGenerateDialog> createState() => _QuizGenerateDialogState();
}

class _QuizGenerateDialogState extends State<QuizGenerateDialog> {
  late final TextEditingController _topicController;
  String _selectedDifficulty = 'adaptive';
  int _questionCount = 5;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _topicController = TextEditingController(text: widget.initialTopic ?? '');
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
            child: const Icon(Icons.bolt_rounded, color: Color(0xFF2563EB), size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _isGenerating ? 'Calibrating Questions...' : 'Generate Adaptive Quiz',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
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
                      'Generating $_questionCount questions for "${_topicController.text.trim()}"...',
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
                      labelText: 'Quiz Topic *',
                      hintText: 'e.g. Branch Prediction, Thermodynamics',
                      prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF2563EB)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _selectedDifficulty,
                    decoration: InputDecoration(
                      labelText: 'Difficulty Level',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'adaptive',
                        child: Text(
                          '🔮 Adaptive (Biased to Weak Areas)',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'easy',
                        child: Text('🟢 Easy / Foundation', overflow: TextOverflow.ellipsis),
                      ),
                      DropdownMenuItem(
                        value: 'medium',
                        child: Text('🟡 Medium / Standard', overflow: TextOverflow.ellipsis),
                      ),
                      DropdownMenuItem(
                        value: 'hard',
                        child: Text('🔴 Hard / Advanced', overflow: TextOverflow.ellipsis),
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
                icon: const Icon(Icons.bolt_rounded, size: 16),
                label: const Text('Generate & Start', style: TextStyle(fontWeight: FontWeight.w700)),
                onPressed: () async {
                  final topic = _topicController.text.trim();
                  if (topic.isEmpty) return;

                  setState(() => _isGenerating = true);
                  await widget.onGenerate(
                    topic: topic,
                    noteId: widget.noteId,
                    difficulty: _selectedDifficulty,
                    questionCount: _questionCount,
                  );
                },
              ),
            ],
    );
  }
}
