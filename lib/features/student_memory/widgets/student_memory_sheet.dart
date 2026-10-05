import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/widgets/custom_snackbar.dart';
import '../models/student_memory.dart';
import '../services/student_memory_service.dart';
import '../../ai_tutor/repositories/ai_tutor_repository.dart';
import '../../ai_tutor/widgets/formatted_ai_text.dart';

/// Modal bottom sheet allowing students to inspect, configure, and fine-tune
/// their AI Cognitive Memory, Target Exam Goals, Strengths, and Weak Points.
class StudentMemorySheet extends StatefulWidget {
  const StudentMemorySheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const StudentMemorySheet(),
    );
  }

  @override
  State<StudentMemorySheet> createState() => _StudentMemorySheetState();
}

class _StudentMemorySheetState extends State<StudentMemorySheet> with SingleTickerProviderStateMixin {
  final StudentMemoryService _memoryService = StudentMemoryService();
  final AiTutorRepository _aiRepo = AiTutorRepository();

  late TabController _tabController;
  final TextEditingController _weakInputController = TextEditingController();
  final TextEditingController _strongInputController = TextEditingController();

  StudentMemoryProfile? _profile;
  bool _isLoading = true;
  bool _isAddingWeak = false;
  bool _isAddingStrong = false;
  bool _isGeneratingRoadmap = false;
  String? _generatedRoadmap;

  final Map<String, List<String>> _examCategories = {
    'School & Boards': [
      'CBSE / Class 10 Boards',
      'CBSE / Class 12 Boards',
      'ICSE / ISC Boards',
      'State Board Exams',
    ],
    'Competitive Entrance': [
      'JEE (Main & Advanced)',
      'NEET Medical Entrance',
      'GATE Engineering Entrance',
      'CUET UG Entrance',
      'NDA / Defense Services',
    ],
    'College & Professional': [
      'University Semester Exams',
      'UPSC Civil Services',
      'Tech & Coding Interviews',
      'General Academic Studies',
    ],
  };

