import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/widgets/custom_snackbar.dart';
import '../../../core/reuse/reuse.dart';
import '../controllers/cognitive_profile_controller.dart';
import '../widgets/cognitive_mastery_heatmap_card.dart';

/// Full-Screen AI Cognitive Brain & Mastery Hub
/// Live Readiness Gauge, Topic Mastery Grid, 1-Click AI Diagnostic, and Action Drills
class CognitiveHubScreen extends StatefulWidget {
  const CognitiveHubScreen({super.key});

  @override
  State<CognitiveHubScreen> createState() => _CognitiveHubScreenState();
}

class _CognitiveHubScreenState extends State<CognitiveHubScreen> with SingleTickerProviderStateMixin {
  late TabController _filterTabController;
  final TextEditingController _addTopicController = TextEditingController();
  bool _isAddingWeak = true;

  @override
  void initState() {
    super.initState();
    _filterTabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CognitiveProfileController>().loadProfile();
    });
  }

  @override
  void dispose() {
    _filterTabController.dispose();
    _addTopicController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final controller = context.watch<CognitiveProfileController>();

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        backgroundColor: AppColors.getSurface(isDark),
        elevation: 0,
        shape: Border(
          bottom: BorderSide(color: AppColors.getBorder(isDark), width: 1),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Cognitive Hub',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16.5,
                color: AppColors.getTextPrimary(isDark),
                letterSpacing: -0.3,
              ),
            ),
            Text(
              'Mastery Matrix & Exam Sprints',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: AppColors.getTextSecondary(isDark),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: controller.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded, size: 20),
            tooltip: 'Sync Profile',
            onPressed: () => controller.loadProfile(forceRemote: true),
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded, size: 20),
            tooltip: 'Configure Exam Target',
            onPressed: () => _showEditGoalsDialog(context, controller),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: controller.isLoading && controller.profile.weakTopics.isEmpty && controller.profile.strongTopics.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => controller.loadProfile(forceRemote: true),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Live Readiness Gauge & Key Academic Stats
                    _buildHeroReadinessCard(controller, isDark),
                    const SizedBox(height: 16),

                    // 2. 1-Click AI Knowledge Diagnostic Banner
                    _buildAiDiagnosticBanner(controller, isDark),
                    const SizedBox(height: 16),

                    // 3. Current Target Exam & Rigor Card
                    _buildExamTargetCard(controller, isDark),
                    const SizedBox(height: 16),

                    // 3.5. Cognitive Mastery Heatmap
                    CognitiveMasteryHeatmapCard(profile: controller.profile),
                    const SizedBox(height: 16),

                    // 4. Topic Mastery Matrix with 1-Click Action Drills
                    _buildTopicMasterySection(controller, isDark),
                    const SizedBox(height: 16),

                    // 5. Exam Traps & Tricky Pitfalls Watchlist
                    if (controller.examTraps.isNotEmpty) ...[
                      _buildExamTrapsSection(controller, isDark),
                      const SizedBox(height: 24),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. Hero Readiness Score & Metrics Card
  // ---------------------------------------------------------------------------
  Widget _buildHeroReadinessCard(CognitiveProfileController controller, bool isDark) {
    final score = controller.readinessScore;
    Color gaugeColor;
    String scoreStatus;

    if (score >= 80) {
      gaugeColor = const Color(0xFF10B981);
      scoreStatus = 'Exam Ready';
    } else if (score >= 60) {
      gaugeColor = const Color(0xFF3B82F6);
      scoreStatus = 'On Track';
    } else if (score >= 40) {
      gaugeColor = const Color(0xFFF59E0B);
      scoreStatus = 'Needs Focus';
    } else {
      gaugeColor = const Color(0xFFEF4444);
      scoreStatus = 'Action Required';
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: gaugeColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                // Animated Circular Readiness Gauge
                ReadinessGauge(
                  percentage: score,
                  size: 86,
                  strokeWidth: 7,
                ),
                const SizedBox(width: 20),

                // Title & Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI Readiness Score',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Calibrated against your doubts, quizzes, and mastery topics.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: gaugeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$scoreStatus • ${controller.weakTopics.length} Focus • ${controller.strongTopics.length} Mastered',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: gaugeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 28),

            // Metrics Row
            Row(
              children: [
                Expanded(child: _buildStatPill('Streak', '${controller.studyStreak}d', Colors.orange, isDark, Icons.bolt_rounded)),
                const SizedBox(width: 6),
                Expanded(child: _buildStatPill('Doubts', '${controller.doubtsAsked}', Colors.indigoAccent, isDark, Icons.psychology_rounded)),
                const SizedBox(width: 6),
                Expanded(child: _buildStatPill('Quizzes', '${controller.quizzesTaken}', Colors.teal, isDark, Icons.quiz_rounded)),
                const SizedBox(width: 6),
                Expanded(child: _buildStatPill('Avg Score', '${controller.avgScore.toStringAsFixed(0)}%', Colors.purpleAccent, isDark, Icons.analytics_rounded)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatPill(String label, String value, Color color, bool isDark, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.25 : 0.18),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. 1-Click AI Knowledge Diagnostic Banner
  // ---------------------------------------------------------------------------
  Widget _buildAiDiagnosticBanner(CognitiveProfileController controller, bool isDark) {
    final hasAiSummary = controller.aiSummary.isNotEmpty;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.blueAccent.withValues(alpha: 0.3),
        ),
      ),
      color: isDark ? const Color(0xFF172554) : const Color(0xFFEFF6FF),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.blueAccent, size: 22),
                const SizedBox(width: 8),
                const Text(
                  'AI Knowledge Diagnostic',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
                const Spacer(),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: Colors.blueAccent.withValues(alpha: 0.2),
                    foregroundColor: Colors.blueAccent,
                  ),
                  icon: controller.isDiagnosing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.bolt, size: 16),
                  label: Text(
                    controller.isDiagnosing ? 'Analyzing...' : 'Run Diagnostic',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  onPressed: controller.isDiagnosing
                      ? null
                      : () async {
                          final success = await controller.runDiagnosis();
                          if (mounted) {
                            if (success) {
                              CustomSnackbar.showSuccess(context, 'AI Diagnostic completed & synced!');
                            } else {
                              CustomSnackbar.showError(context, controller.errorMessage ?? 'Diagnosis failed');
                            }
                          }
                        },
                ),
              ],
            ),
            const SizedBox(height: 10),

            // AI Assessment Text
            Text(
              hasAiSummary
                  ? controller.aiSummary
                  : 'Tap "Run Diagnostic" to trigger deep AI analysis across your doubt queries and quiz mistakes.',
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: isDark ? Colors.blue[100] : const Color(0xFF1E3A8A),
              ),
            ),

            // Recommended Action Drills
            if (controller.recommendedActions.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'AI Priority Actions:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent,
                ),
              ),
              const SizedBox(height: 6),
              ...controller.recommendedActions.map(
                (act) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                      Expanded(
                        child: Text(
                          act,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[300] : Colors.grey[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Current Target Exam & Rigor Card
  // ---------------------------------------------------------------------------
  Widget _buildExamTargetCard(CognitiveProfileController controller, bool isDark) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
        ),
      ),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.purpleAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.school, color: Colors.purpleAccent, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    controller.profile.targetExam,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Academic Rigor: ${controller.profile.academicLevel}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              tooltip: 'Change Exam Goal',
              onPressed: () => _showEditGoalsDialog(context, controller),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. Topic Mastery Matrix with 1-Click Action Drills
  // ---------------------------------------------------------------------------
  Widget _buildTopicMasterySection(CognitiveProfileController controller, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Topic Mastery Matrix',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Topic'),
              onPressed: () => _showAddTopicDialog(context, controller),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Filter Tabs
        Container(
          height: 38,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.grey[200],
            borderRadius: BorderRadius.circular(10),
          ),
          child: TabBar(
            controller: _filterTabController,
            onTap: (_) => setState(() {}),
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(8),
            ),
            labelColor: Colors.white,
            unselectedLabelColor: isDark ? Colors.grey[400] : Colors.grey[700],
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            tabs: [
              Tab(text: 'Needs Focus (${controller.weakTopics.length})'),
              Tab(text: 'Mastered (${controller.strongTopics.length})'),
              const Tab(text: 'All Topics'),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Topic Cards List
        _buildFilteredTopicList(controller, isDark),
      ],
    );
  }

  Widget _buildFilteredTopicList(CognitiveProfileController controller, bool isDark) {
    List<MapEntry<String, bool>> displayedTopics = [];

    final tabIdx = _filterTabController.index;
    if (tabIdx == 0) {
      // Needs Focus
      for (final t in controller.weakTopics) {
        displayedTopics.add(MapEntry(t, false));
      }
    } else if (tabIdx == 1) {
      // Mastered
      for (final t in controller.strongTopics) {
        displayedTopics.add(MapEntry(t, true));
      }
    } else {
      // All Topics
      for (final t in controller.weakTopics) {
        displayedTopics.add(MapEntry(t, false));
      }
      for (final t in controller.strongTopics) {
        if (!controller.weakTopics.contains(t)) {
          displayedTopics.add(MapEntry(t, true));
        }
      }
    }

    if (displayedTopics.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            children: [
              Icon(Icons.checklist, size: 40, color: Colors.grey[400]),
              const SizedBox(height: 8),
              Text(
                tabIdx == 0 ? 'No weak topics identified! Great job.' : 'No topics added yet.',
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: displayedTopics.length,
      separatorBuilder: (ctx, idx) => const SizedBox(height: 8),
      itemBuilder: (ctx, index) {
        final entry = displayedTopics[index];
        final topic = entry.key;
        final isMastered = entry.value;
        final masteryVal = controller.topicMastery[topic] ?? (isMastered ? 85 : 35);

        return _buildTopicCard(controller, topic, isMastered, masteryVal, isDark);
      },
    );
  }

  Widget _buildTopicCard(
    CognitiveProfileController controller,
    String topic,
    bool isMastered,
    int mastery,
    bool isDark,
  ) {
    final statusColor = isMastered ? const Color(0xFF10B981) : const Color(0xFFF59E0B);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
      ),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isMastered ? Icons.check_circle : Icons.warning_amber_rounded,
                  color: statusColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    topic,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                AppPillBadge(
                  label: '$mastery% Mastery',
                  color: statusColor,
                  isDark: isDark,
                  fontSize: 10.5,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18),
                  onSelected: (val) {
                    if (val == 'promote') {
                      controller.promoteTopic(topic);
                    } else if (val == 'demote') {
                      controller.demoteTopic(topic);
                    } else if (val == 'delete') {
                      controller.deleteTopic(topic);
                    }
                  },
                  itemBuilder: (ctx) => [
                    if (!isMastered)
                      const PopupMenuItem(
                        value: 'promote',
                        child: Row(
                          children: [
                            Icon(Icons.check, color: Colors.green, size: 18),
                            SizedBox(width: 8),
                            Text('Mark as Mastered'),
                          ],
                        ),
                      )
                    else
                      const PopupMenuItem(
                        value: 'demote',
                        child: Row(
                          children: [
                            Icon(Icons.replay, color: Colors.orange, size: 18),
                            SizedBox(width: 8),
                            Text('Mark for Focus'),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: Colors.red, size: 18),
                          SizedBox(width: 8),
                          Text('Remove Topic'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Progress bar
            LinearProgressIndicator(
              value: (mastery / 100.0).clamp(0.0, 1.0),
              backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              borderRadius: BorderRadius.circular(4),
              minHeight: 5,
            ),
            const SizedBox(height: 10),

            // 1-Click Action Drills
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildActionChip(
                  icon: Icons.quiz_outlined,
                  label: 'Take Quiz',
                  color: Colors.blueAccent,
                  onTap: () {
                    context.push(AppRoutes.quizzes, extra: {'topic': topic});
                  },
                ),
                _buildActionChip(
                  icon: Icons.chat_bubble_outline,
                  label: 'Ask AI Doubt',
                  color: Colors.indigoAccent,
                  onTap: () {
                    context.push(
                      AppRoutes.aiChat,
                      extra: {
                        'initialQuery': 'Explain the core principles and tricky problems of $topic in depth.',
                        'topic': topic,
                      },
                    );
                  },
                ),
                _buildActionChip(
                  icon: Icons.hub_outlined,
                  label: 'Mind Map',
                  color: Colors.teal,
                  onTap: () {
                    context.push(AppRoutes.diagram, extra: {'topic': topic});
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 5. Exam Traps Watchlist Section
  // ---------------------------------------------------------------------------
  Widget _buildExamTrapsSection(CognitiveProfileController controller, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.shield_outlined, color: Colors.orangeAccent, size: 20),
            SizedBox(width: 8),
            Text(
              'Exam Traps & Pitfalls Watchlist',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Specific conceptual traps AI identified in your recent quiz submissions:',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 10),
        ...controller.examTraps.map(
          (trap) => Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.orangeAccent.withValues(alpha: 0.3)),
            ),
            color: isDark ? const Color(0xFF291B10) : const Color(0xFFFFFBEB),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      trap,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: isDark ? Colors.orange[100] : const Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Dialogs: Edit Goals & Add Topic
  // ---------------------------------------------------------------------------
  void _showEditGoalsDialog(BuildContext context, CognitiveProfileController controller) {
    final examCtrl = TextEditingController(text: controller.profile.targetExam);
    final levelCtrl = TextEditingController(text: controller.profile.academicLevel);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Target Exam & Rigor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: examCtrl,
              decoration: const InputDecoration(
                labelText: 'Target Exam / Standard',
                hintText: 'Target exam or certification name...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: levelCtrl,
              decoration: const InputDecoration(
                labelText: 'Academic Rigor Level',
                hintText: 'Academic level or grade...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final exam = examCtrl.text.trim();
              final lvl = levelCtrl.text.trim();
              if (exam.isNotEmpty && lvl.isNotEmpty) {
                controller.updateGoals(targetExam: exam, academicLevel: lvl);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save Goals'),
          ),
        ],
      ),
    );
  }

  void _showAddTopicDialog(BuildContext context, CognitiveProfileController controller) {
    _addTopicController.clear();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Topic to Matrix'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _addTopicController,
                decoration: const InputDecoration(
                  labelText: 'Topic Name',
                  hintText: 'Enter topic name to track...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Needs Focus'),
                      selected: _isAddingWeak,
                      onSelected: (val) {
                        setDialogState(() => _isAddingWeak = true);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Mastered'),
                      selected: !_isAddingWeak,
                      onSelected: (val) {
                        setDialogState(() => _isAddingWeak = false);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final topic = _addTopicController.text.trim();
                if (topic.isNotEmpty) {
                  controller.addCustomTopic(topic, isWeak: _isAddingWeak);
                }
                Navigator.pop(ctx);
              },
              child: const Text('Add Topic'),
            ),
          ],
        ),
      ),
    );
  }
}
