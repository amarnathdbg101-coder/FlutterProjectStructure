import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../controllers/quiz_controller.dart';
import '../models/quiz_model.dart';

class QuizListScreen extends StatefulWidget {
  final String? initialTopic;
  final String? noteId;

  const QuizListScreen({
    super.key,
    this.initialTopic,
    this.noteId,
  });

  @override
  State<QuizListScreen> createState() => _QuizListScreenState();
}

class _QuizListScreenState extends State<QuizListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<QuizController>().loadQuizzesAndProfile();
      if (widget.initialTopic != null && widget.initialTopic!.isNotEmpty) {
        _showGenerateQuizDialog(initialTopic: widget.initialTopic);
      }
    });
  }

  Future<void> _handleGenerateQuiz(String topic, String difficulty, int count) async {
    final controller = context.read<QuizController>();

    // Show progress dialog with academic status
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 20),
              const Text(
                'Generating Adaptive Quiz...',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Calibrating $count exam questions on "$topic" with LaTeX formulas, derivations, and traps.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      await controller.generateAndStartQuiz(
        topic: topic,
        noteId: widget.noteId,
        difficulty: difficulty,
        questionCount: count,
      );
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // dismiss loading dialog
        context.push('/quizzes/take');
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // dismiss loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Failed to generate quiz: $e'),
          ),
        );
      }
    }
  }

  void _showGenerateQuizDialog({String? initialTopic}) {
    final topicController = TextEditingController(text: initialTopic ?? '');
    String selectedDifficulty = 'adaptive';
    int questionCount = 5;

    final quickTopics = [
      'Thermodynamics',
      'Computer Architecture',
      'Operating Systems',
      'Data Structures',
      'Electromagnetism',
      'Linear Algebra',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.quiz_outlined, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Generate Adaptive Quiz', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: topicController,
                  decoration: const InputDecoration(
                    labelText: 'Quiz Topic *',
                    hintText: 'e.g. Thermodynamics, Computer Networks',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Quick Topic Suggestions:',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: quickTopics.map((t) {
                    return ActionChip(
                      label: Text(t, style: const TextStyle(fontSize: 11)),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        setDialogState(() {
                          topicController.text = t;
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: selectedDifficulty,
                  decoration: const InputDecoration(
                    labelText: 'Difficulty Level',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'adaptive', child: Text('Adaptive (Biased to Weak Areas)')),
                    DropdownMenuItem(value: 'easy', child: Text('Easy / Foundation')),
                    DropdownMenuItem(value: 'medium', child: Text('Medium / Standard')),
                    DropdownMenuItem(value: 'hard', child: Text('Hard / Advanced')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedDifficulty = val);
                  },
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Question Count:', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text('$questionCount Questions', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                  ],
                ),
                Slider(
                  value: questionCount.toDouble(),
                  min: 3,
                  max: 15,
                  divisions: 12,
                  label: '$questionCount',
                  onChanged: (val) {
                    setDialogState(() => questionCount = val.round());
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final topic = topicController.text.trim();
                if (topic.isEmpty) return;
                Navigator.pop(ctx);
                _handleGenerateQuiz(topic, selectedDifficulty, questionCount);
              },
              child: const Text('Generate & Start'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<QuizController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profile = controller.profile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quizzes & Cognitive Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => controller.loadQuizzesAndProfile(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showGenerateQuizDialog(),
        icon: const Icon(Icons.add),
        label: const Text('New Quiz'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Responsive.maxContentWidth(context)),
          child: SafeScrollable(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Cognitive Profile Header Card ---
                  _buildCognitiveProfileCard(profile, isDark),
                  const SizedBox(height: 24),

                  // --- Quizzes Section Header ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Practice Quizzes',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.auto_awesome, size: 16),
                        label: const Text('Adaptive Generator'),
                        onPressed: () => _showGenerateQuizDialog(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (controller.isLoading)
                    const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
                  else if (controller.quizzes.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.grey[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey[200]!),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.quiz_outlined, size: 48, color: AppColors.primary),
                          const SizedBox(height: 12),
                          const Text(
                            'No Quizzes Generated Yet',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Generate an adaptive quiz targeting your course topics and weak memory areas.',
                            style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text('Create First Quiz'),
                            onPressed: () => _showGenerateQuizDialog(),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: controller.quizzes.length,
                      separatorBuilder: (context, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final quiz = controller.quizzes[index];
                        return _buildQuizCard(quiz, controller, isDark);
                      },
                    ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCognitiveProfileCard(CognitiveProfileModel profile, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E1B4B), const Color(0xFF312E81)]
              : [const Color(0xFF4F46E5), const Color(0xFF3730A3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.psychology, color: Colors.white, size: 24),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Cognitive Memory Matrix',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_fire_department, color: Colors.orangeAccent, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${profile.studyStreakDays} Day Streak',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  label: 'Avg Score',
                  value: '${profile.averageQuizScore.toStringAsFixed(1)}%',
                  icon: Icons.trending_up,
                ),
              ),
              Container(width: 1, height: 40, color: Colors.white24),
              Expanded(
                child: _buildMetricTile(
                  label: 'Quizzes',
                  value: '${profile.totalQuizzesTaken}',
                  icon: Icons.checklist_rounded,
                ),
              ),
              Container(width: 1, height: 40, color: Colors.white24),
              Expanded(
                child: _buildMetricTile(
                  label: 'Target',
                  value: profile.targetExam,
                  icon: Icons.school,
                ),
              ),
            ],
          ),
          if (profile.weakTopics.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Identified Weak Areas (Adaptive AI Revision Bias):',
              style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: profile.weakTopics.map((topic) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 100),
                    child: Text(
                      topic,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricTile({required String label, required String value, required IconData icon}) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 10.5),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildQuizCard(QuizModel quiz, QuizController controller, bool isDark) {
    Color difficultyColor;
    switch (quiz.difficulty.toLowerCase()) {
      case 'easy':
        difficultyColor = AppColors.success;
        break;
      case 'hard':
        difficultyColor = AppColors.error;
        break;
      default:
        difficultyColor = AppColors.secondary;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: difficultyColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.timer_outlined, color: difficultyColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quiz.title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: difficultyColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        quiz.difficulty.toUpperCase(),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: difficultyColor),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${quiz.totalQuestions} Questions',
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              controller.startQuiz(quiz);
              context.push('/quizzes/take');
            },
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }
}
