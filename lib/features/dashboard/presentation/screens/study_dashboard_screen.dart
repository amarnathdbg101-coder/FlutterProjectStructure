import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart' as legacy_provider;
import '../../../../core/routes/app_router.dart';
import '../../../../core/services/ai_language_service.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/custom_dialog.dart';
import '../../../auth/controllers/auth_controller.dart';
import '../../../student_memory/services/student_memory_service.dart';
import '../../../student_memory/services/smart_ai_context_helper.dart';
import '../../../student_memory/widgets/flashcard_deck_sheet.dart';
import '../../../student_memory/widgets/exam_study_planner_sheet.dart';
import '../../../student_memory/widgets/daily_review_queue_card.dart';
import '../../controllers/dashboard_controller.dart';
import '../widgets/omni_search_bar.dart';
import '../widgets/study_engine_card.dart';

class StudyDashboardScreen extends ConsumerStatefulWidget {
  const StudyDashboardScreen({super.key});

  @override
  ConsumerState<StudyDashboardScreen> createState() => _StudyDashboardScreenState();
}

class _StudyDashboardScreenState extends ConsumerState<StudyDashboardScreen> {
  final StudentMemoryService _memoryService = StudentMemoryService();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      context.read<AuthController>().fetchProfile();
      _loadStudentMemory();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStudentMemory() async {
    await _memoryService.getProfile();
  }

  Future<void> _logout() async {
    final confirm = await CustomDialog.confirm(
      context,
      title: 'Logout',
      message: 'Are you sure you want to log out of your StudySilo workspace?',
      confirmText: 'Logout',
      isDestructive: true,
    );

    if (confirm && mounted) {
      await context.read<AuthController>().logout();
      if (mounted) {
        context.go(AppRoutes.login);
      }
    }
  }

  void _submitSearch(String query) {
    final text = query.trim();
    if (text.isEmpty) return;
    _searchController.clear();
    ref.read(searchQueryProvider.notifier).clear();
    context.push(AppRoutes.aiChat, extra: {'initialQuery': text});
  }

  void _handleSuggestionTap(String suggestion) {
    if (suggestion.contains('Quiz')) {
      context.push(AppRoutes.quizzes);
    } else if (suggestion.contains('Concept Map')) {
      context.push(AppRoutes.diagram);
    } else if (suggestion.contains('Carnot')) {
      context.push(AppRoutes.aiChat, extra: {
        'initialQuery': 'Explain Carnot Engine cycle and efficiency formula step-by-step.'
      });
    } else {
      final cleanText = suggestion.replaceAll(RegExp(r'^\W+'), '').trim();
      context.push(AppRoutes.aiChat, extra: {
        'initialQuery': 'Explain $cleanText in detail with practical real-world examples and step-by-step breakdown.'
      });
    }
  }

  void _handleEngineNavigation(String route) {
    if (route == 'sheet:flashcards') {
      FlashcardDeckSheet.show(context);
    } else if (route == 'sheet:planner') {
      ExamStudyPlannerSheet.show(context);
    } else {
      context.push(route);
    }
  }

  Widget _buildDrawer(BuildContext context, String currentAiLang) {
    final auth = context.watch<AuthController>();
    final themeController = context.watch<ThemeController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final user = auth.currentUser;
    final userName = user?.name ?? TokenStorage.getUserName() ?? 'Scholar';
    final userEmail = user?.email ?? TokenStorage.getUserEmail() ?? '';

    return Drawer(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        userName.isNotEmpty ? userName[0].toUpperCase() : 'S',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          userName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (userEmail.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            userEmail,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Text(
                      'THEME & APPEARANCE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  _buildThemeTile(
                    title: 'Light Mode',
                    icon: Icons.light_mode_outlined,
                    isSelected: themeController.themeMode == ThemeMode.light,
                    onTap: () => themeController.setThemeMode(ThemeMode.light),
                    isDark: isDark,
                  ),
                  _buildThemeTile(
                    title: 'Dark Mode',
                    icon: Icons.dark_mode_outlined,
                    isSelected: themeController.themeMode == ThemeMode.dark,
                    onTap: () => themeController.setThemeMode(ThemeMode.dark),
                    isDark: isDark,
                  ),
                  _buildThemeTile(
                    title: 'System Default',
                    icon: Icons.brightness_auto_outlined,
                    isSelected: themeController.themeMode == ThemeMode.system,
                    onTap: () => themeController.setThemeMode(ThemeMode.system),
                    isDark: isDark,
                  ),

                  const Divider(height: 24),
                  ListTile(
                    leading: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 20),
                    title: const Text(
                      'Logout',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _logout();
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

  Widget _buildThemeTile({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: isSelected
            ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2FF))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(
          icon,
          size: 19,
          color: isSelected
              ? const Color(0xFF2563EB)
              : (isDark ? Colors.white70 : const Color(0xFF64748B)),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? const Color(0xFF2563EB)
                : (isDark ? Colors.white : const Color(0xFF0F172A)),
          ),
        ),
        trailing: isSelected
            ? const Icon(Icons.check_rounded, color: Color(0xFF2563EB), size: 17)
            : null,
        onTap: onTap,
      ),
    );
  }