  // High-yield topic suggestions for quick one-tap tagging
  final List<String> _suggestedTopics = [
    'Thermodynamics',
    'Rotational Dynamics',
    'Electromagnetism',
    'Integral Calculus',
    'Organic Reaction Mechanisms',
    'Chemical Equilibrium',
    'Data Structures & Algorithms',
    'Probability & Statistics',
    'Newton Laws of Motion',
    'Wave Optics',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _weakInputController.dispose();
    _strongInputController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile({bool forceRemote = false}) async {
    final p = await _memoryService.getProfile(forceRemote: forceRemote);
    if (mounted) {
      setState(() {
        _profile = p;
        _isLoading = false;
      });
    }
  }

  Future<void> _addWeakTopicInline() async {
    final rawText = _weakInputController.text.trim();
    if (rawText.isEmpty) {
      CustomSnackbar.showInfo(context, 'Please enter a topic to add to Weak Areas');
      return;
    }

    final items = rawText
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (items.isEmpty) return;

    final currentWeak = _profile?.weakTopics ?? [];
    final newItems = items
        .where((it) => !currentWeak.any((w) => w.toLowerCase() == it.toLowerCase()))
        .toList();

    if (newItems.isEmpty) {
      CustomSnackbar.showInfo(context, 'All entered topic(s) are already tagged as weak areas');
      _weakInputController.clear();
      return;
    }

    _weakInputController.clear();
    setState(() {
      _isAddingWeak = true;
      // Optimistic update
      _profile = _profile?.copyWith(
        weakTopics: [...currentWeak, ...newItems],
        strongTopics: (_profile?.strongTopics ?? [])
            .where((s) => !newItems.any((it) => it.toLowerCase() == s.toLowerCase()))
            .toList(),
      );
    });

    try {
      final updated = await _memoryService.addWeakTopic(rawText);
      if (mounted) {
        setState(() {
          _profile = updated;
          _isAddingWeak = false;
        });
        CustomSnackbar.showSuccess(
          context,
          'Tagged ${newItems.join(", ")} to Weak Topics. AI Tutor will prioritize this!',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isAddingWeak = false);
        _loadProfile();
      }
    }
  }

  Future<void> _addStrongTopicInline() async {
    final rawText = _strongInputController.text.trim();
    if (rawText.isEmpty) {
      CustomSnackbar.showInfo(context, 'Please enter a topic to add to Mastered Concepts');
      return;
    }

    final items = rawText
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (items.isEmpty) return;

    final currentStrong = _profile?.strongTopics ?? [];
    final newItems = items
        .where((it) => !currentStrong.any((s) => s.toLowerCase() == it.toLowerCase()))
        .toList();

    if (newItems.isEmpty) {
      CustomSnackbar.showInfo(context, 'All entered topic(s) are already tagged as mastered');
      _strongInputController.clear();
      return;
    }

    _strongInputController.clear();
    setState(() {
      _isAddingStrong = true;
      // Optimistic update
      _profile = _profile?.copyWith(
        strongTopics: [...currentStrong, ...newItems],
        weakTopics: (_profile?.weakTopics ?? [])
            .where((w) => !newItems.any((it) => it.toLowerCase() == w.toLowerCase()))
            .toList(),
      );
    });

    try {
      final updated = await _memoryService.addStrongTopic(rawText);
      if (mounted) {
        setState(() {
          _profile = updated;
          _isAddingStrong = false;
        });
        CustomSnackbar.showSuccess(
          context,
          'Tagged ${newItems.join(", ")} to Mastered Concepts! 🚀',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isAddingStrong = false);
        _loadProfile();
      }
    }
  }

  Future<void> _removeWeakTopic(String topic) async {
    setState(() {
      _profile = _profile?.copyWith(
        weakTopics: (_profile?.weakTopics ?? [])
            .where((w) => w.toLowerCase() != topic.toLowerCase())
            .toList(),
      );
    });
    try {
      final updated = await _memoryService.removeWeakTopic(topic);
      if (mounted) setState(() => _profile = updated);
    } catch (_) {
      _loadProfile();
    }
  }

  Future<void> _removeStrongTopic(String topic) async {
    setState(() {
      _profile = _profile?.copyWith(
        strongTopics: (_profile?.strongTopics ?? [])
            .where((s) => s.toLowerCase() != topic.toLowerCase())
            .toList(),
      );
    });
    try {
      final updated = await _memoryService.removeStrongTopic(topic);
      if (mounted) setState(() => _profile = updated);
    } catch (_) {
      _loadProfile();
    }
  }

  Future<void> _moveToMastered(String topic) async {
    setState(() {
      _profile = _profile?.copyWith(
        weakTopics: (_profile?.weakTopics ?? [])
            .where((w) => w.toLowerCase() != topic.toLowerCase())
            .toList(),
        strongTopics: [...(_profile?.strongTopics ?? []), topic],
      );
    });
    try {
      final updated = await _memoryService.moveToMastered(topic);
      if (mounted) {
        setState(() => _profile = updated);
        CustomSnackbar.showSuccess(context, 'Moved "$topic" to Mastered Concepts! 🏆');
      }
    } catch (_) {
      _loadProfile();
    }
  }

  Future<void> _moveToWeak(String topic) async {
    setState(() {
      _profile = _profile?.copyWith(
        strongTopics: (_profile?.strongTopics ?? [])
            .where((s) => s.toLowerCase() != topic.toLowerCase())
            .toList(),
        weakTopics: [...(_profile?.weakTopics ?? []), topic],
      );
    });
    try {
      final updated = await _memoryService.moveToWeak(topic);
      if (mounted) {
        setState(() => _profile = updated);
        CustomSnackbar.showInfo(context, 'Moved "$topic" to Weak Topics for revision');
      }
    } catch (_) {
      _loadProfile();
    }
  }

  void _showEditGoalDialog() {
    final profile = _profile;
    if (profile == null) return;

    final textController = TextEditingController(text: profile.targetExam);
    String selectedLevel = profile.academicLevel;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;

          return Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
            padding: EdgeInsets.only(bottom: bottomInset),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.track_changes_rounded, color: Color(0xFF6366F1), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Edit Target Exam & Rigor',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      shrinkWrap: true,
                      children: [
                        Text(
                          'SELECT POPULAR TARGET',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 10),
                        ..._examCategories.entries.map((cat) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cat.key,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: cat.value.map((exam) {
                                    final isSel = textController.text.trim().toLowerCase() == exam.toLowerCase();
                                    return InkWell(
                                      onTap: () => setDlgState(() => textController.text = exam),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: isSel
                                              ? const Color(0xFF6366F1)
                                              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: isSel
                                                ? const Color(0xFF6366F1)
                                                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                          ),
                                        ),
                                        child: Text(
                                          exam,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                            color: isSel
                                                ? Colors.white
                                                : (isDark ? Colors.white70 : const Color(0xFF334155)),
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 10),
                        Text(
                          'OR ENTER CUSTOM TARGET',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: textController,
                          decoration: InputDecoration(
                            hintText: 'e.g. CAT Exam, SSC CGL, Olympiads',
                            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'ACADEMIC LEVEL / RIGOR',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Builder(
                          builder: (context) {
                            const validLevels = [
                              'School / College (Adaptive)',
                              'School / Foundation (Class 8-10)',
                              'Senior Secondary (Class 11-12)',
                              'Competitive Entrance (Rank Booster)',
                              'Undergraduate / College Degree',
                              'Advanced / Research Level',
                            ];
                            final safeValue = validLevels.contains(selectedLevel)
                                ? selectedLevel
                                : 'School / College (Adaptive)';

                            return DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: safeValue,
                              items: const [
                                DropdownMenuItem(
                                  value: 'School / College (Adaptive)',
                                  child: Text('School / College (Adaptive)'),
                                ),
                                DropdownMenuItem(
                                  value: 'School / Foundation (Class 8-10)',
                                  child: Text('School Foundation (Class 8-10)'),
                                ),
                                DropdownMenuItem(
                                  value: 'Senior Secondary (Class 11-12)',
                                  child: Text('Senior Secondary (Class 11-12)'),
                                ),
                                DropdownMenuItem(
                                  value: 'Competitive Entrance (Rank Booster)',
                                  child: Text('Competitive Entrance (Rank Booster)'),
                                ),
                                DropdownMenuItem(
                                  value: 'Undergraduate / College Degree',
                                  child: Text('Undergraduate / College Degree'),
                                ),
                                DropdownMenuItem(
                                  value: 'Advanced / Research Level',
                                  child: Text('Advanced / Research Level'),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) setDlgState(() => selectedLevel = val);
                              },
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6366F1),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: isSaving
                                ? null
                                : () async {
                                    final newExam = textController.text.trim();
                                    if (newExam.isNotEmpty) {
                                      setDlgState(() => isSaving = true);
                                      final updated = await _memoryService.updateExamTarget(
                                        targetExam: newExam,
                                        academicLevel: selectedLevel,
                                      );
                                      if (ctx.mounted) Navigator.pop(ctx);
                                      if (mounted) {
                                        setState(() => _profile = updated);
                                        CustomSnackbar.showSuccess(
                                          context,
                                          'Exam Target updated to "$newExam"',
                                        );
                                      }
                                    }
                                  },
                            child: isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Save & Apply to AI Tutor',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _generatePersonalizedRoadmap() async {
    final profile = _profile;
    if (profile == null || _isGeneratingRoadmap) return;

    setState(() {
      _isGeneratingRoadmap = true;
      _generatedRoadmap = null;
    });

    try {
      final weakList = profile.weakTopics.isNotEmpty
          ? profile.weakTopics.join(', ')
          : 'core foundational topics';
      final prompt = 'Generate a high-yield, structured 30-Day Personalized Study & Revision Roadmap '
          'for a student targeting "${profile.targetExam}" at "${profile.academicLevel}". '
          'Weak areas requiring highest priority: $weakList. '
          'Include daily milestones, high-yield formula review checkpoints, trap avoidance tips, and revision schedule.';

      final doubt = await _aiRepo.askDoubt(
        question: prompt,
        mode: 'pyqStrategist',
        targetExam: profile.targetExam,
        academicLevel: profile.academicLevel,
        weakTopics: profile.weakTopics,
      );

      if (mounted) {
        setState(() {
          _isGeneratingRoadmap = false;
          _generatedRoadmap = doubt.content;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGeneratingRoadmap = false);
        CustomSnackbar.showError(context, 'Failed to generate roadmap: $e');
      }
    }
  }

  void _copyRoadmap() {
    final roadmap = _generatedRoadmap;
    if (roadmap == null || roadmap.isEmpty) return;
    Clipboard.setData(ClipboardData(text: roadmap));
    CustomSnackbar.showSuccess(context, '✨ 30-Day AI Roadmap copied to clipboard!');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final weakCount = _profile?.weakTopics.length ?? 0;
    final strongCount = _profile?.strongTopics.length ?? 0;

    return Container(
      constraints: BoxConstraints(maxHeight: size.height * 0.90),
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Top Drag Handle
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

            // Header Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Cognitive Profile & Goals',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Calibrates AI Tutor answers to your syllabus & weak points',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    tooltip: 'Sync with Cloud DB',
                    onPressed: () async {
                      setState(() => _isLoading = true);
                      await _loadProfile(forceRemote: true);
                      if (mounted) {
                        CustomSnackbar.showSuccess(context, 'Synced with cognitive profile database');
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Segmented TabBar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: const Color(0xFF6366F1),
                  borderRadius: BorderRadius.circular(10),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                dividerColor: Colors.transparent,
                tabs: [
                  const Tab(text: 'Target & Rigor'),
                  Tab(
                    text: _profile != null
                        ? 'Mastery ($weakCount weak, $strongCount strong)'
                        : 'Mastery',
                  ),
                  const Tab(text: '30-Day Plan'),
                ],
              ),
            ),
            const Divider(height: 1),

            // Tab Views
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildTargetTab(isDark),
                        _buildMasteryTab(isDark),
                        _buildRoadmapTab(isDark),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // --- TAB 1: Target Exam & Rigor ---
  Widget _buildTargetTab(bool isDark) {
    final profile = _profile!;
    final readiness = profile.readinessScore;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current Target Box
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.school_rounded, color: Color(0xFF6366F1), size: 18),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'CURRENT TARGET EXAM',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: Color(0xFF6366F1),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    InkWell(
                      onTap: _showEditGoalDialog,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit_outlined, size: 13, color: Color(0xFF6366F1)),
                            SizedBox(width: 4),
                            Text(
                              'Change',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  profile.targetExam,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    profile.academicLevel,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Readiness Progress Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Exam Readiness Level',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '$readiness%',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: readiness / 100.0,
                    minHeight: 8,
                    backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // AI Calibration Info Box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 16, color: Color(0xFF6366F1)),
                    SizedBox(width: 8),
                    Text(
                      'How AI Tutor Calibrates to You',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '• Uses "${profile.targetExam}" curriculum standards & syllabus boundaries\n'
                  '• Emphasizes high-yield Previous Year Question (PYQ) patterns\n'
                  '• Automatically generates LaTeX equations & warns about common traps\n'
                  '• Prioritizes your tagged weak topics in adaptive quizzes and explanations',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 2: Mastery & Topics ---
  Widget _buildMasteryTab(bool isDark) {
    final profile = _profile!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: Weak Topics (Needs Drill)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFEF4444).withValues(alpha: 0.25),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFEF4444)),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'WEAK TOPICS & TRAP AREAS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: Color(0xFFEF4444),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${profile.weakTopics.length} tagged',
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFEF4444)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Inline Add Input for Weak Topic
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _weakInputController,
                        style: const TextStyle(fontSize: 12.5),
                        decoration: InputDecoration(
                          hintText: 'Add weak concept (e.g. Thermodynamics, Optics)...',
                          hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          ),
                        ),
                        onSubmitted: (_) => _addWeakTopicInline(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isAddingWeak ? null : _addWeakTopicInline,
                      child: _isAddingWeak
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Add', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (profile.weakTopics.isEmpty)
                  Text(
                    'No weak topics tagged yet. Add concepts above so AI Tutor drills them with priority.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      fontStyle: FontStyle.italic,
                    ),
                  )
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: profile.weakTopics.map((topic) {
                      return Chip(
                        backgroundColor: const Color(0xFFEF4444).withValues(alpha: isDark ? 0.2 : 0.08),
                        side: BorderSide(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                        avatar: InkWell(
                          onTap: () => _moveToMastered(topic),
                          child: const Icon(
                            Icons.check_circle_outline_rounded,
                            size: 16,
                            color: Color(0xFF10B981),
                          ),
                        ),
                        label: Tooltip(
                          message: 'Tap checkmark to mark Mastered, or (X) to remove',
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 140),
                            child: Text(
                              topic,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        deleteIcon: const Icon(Icons.close_rounded, size: 13),
                        onDeleted: () => _removeWeakTopic(topic),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Section 2: Mastered Concepts (Strengths)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.25),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.verified_rounded, size: 18, color: Color(0xFF10B981)),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'MASTERED CONCEPTS & STRENGTHS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: Color(0xFF10B981),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${profile.strongTopics.length} mastered',
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Inline Add Input for Strong Topic
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _strongInputController,
                        style: const TextStyle(fontSize: 12.5),
                        decoration: InputDecoration(
                          hintText: 'Add mastered concept (e.g. Newton Laws)...',
                          hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          ),
                        ),
                        onSubmitted: (_) => _addStrongTopicInline(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isAddingStrong ? null : _addStrongTopicInline,
                      child: _isAddingStrong
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Add', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (profile.strongTopics.isEmpty)
                  Text(
                    'Add topics where you feel confident. AI Tutor builds on these strengths.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      fontStyle: FontStyle.italic,
                    ),
                  )
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: profile.strongTopics.map((topic) {
                      return Chip(
                        backgroundColor: const Color(0xFF10B981).withValues(alpha: isDark ? 0.2 : 0.08),
                        side: BorderSide(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                        avatar: InkWell(
                          onTap: () => _moveToWeak(topic),
                          child: const Icon(
                            Icons.refresh_rounded,
                            size: 15,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                        label: Tooltip(
                          message: 'Tap refresh icon to move back to Weak Topics, or (X) to remove',
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 140),
                            child: Text(
                              topic,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        deleteIcon: const Icon(Icons.close_rounded, size: 13),
                        onDeleted: () => _removeStrongTopic(topic),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Section 3: Suggested Topics for 1-Tap Add
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.tips_and_updates_rounded, size: 16, color: Color(0xFF6366F1)),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        '1-TAP TOPIC SUGGESTIONS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: Color(0xFF6366F1),
                        ),
                      ),
                    ),
                    Text(
                      'Tap to add as Weak',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _suggestedTopics.where((sug) {
                    final existsInWeak = profile.weakTopics.any((w) => w.toLowerCase() == sug.toLowerCase());
                    final existsInStrong = profile.strongTopics.any((s) => s.toLowerCase() == sug.toLowerCase());
                    return !existsInWeak && !existsInStrong;
                  }).map((sug) {
                    return ActionChip(
                      avatar: const Icon(Icons.add, size: 14, color: Color(0xFF6366F1)),
                      label: Text(
                        sug,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                      side: BorderSide(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                      ),
                      onPressed: () async {
                        final updated = await _memoryService.addWeakTopic(sug);
                        if (mounted) {
                          setState(() => _profile = updated);
                          CustomSnackbar.showSuccess(context, 'Tagged "$sug" to Weak Topics');
                        }
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 3: 30-Day Plan ---
  Widget _buildRoadmapTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '30-Day Revision Roadmap',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
              if (_generatedRoadmap != null && _generatedRoadmap!.isNotEmpty)
                TextButton.icon(
                  onPressed: _copyRoadmap,
                  icon: const Icon(Icons.copy_rounded, size: 14),
                  label: const Text('Copy', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Synthesizes an exam revision schedule based on your weak topics and target curriculum.',
            style: TextStyle(
              fontSize: 11.5,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 14),

          if (_isGeneratingRoadmap)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                children: [
                  CircularProgressIndicator(strokeWidth: 2.5),
                  SizedBox(height: 16),
                  Text(
                    'AI is crafting your 30-Day Personalized Revision Plan...',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else if (_generatedRoadmap != null)
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: FormattedAiText(
                    text: _generatedRoadmap!,
                    isDark: isDark,
                    baseFontSize: 13,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _generatePersonalizedRoadmap,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Regenerate Roadmap', style: TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            )
          else
            InkWell(
              onTap: _generatePersonalizedRoadmap,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF6366F1).withValues(alpha: isDark ? 0.25 : 0.1),
                      const Color(0xFF8B5CF6).withValues(alpha: isDark ? 0.25 : 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.auto_awesome, color: Color(0xFF6366F1), size: 24),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Generate 30-Day Plan',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6366F1),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'AI-tailored study milestones & formula checkpoints',
                            style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF6366F1)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
