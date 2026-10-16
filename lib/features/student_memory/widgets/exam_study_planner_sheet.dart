import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/widgets/custom_snackbar.dart';
import '../services/exam_planner_service.dart';
import 'flashcard_deck_sheet.dart';

/// Interactive AI Exam Study Planner & Spaced Repetition Roadmap Sheet
class ExamStudyPlannerSheet extends StatefulWidget {
  const ExamStudyPlannerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const ExamStudyPlannerSheet(),
    );
  }

  @override
  State<ExamStudyPlannerSheet> createState() => _ExamStudyPlannerSheetState();
}

class _ExamStudyPlannerSheetState extends State<ExamStudyPlannerSheet> {
  final ExamPlannerService _service = ExamPlannerService();
  late ExamStudyPlanModel _plan;
  bool _isGenerating = false;
  String _activeFilter = 'All'; // 'All', 'Pending', 'Completed', 'High Priority'

  // Focus Timer Session
  bool _isTimerActive = false;
  int _timerSecondsRemaining = 25 * 60; // 25 min default pomodoro
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _plan = _service.getPlan();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startFocusTimer() {
    setState(() {
      _isTimerActive = true;
      _timerSecondsRemaining = 25 * 60;
    });

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerSecondsRemaining > 0) {
        setState(() {
          _timerSecondsRemaining--;
        });
      } else {
        timer.cancel();
        setState(() {
          _isTimerActive = false;
        });
        _service.recordFocusMinutes(25);
        if (mounted) {
          CustomSnackbar.showSuccess(context, '🎉 Focus session finished! 25 minutes logged to your study streak.');
        }
      }
    });
  }

  void _stopFocusTimer() {
    _countdownTimer?.cancel();
    final elapsedMinutes = ((25 * 60) - _timerSecondsRemaining) ~/ 60;
    if (elapsedMinutes >= 1) {
      _service.recordFocusMinutes(elapsedMinutes);
      CustomSnackbar.showInfo(context, 'Logged $elapsedMinutes minutes of focused study time.');
    }
    setState(() {
      _isTimerActive = false;
      _timerSecondsRemaining = 25 * 60;
    });
  }

  Future<void> _pickExamDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _plan.examDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );

    if (picked != null) {
      final updated = _plan.copyWith(examDate: picked);
      setState(() => _plan = updated);
      await _service.savePlan(updated);
      if (mounted) {
        CustomSnackbar.showSuccess(context, 'Exam date updated!');
      }
    }
  }

  void _editExamName() {
    final controller = TextEditingController(text: _plan.examName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Target Exam Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter target exam or certification name...',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                final updated = _plan.copyWith(examName: newName);
                setState(() => _plan = updated);
                _service.savePlan(updated);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAiGeneratorDialog() {
    final examCtrl = TextEditingController(text: _plan.examName);
    final syllabusCtrl = TextEditingController(
      text: _plan.syllabusTopics.isNotEmpty
          ? _plan.syllabusTopics.join(', ')
          : 'Calculus, Thermodynamics, Operating Systems, Organic Chemistry',
    );
    double hours = _plan.dailyHoursGoal;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.auto_awesome, color: Color(0xFF4F46E5)),
                SizedBox(width: 8),
                Text('Generate AI Study Roadmap', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Target Exam Name:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: examCtrl,
                    decoration: InputDecoration(
                      hintText: 'Enter target exam name...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Syllabus / Subjects to Cover (comma-separated):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: syllabusCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Enter subjects, modules, or chapters to cover...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Daily Goal:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      Text('${hours.toInt()} hrs/day', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
                    ],
                  ),
                  Slider(
                    value: hours,
                    min: 1,
                    max: 12,
                    divisions: 11,
                    activeColor: const Color(0xFF4F46E5),
                    onChanged: (v) {
                      setDialogState(() => hours = v);
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
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.bolt, size: 16),
                label: const Text('Generate Roadmap', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                  final exam = examCtrl.text.trim();
                  final topics = syllabusCtrl.text
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList();

                  Navigator.pop(ctx);

                  if (exam.isNotEmpty && topics.isNotEmpty) {
                    _executeAiPlanGeneration(exam, topics, hours);
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _executeAiPlanGeneration(String exam, List<String> topics, double hours) async {
    setState(() => _isGenerating = true);
    try {
      final newPlan = await _service.generateAiPlan(
        examName: exam,
        examDate: _plan.examDate,
        syllabus: topics,
        dailyHours: hours,
      );
      if (!mounted) return;
      setState(() {
        _plan = newPlan;
        _isGenerating = false;
      });
      CustomSnackbar.showSuccess(context, 'Personalized AI Study Roadmap Generated! 🎯');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isGenerating = false);
      CustomSnackbar.showError(context, 'Failed to generate plan: $e');
    }
  }

  void _showAddCustomTaskDialog() {
    final titleCtrl = TextEditingController();
    final focusCtrl = TextEditingController(text: 'Core Concept & Practice');
    int dayNum = 1;
    String priority = 'high';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: const Text('Add Custom Study Goal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Task / Topic Title:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      hintText: 'Enter study task or milestone title...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  const Text('Focus Area:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: focusCtrl,
                    decoration: InputDecoration(
                      hintText: 'Enter focus area or subtopic...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Day Number:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<int>(
                              initialValue: dayNum,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                isDense: true,
                              ),
                              items: List.generate(30, (i) => i + 1)
                                  .map((d) => DropdownMenuItem(value: d, child: Text('Day $d')))
                                  .toList(),
                              onChanged: (v) => setDialogState(() => dayNum = v ?? 1),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Priority:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              initialValue: priority,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                isDense: true,
                              ),
                              items: const [
                                DropdownMenuItem(value: 'high', child: Text('High')),
                                DropdownMenuItem(value: 'medium', child: Text('Medium')),
                                DropdownMenuItem(value: 'low', child: Text('Low')),
                              ],
                              onChanged: (v) => setDialogState(() => priority = v ?? 'high'),
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
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  final t = titleCtrl.text.trim();
                  Navigator.pop(ctx);
                  if (t.isNotEmpty) {
                    final newTask = StudyPlanTaskModel(
                      id: 'custom-${DateTime.now().microsecondsSinceEpoch}',
                      dayNumber: dayNum,
                      title: t,
                      focusArea: focusCtrl.text.trim(),
                      priority: priority,
                      subtasks: const ['Complete active recall drill', 'Review formulas'],
                    );
                    _service.addTask(newTask).then((_) {
                      if (mounted) {
                        setState(() => _plan = _service.getPlan());
                      }
                    });
                  }
                },
                child: const Text('Add Task'),
              ),
            ],
          );
        },
      ),
    );
  }

  List<StudyPlanTaskModel> get _filteredTasks {
    switch (_activeFilter) {
      case 'Pending':
        return _plan.schedule.where((t) => !t.isCompleted).toList();
      case 'Completed':
        return _plan.schedule.where((t) => t.isCompleted).toList();
      case 'High Priority':
        return _plan.schedule.where((t) => t.priority.toLowerCase() == 'high').toList();
      default:
        return _plan.schedule;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final daysLeft = _plan.daysRemaining;
    final formattedDate = DateFormat('MMM dd, yyyy').format(_plan.examDate);
    final completionPct = (_plan.progressPercentage * 100).toInt();

    final timerMinutes = _timerSecondsRemaining ~/ 60;
    final timerSeconds = _timerSecondsRemaining % 60;
    final timerDisplay = '${timerMinutes.toString().padLeft(2, '0')}:${timerSeconds.toString().padLeft(2, '0')}';

    return Container(
      height: size.height * 0.90,
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
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.event_note_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI Exam Study & Spaced Roadmap',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${_plan.examName} • $daysLeft Days Left • $completionPct% Completed',
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

          // Main Scrollable Area
          Expanded(
            child: _isGenerating
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Color(0xFF4F46E5)),
                        SizedBox(height: 16),
                        Text('Designing Tailored Spaced Repetition Roadmap...', style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(height: 6),
                        Text('Calibrating high-yield formulas, PYQ traps & active recall milestones', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Hero Countdown Card
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF4F46E5), Color(0xFF3730A3)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x334F46E5),
                                blurRadius: 16,
                                offset: Offset(0, 6),
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
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                _plan.examName,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.edit_rounded, color: Colors.white70, size: 16),
                                              onPressed: _editExamName,
                                            ),
                                          ],
                                        ),
                                        Text(
                                          'Target Exam: $formattedDate ($daysLeft days to go)',
                                          style: const TextStyle(color: Color(0xD9FFFFFF), fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  InkWell(
                                    onTap: _pickExamDate,
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(Icons.calendar_month_rounded, size: 14, color: Colors.white),
                                          SizedBox(width: 4),
                                          Text('Change Date', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Progress Bar
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Roadmap Progress: ${_plan.completedTaskCount} of ${_plan.schedule.length} Goals',
                                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '$completionPct%',
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              LinearProgressIndicator(
                                value: _plan.progressPercentage,
                                backgroundColor: Colors.white24,
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                                minHeight: 6,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              const SizedBox(height: 16),

                              // Action Bar: Generate AI Plan + Focus Study Timer
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: const Color(0xFF4F46E5),
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      icon: const Icon(Icons.auto_awesome, size: 15),
                                      label: const Text('AI Re-Plan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      onPressed: _showAiGeneratorDialog,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        side: const BorderSide(color: Colors.white54),
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      icon: Icon(_isTimerActive ? Icons.stop_rounded : Icons.timer_outlined, size: 15),
                                      label: Text(
                                        _isTimerActive ? timerDisplay : '25m Focus Block',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      onPressed: () {
                                        if (_isTimerActive) {
                                          _stopFocusTimer();
                                        } else {
                                          _startFocusTimer();
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Filter Chips & Add Task Button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Text(
                                'Study Roadmap Goals',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: _showAddCustomTaskDialog,
                              icon: const Icon(Icons.add_task_rounded, size: 16),
                              label: const Text('Add Goal'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Filter Options
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: ['All', 'Pending', 'Completed', 'High Priority'].map((filter) {
                              final isSelected = _activeFilter == filter;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  selected: isSelected,
                                  label: Text(filter),
                                  labelStyle: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                  ),
                                  selectedColor: const Color(0xFF4F46E5),
                                  backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                  onSelected: (_) {
                                    setState(() => _activeFilter = filter);
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Tasks Timeline
                        if (_filteredTasks.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(28),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 40),
                                const SizedBox(height: 10),
                                Text(
                                  _activeFilter == 'Pending' ? 'All goals completed! Great work 🎉' : 'No tasks match filter',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            ),
                          )
                        else
                          ..._filteredTasks.map((task) => _buildTaskCard(task, isDark)),

                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(StudyPlanTaskModel task, bool isDark) {
    Color priorityColor;
    switch (task.priority.toLowerCase()) {
      case 'high':
        priorityColor = AppColors.error;
        break;
      case 'medium':
        priorityColor = AppColors.warning;
        break;
      default:
        priorityColor = AppColors.success;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: task.isCompleted
              ? const Color(0xFF10B981)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: task.isCompleted ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Badge Row: Day Number + Focus Area + Priority
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'DAY ${task.dayNumber}',
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: priorityColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    task.priority.toUpperCase(),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: priorityColor),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    task.focusArea,
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                  tooltip: 'Delete Task',
                  onPressed: () async {
                    await _service.deleteTask(task.id);
                    setState(() => _plan = _service.getPlan());
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Task Title with Checkbox
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: task.isCompleted,
                  activeColor: const Color(0xFF10B981),
                  onChanged: (val) async {
                    await _service.toggleTask(task.id, val ?? false);
                    setState(() => _plan = _service.getPlan());
                  },
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                        color: task.isCompleted
                            ? (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))
                            : (isDark ? Colors.white : const Color(0xFF0F172A)),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Subtasks
            if (task.subtasks.isNotEmpty) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: task.subtasks.map((sub) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ', style: TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold)),
                          Expanded(
                            child: Text(
                              sub,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.grey[300] : Colors.grey[700],
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
            const SizedBox(height: 12),

            // 1-Tap Action Handoffs: AI Tutor + Quiz + Formula Studio
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.psychology, size: 14, color: Color(0xFF4F46E5)),
                    label: const Text('Teach with AI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    backgroundColor: const Color(0xFF4F46E5).withValues(alpha: 0.08),
                    onPressed: () {
                      Navigator.pop(context);
                      context.push(AppRoutes.aiChat, extra: {
                        'initialQuery': 'Please teach and guide me step-by-step through this exam milestone:\n\nTask: ${task.title}\nFocus: ${task.focusArea}',
                        'noteTitle': task.title,
                      });
                    },
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.quiz_outlined, size: 14, color: Color(0xFF10B981)),
                    label: const Text('Practice Quiz', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.08),
                    onPressed: () {
                      Navigator.pop(context);
                      context.push(AppRoutes.quizzes, extra: {
                        'topic': task.title,
                        'title': task.title,
                      });
                    },
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.functions_rounded, size: 14, color: Color(0xFF0284C7)),
                    label: const Text('Formula Studio', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    backgroundColor: const Color(0xFF0284C7).withValues(alpha: 0.08),
                    onPressed: () {
                      Navigator.pop(context);
                      context.push(AppRoutes.formulaStudio, extra: {
                        'topic': task.title,
                      });
                    },
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.style_rounded, size: 14, color: Color(0xFF8B5CF6)),
                    label: const Text('3D Flashcards', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    backgroundColor: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                    onPressed: () {
                      Navigator.pop(context);
                      FlashcardDeckSheet.show(context, topic: task.title);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
