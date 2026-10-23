import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/latex_sanitizer.dart';
import '../../../core/widgets/custom_snackbar.dart';
import '../../ai_tutor/widgets/formatted_ai_text.dart';
import '../models/exam_simulator_model.dart';
import '../services/exam_simulator_service.dart';
import '../widgets/exam_diagnostic_report_sheet.dart';

class ExamSimulatorScreen extends StatefulWidget {
  final MockExamModel exam;

  const ExamSimulatorScreen({
    super.key,
    required this.exam,
  });

  @override
  State<ExamSimulatorScreen> createState() => _ExamSimulatorScreenState();
}

class _ExamSimulatorScreenState extends State<ExamSimulatorScreen> {
  final ExamSimulatorService _simulatorService = ExamSimulatorService();

  late int _secondsRemaining;
  Timer? _countdownTimer;
  int _currentIndex = 0;

  final Map<int, int> _userAnswers = {}; // qIndex -> optionIndex
  final Set<int> _markedForReview = {};
  int _timeSpentSeconds = 0;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _secondsRemaining = widget.exam.durationMinutes * 60;
    _startTimer();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
          _timeSpentSeconds++;
        });
      } else {
        timer.cancel();
        _submitExam(isAutoTimeout: true);
      }
    });
  }

  void _submitExam({bool isAutoTimeout = false}) {
    if (_isSubmitting) return;
    _countdownTimer?.cancel();
    setState(() => _isSubmitting = true);

    final report = _simulatorService.evaluateDiagnosticReport(
      exam: widget.exam,
      userAnswers: _userAnswers,
      timeTakenSeconds: _timeSpentSeconds,
    );

    if (isAutoTimeout && mounted) {
      CustomSnackbar.showInfo(context, '⏰ Time expired! Test auto-submitted.');
    }

    if (mounted) {
      Navigator.pop(context); // Close simulator screen
      ExamDiagnosticReportSheet.show(context, report);
    }
  }

  void _showQuestionPalette() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Question Palette & Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 12),

              // Status Legend
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildLegendItem('Answered', const Color(0xFF10B981)),
                  _buildLegendItem('Unanswered', isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  _buildLegendItem('Review', const Color(0xFF8B5CF6)),
                ],
              ),
              const SizedBox(height: 16),

              // Grid Palette
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.2,
                ),
                itemCount: widget.exam.questions.length,
                itemBuilder: (context, idx) {
                  final isAnswered = _userAnswers.containsKey(idx) && _userAnswers[idx]! >= 0;
                  final isMarked = _markedForReview.contains(idx);
                  final isCurrent = _currentIndex == idx;

                  Color btnColor;
                  if (isMarked) {
                    btnColor = const Color(0xFF8B5CF6);
                  } else if (isAnswered) {
                    btnColor = const Color(0xFF10B981);
                  } else {
                    btnColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
                  }

                  return InkWell(
                    onTap: () {
                      setState(() => _currentIndex = idx);
                      Navigator.pop(ctx);
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: btnColor,
                        borderRadius: BorderRadius.circular(10),
                        border: isCurrent ? Border.all(color: Colors.amber, width: 2) : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Q${idx + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: (isAnswered || isMarked) ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final q = widget.exam.questions[_currentIndex];

    final minutes = _secondsRemaining ~/ 60;
    final seconds = _secondsRemaining % 60;
    final timerText = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    final isLowTime = _secondsRemaining <= 180;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 1,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.exam.title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${widget.exam.examType} • +${widget.exam.positiveMarking.toInt()} / -${widget.exam.negativeMarking.toInt()} Marking',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          // Countdown Timer
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isLowTime ? AppColors.error.withValues(alpha: 0.15) : const Color(0xFF4F46E5).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isLowTime ? AppColors.error : const Color(0xFF4F46E5)),
            ),
            child: Row(
              children: [
                Icon(Icons.timer_outlined, size: 14, color: isLowTime ? AppColors.error : const Color(0xFF4F46E5)),
                const SizedBox(width: 4),
                Text(
                  timerText,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                    color: isLowTime ? AppColors.error : const Color(0xFF4F46E5),
                  ),
                ),
              ],
            ),
          ),

          // Palette Trigger
          IconButton(
            icon: const Icon(Icons.grid_view_rounded),
            tooltip: 'Question Palette',
            onPressed: _showQuestionPalette,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Question Header Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Question ${_currentIndex + 1} of ${widget.exam.questions.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  if (_markedForReview.contains(_currentIndex))
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('Marked for Review', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6))),
                    ),
                ],
              ),
            ),

            // Question & Options Area
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Question Text Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: FormattedAiText(
                        text: q.questionText,
                        isDark: isDark,
                        baseFontSize: 14.5,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Options List
                    ...List.generate(q.options.length, (optIdx) {
                      final optionText = q.options[optIdx];
                      final isSelected = _userAnswers[_currentIndex] == optIdx;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF4F46E5).withValues(alpha: 0.12)
                              : (isDark ? const Color(0xFF1E293B) : Colors.white),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF4F46E5) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            width: isSelected ? 2.0 : 1.0,
                          ),
                        ),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _userAnswers[_currentIndex] = optIdx;
                            });
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected ? const Color(0xFF4F46E5) : Colors.transparent,
                                    border: Border.all(
                                      color: isSelected ? const Color(0xFF4F46E5) : Colors.grey,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: isSelected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: FormattedAiText(
                                    text: optionText,
                                    isDark: isDark,
                                    baseFontSize: 13.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

            // Bottom Navigation & Actions Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _userAnswers.remove(_currentIndex);
                      });
                    },
                    child: const Text('Clear', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () {
                      setState(() {
                        if (_markedForReview.contains(_currentIndex)) {
                          _markedForReview.remove(_currentIndex);
                        } else {
                          _markedForReview.add(_currentIndex);
                        }
                      });
                    },
                    child: Text(
                      _markedForReview.contains(_currentIndex) ? 'Unmark' : 'Review Later',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const Spacer(),

                  if (_currentIndex < widget.exam.questions.length - 1)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.arrow_forward, size: 16),
                      label: const Text('Save & Next'),
                      onPressed: () {
                        setState(() {
                          _currentIndex++;
                        });
                      },
                    )
                  else
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text('Submit Test'),
                      onPressed: () => _submitExam(isAutoTimeout: false),
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
