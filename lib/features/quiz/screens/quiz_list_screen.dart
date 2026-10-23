import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/custom_snackbar.dart';
import '../controllers/quiz_controller.dart';
import '../models/quiz_model.dart';
import '../models/exam_simulator_model.dart';
import '../services/exam_simulator_service.dart';
import '../widgets/quiz_card.dart';
import '../widgets/quiz_attempt_card.dart';
import '../widgets/quiz_generate_dialog.dart';
import 'exam_simulator_screen.dart';

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

class _QuizListScreenState extends State<QuizListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<QuizController>().loadQuizzesAndProfile();
      if (widget.initialTopic != null && widget.initialTopic!.isNotEmpty) {
        _openGenerateQuizDialog(initialTopic: widget.initialTopic);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openGenerateQuizDialog({String? initialTopic}) {
    QuizGenerateDialog.show(
      context,
      initialTopic: initialTopic,
      noteId: widget.noteId,
      onGenerate: ({
        required String topic,
        String? noteId,
        required String difficulty,
        required int questionCount,
      }) async {
        try {
          final controller = context.read<QuizController>();
          await controller.generateAndStartQuiz(
            topic: topic,
            noteId: noteId,
            difficulty: difficulty,
            questionCount: questionCount,
          );

          if (mounted) {
            Navigator.pop(context);
            context.push(AppRoutes.quizTake);
          }
        } catch (e) {
          if (mounted) {
            CustomSnackbar.showError(context, 'Failed to generate quiz: $e');
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<QuizController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profile = controller.profile;

    final filteredQuizzes = controller.quizzes.where((q) {
      if (_selectedFilter == 'all') return true;
      return q.difficulty.toLowerCase() == _selectedFilter;
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: AppColors.getSurface(isDark),
        elevation: 0,
        shape: Border(
          bottom: BorderSide(color: AppColors.getBorder(isDark), width: 1),
        ),
        title: const Text(
          'Adaptive Quizzes',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        actions: [
          IconButton(
            tooltip: 'Cognitive Brain Hub',
            icon: const Icon(Icons.psychology_outlined, size: 21),
            onPressed: () => context.push(AppRoutes.cognitiveProfile).then((_) {
              controller.loadQuizzesAndProfile();
            }),
          ),
          IconButton(
            tooltip: 'Refresh Quizzes',
            icon: const Icon(Icons.refresh_rounded, size: 21),
            onPressed: () => controller.loadQuizzesAndProfile(),
          ),
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF2563EB),
          unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          indicatorColor: const Color(0xFF2563EB),
          indicatorWeight: 2.5,
          tabs: [
            Tab(text: 'Available Quizzes (${controller.quizzes.length})'),
            Tab(text: 'Attempt History (${controller.attempts.length})'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openGenerateQuizDialog(),
        icon: const Icon(Icons.bolt_rounded, size: 20),
        label: const Text('Generate Quiz', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        elevation: 3,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Responsive.maxContentWidth(context)),
          child: TabBarView(
            controller: _tabController,
            children: [
              // Tab 1: Available Quizzes
              _buildQuizzesTab(controller, filteredQuizzes, profile, isDark),

              // Tab 2: Attempt History
              _buildAttemptsTab(controller, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuizzesTab(
    QuizController controller,
    List<QuizModel> filteredQuizzes,
    CognitiveProfileModel profile,
    bool isDark,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cognitive Memory Matrix Card (Clean Slate / Deep Indigo)
          _buildCognitiveProfileCard(profile, isDark),
          const SizedBox(height: 14),

          // Real AI Exam Simulator & Diagnostic Mock Tests
          _buildExamSimulatorCard(context, isDark),
          const SizedBox(height: 18),

          // Practice Quizzes Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'PRACTICE QUIZZES',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                '${filteredQuizzes.length} Available',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', 'all', isDark),
                const SizedBox(width: 6),
                _buildFilterChip('Adaptive', 'adaptive', isDark),
                const SizedBox(width: 6),
                _buildFilterChip('Easy', 'easy', isDark),
                const SizedBox(width: 6),
                _buildFilterChip('Medium', 'medium', isDark),
                const SizedBox(width: 6),
                _buildFilterChip('Hard', 'hard', isDark),
              ],
            ),
          ),
          const SizedBox(height: 14),

          if (controller.isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: Color(0xFF2563EB)),
              ),
            )
          else if (filteredQuizzes.isEmpty)
            _buildEmptyState(isDark)
          else
            Column(
              children: [
                for (int i = 0; i < filteredQuizzes.length; i++) ...[
                  QuizCard(
                    quiz: filteredQuizzes[i],
                    isDark: isDark,
                    onStart: () async {
                      await controller.startQuiz(filteredQuizzes[i]);
                      if (mounted) {
                        context.push(AppRoutes.quizTake);
                      }
                    },
                    onDelete: () async {
                      final ok = await controller.deleteQuiz(filteredQuizzes[i].id);
                      if (mounted && ok) {
                        CustomSnackbar.showSuccess(context, 'Quiz deleted');
                      }
                    },
                  ),
                  if (i < filteredQuizzes.length - 1) const SizedBox(height: 12),
                ],
              ],
            ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildAttemptsTab(QuizController controller, bool isDark) {
    if (controller.isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)));
    }

    if (controller.attempts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.history_rounded, size: 36, color: Color(0xFF2563EB)),
              ),
              const SizedBox(height: 16),
              Text(
                'No Attempts Yet',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Attempt a quiz to see diagnostic feedback and Bloom taxonomy scores here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: controller.attempts.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return QuizAttemptCard(
          attempt: controller.attempts[index],
          isDark: isDark,
        );
      },
    );
  }

  Widget _buildFilterChip(String label, String value, bool isDark) {
    final isSelected = _selectedFilter == value;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = value),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2563EB)
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF2563EB)
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected
                ? Colors.white
                : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  Widget _buildCognitiveProfileCard(CognitiveProfileModel profile, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.psychology_rounded, color: Color(0xFF2563EB), size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Memory & Diagnostic Profile',
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
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
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.getBorder(isDark)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_fire_department_rounded, color: Color(0xFFEA580C), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '${profile.studyStreakDays} Day Streak',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                      ),
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
                  icon: Icons.trending_up_rounded,
                  isDark: isDark,
                ),
              ),
              Container(width: 1, height: 32, color: AppColors.getBorder(isDark)),
              Expanded(
                child: _buildMetricTile(
                  label: 'Quizzes Taken',
                  value: '${profile.totalQuizzesTaken}',
                  icon: Icons.checklist_rounded,
                  isDark: isDark,
                ),
              ),
              Container(width: 1, height: 32, color: AppColors.getBorder(isDark)),
              Expanded(
                child: _buildMetricTile(
                  label: 'Target Goal',
                  value: profile.targetExam,
                  icon: Icons.school_rounded,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          if (profile.weakTopics.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Identified Weak Areas (Adaptive AI Revision Bias):',
              style: TextStyle(
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: profile.weakTopics.map((topic) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    topic,
                    style: const TextStyle(color: Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
    required bool isDark,
  }) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF2563EB), size: 17),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        Text(
          label,
          style: TextStyle(
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            fontSize: 10.5,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.getSurface(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.getBorder(isDark)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.quiz_outlined, size: 32, color: Color(0xFF2563EB)),
          ),
          const SizedBox(height: 14),
          Text(
            'No Quizzes Found',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Generate an adaptive quiz targeting your course topics and weak memory areas.',
            style: TextStyle(
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.bolt_rounded, size: 16),
            label: const Text('Generate First Quiz', style: TextStyle(fontWeight: FontWeight.w700)),
            onPressed: () => _openGenerateQuizDialog(),
          ),
        ],
      ),
    );
  }

  void _openExamSimulatorDialog() {
    final topicCtrl = TextEditingController(text: widget.initialTopic ?? 'Core Physics & Mathematics');
    String examType = 'JEE Main';
    int duration = 15;
    int questionCount = 5;
    bool isGenerating = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.timer_outlined, color: Color(0xFF4F46E5)),
                SizedBox(width: 8),
                Text('Launch AI Exam Simulator', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Syllabus Topic / Subject:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: topicCtrl,
                    decoration: InputDecoration(
                      hintText: 'Enter topic or subject for mock test...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),

                  const Text('Target Exam Pattern:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    value: examType,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'JEE Main', child: Text('JEE Main (+4 / -1 Marking)')),
                      DropdownMenuItem(value: 'NEET UG', child: Text('NEET UG (+4 / -1 Marking)')),
                      DropdownMenuItem(value: 'GATE CS', child: Text('GATE (+1 / -0.33 Marking)')),
                      DropdownMenuItem(value: 'University Midterm', child: Text('University (No Negative)')),
                    ],
                    onChanged: (v) => setDialogState(() => examType = v ?? 'JEE Main'),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Duration:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<int>(
                              value: duration,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                isDense: true,
                              ),
                              items: const [
                                DropdownMenuItem(value: 10, child: Text('10 mins')),
                                DropdownMenuItem(value: 15, child: Text('15 mins')),
                                DropdownMenuItem(value: 30, child: Text('30 mins')),
                                DropdownMenuItem(value: 60, child: Text('60 mins')),
                              ],
                              onChanged: (v) => setDialogState(() => duration = v ?? 15),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Questions:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<int>(
                              value: questionCount,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                isDense: true,
                              ),
                              items: const [
                                DropdownMenuItem(value: 5, child: Text('5 Questions')),
                                DropdownMenuItem(value: 10, child: Text('10 Questions')),
                                DropdownMenuItem(value: 15, child: Text('15 Questions')),
                              ],
                              onChanged: (v) => setDialogState(() => questionCount = v ?? 5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                ),
                icon: isGenerating ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.bolt, size: 16),
                label: Text(isGenerating ? 'Generating Exam...' : 'Start Mock Exam'),
                onPressed: isGenerating
                    ? null
                    : () async {
                        setDialogState(() => isGenerating = true);
                        final topic = topicCtrl.text.trim();

                        double pos = 4.0;
                        double neg = 1.0;
                        if (examType.contains('GATE')) {
                          pos = 1.0;
                          neg = 0.33;
                        } else if (examType.contains('University')) {
                          pos = 1.0;
                          neg = 0.0;
                        }

                        final exam = await ExamSimulatorService().generateMockExam(
                          topic: topic,
                          examType: examType,
                          durationMinutes: duration,
                          questionCount: questionCount,
                          positiveMarking: pos,
                          negativeMarking: neg,
                        );

                        if (context.mounted) {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => ExamSimulatorScreen(exam: exam)),
                          );
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildExamSimulatorCard(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF312E81), Color(0xFF4338CA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x2B312E81), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  children: [
                    Icon(Icons.bolt, color: Colors.amber, size: 14),
                    SizedBox(width: 4),
                    Text('REAL EXAM SIMULATOR', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  ],
                ),
              ),
              const Icon(Icons.timer_outlined, color: Colors.white, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          const Text('AI Exam Simulator & Diagnostic Mocks', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Timed conditions with negative marking (+4/-1 JEE, GATE, NEET) & AI Diagnostic Error Forensics.', style: TextStyle(color: Color(0xE6FFFFFF), fontSize: 12)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF312E81),
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              icon: const Icon(Icons.play_arrow_rounded, size: 20),
              label: const Text('Launch AI Exam Simulator', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              onPressed: _openExamSimulatorDialog,
            ),
          ),
        ],
      ),
    );
  }
}