  Widget _buildAILanguageSelector(BuildContext context, bool isDark, String currentLang) {
    final selectedOption = AILanguageService.getOption(currentLang);

    return PopupMenuButton<String>(
      tooltip: 'AI Response Language',
      elevation: 6,
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      position: PopupMenuPosition.under,
      onSelected: (String langId) {
        ref.read(aiLanguageProvider.notifier).selectLanguage(langId);
        final opt = AILanguageService.getOption(langId);
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Text(opt.icon, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    langId == 'auto'
                        ? 'AI will now automatically match your prompt language!'
                        : 'AI will now respond strictly in ${opt.name} across all features!',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF2563EB),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 3),
          ),
        );
      },
      itemBuilder: (BuildContext context) {
        return AILanguageService.supportedLanguages.map((opt) {
          final isSelected = opt.id.toLowerCase() == currentLang.toLowerCase();
          return PopupMenuItem<String>(
            value: opt.id,
            height: 48,
            child: Row(
              children: [
                Text(opt.icon, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        opt.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                          color: isSelected
                              ? const Color(0xFF2563EB)
                              : (isDark ? Colors.white : const Color(0xFF0F172A)),
                        ),
                      ),
                      Text(
                        opt.nativeName,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF2563EB)),
              ],
            ),
          );
        }).toList();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(selectedOption.icon, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 4),
            Text(
              selectedOption.name.split(' ').first,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 15,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final engines = ref.watch(studyEnginesProvider);
    final currentAiLang = ref.watch(aiLanguageProvider);
    final auth = context.watch<AuthController>();
    final user = auth.currentUser;
    final userName = user?.name ?? TokenStorage.getUserName() ?? 'Scholar';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F17) : const Color(0xFFF8FAFC),
      drawer: _buildDrawer(context, currentAiLang),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: Responsive.maxContentWidth(context)),
            child: RefreshIndicator(
              onRefresh: _loadStudentMemory,
              color: const Color(0xFF2563EB),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                slivers: [
                  // 1. Sleek Top Bar with brand icon, 1-tap theme switch and minimal streak counter
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Builder(
                                  builder: (ctx) => InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () => Scaffold.of(ctx).openDrawer(),
                                    child: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
                                        borderRadius: BorderRadius.circular(9),
                                        border: Border.all(
                                          color: isDark ? const Color(0xFF334155) : Colors.transparent,
                                        ),
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          Icons.menu_rounded,
                                          size: 19,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'StudySilo',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 16.5,
                                          fontWeight: FontWeight.w800,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          letterSpacing: -0.4,
                                        ),
                                      ),
                                      Text(
                                        'Academic Workspace',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w500,
                                          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                          letterSpacing: -0.1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildAILanguageSelector(context, isDark, currentAiLang),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 2. Clear Greeting & Omni Search Bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Hello, $userName',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Ready to learn today?',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        letterSpacing: -0.5,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Builder(
                                builder: (ctx) {
                                  final profile = StudentMemoryService.getCachedProfileSync();
                                  final targetExam = profile?.targetExam ?? 'Academic';
                                  final streak = profile?.studyStreakDays ?? 1;
                                  return InkWell(
                                    onTap: () => context.push(AppRoutes.cognitiveProfile),
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.16 : 0.08),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.35 : 0.2),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.bolt_rounded, size: 14, color: Color(0xFFF59E0B)),
                                          const SizedBox(width: 4),
                                          Text(
                                            '$streak d • $targetExam',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF2563EB),
                                              letterSpacing: -0.1,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Builder(
                            builder: (ctx) {
                              final profile = StudentMemoryService.getCachedProfileSync();
                              final dynamicTopics = SmartAiContextHelper.getSuggestedTopics(profile);
                              final dynamicSuggestions = [
                                '🎯 Adaptive Quiz',
                                '🗺️ Concept Mind Map',
                                ...dynamicTopics.take(3).map((t) => '⚡ $t'),
                              ];

                              return OmniSearchBar(
                                controller: _searchController,
                                isDark: isDark,
                                suggestions: dynamicSuggestions,
                                onChanged: (val) {
                                  ref.read(searchQueryProvider.notifier).setQuery(val);
                                },
                                onSubmitted: _submitSearch,
                                onSuggestionTap: _handleSuggestionTap,
                                onVoiceTap: () {
                                  context.push(AppRoutes.aiChat);
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 3. Daily Spaced Repetition Active Recall Queue
                  const SliverToBoxAdapter(
                    child: DailyReviewQueueCard(),
                  ),


                  // 4. Modules Section Title
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'AI STUDY ENGINES',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                letterSpacing: 0.8,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${engines.length} Modules',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 7. 2-Column Grid (Clean, square-proportioned modules without tag clutter)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: Responsive.isMobile(context)
                            ? (MediaQuery.of(context).textScaler.scale(1) > 1.05 ? 1.04 : 1.12)
                            : 1.30,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final item = engines[index];
                          return StudyEngineCard(
                            title: item.title,
                            description: item.description,
                            icon: item.icon,
                            badge: item.badge,
                            engineId: item.id,
                            isDark: isDark,
                            onTap: () => _handleEngineNavigation(item.route),
                          );
                        },
                        childCount: engines.length,
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
