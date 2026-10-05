import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/custom_dialog.dart';
import '../../../core/reuse/reuse.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../student_memory/models/student_memory.dart';
import '../../student_memory/services/student_memory_service.dart';
import '../../student_memory/widgets/student_memory_sheet.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final StudentMemoryService _memoryService = StudentMemoryService();
  final TextEditingController _quickPromptController = TextEditingController();
  StudentMemoryProfile? _studentProfile;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthController>().fetchProfile();
      _loadStudentMemory();
    });
  }

  @override
  void dispose() {
    _quickPromptController.dispose();
    super.dispose();
  }

  Future<void> _loadStudentMemory() async {
    final profile = await _memoryService.getProfile();
    if (mounted) {
      setState(() {
        _studentProfile = profile;
      });
    }
  }

  Future<void> _logout() async {
    final confirm = await CustomDialog.confirm(
      context,
      title: 'Logout',
      message: 'Are you sure you want to log out of your AI Study Hub session?',
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

  void _submitQuickPrompt(String prompt) {
    final text = prompt.trim();
    if (text.isEmpty) return;
    _quickPromptController.clear();
    context.push(AppRoutes.aiChat, extra: {'initialQuery': text});
  }

  Widget _buildDrawer(BuildContext context) {
    final auth = context.watch<AuthController>();
    final themeController = context.watch<ThemeController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final user = auth.currentUser;
    final userName = user?.name ?? TokenStorage.getUserName() ?? 'AI Scholar';
    final userEmail = user?.email ?? TokenStorage.getUserEmail() ?? '';

    return Drawer(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.white,
                        child: CircleAvatar(
                          radius: 24,
                          backgroundColor: const Color(0xFFEEF2FF),
                          child: Text(
                            userName.isNotEmpty ? userName[0].toUpperCase() : 'S',
                            style: const TextStyle(
                              color: Color(0xFF4F46E5),
                              fontWeight: FontWeight.w800,
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
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (userEmail.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                userEmail,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xD9FFFFFF),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'ðŸ§  AI Scholar',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Navigation Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Text(
                      'AI STUDY SUITE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),

                  ListTile(
                    leading: const Icon(Icons.psychology_rounded, color: Color(0xFF4F46E5)),
                    title: const Text('AI Socratic Tutor', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('6 Pedagogical modes with KaTeX formulas', style: TextStyle(fontSize: 11)),
                    onTap: () {
                      Navigator.pop(context);
                      context.push(AppRoutes.aiChat);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.track_changes_rounded, color: Color(0xFF7C3AED)),
                    title: const Text('Target Exam & AI Memory', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Exam syllabus & weak topics personalization', style: TextStyle(fontSize: 11)),
                    onTap: () {
                      Navigator.pop(context);
                      StudentMemorySheet.show(context).then((_) => _loadStudentMemory());
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.quiz_rounded, color: Color(0xFFF59E0B)),
                    title: const Text('AI Active Recall Quizzes', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Adaptive question generation & scoring', style: TextStyle(fontSize: 11)),
                    onTap: () {
                      Navigator.pop(context);
                      context.push(AppRoutes.quizzes);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.account_tree_rounded, color: Color(0xFF0EA5E9)),
                    title: const Text('AI Concept Mind Maps', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Visual hierarchy & interactive diagram tree', style: TextStyle(fontSize: 11)),
                    onTap: () {
                      Navigator.pop(context);
                      context.push(AppRoutes.diagram);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.functions_rounded, color: Color(0xFF10B981)),
                    title: const Text('AI Formula & Equation Studio', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Instant LaTeX cheat sheets & SI variable legends', style: TextStyle(fontSize: 11)),
                    onTap: () {
                      Navigator.pop(context);
                      context.push(AppRoutes.formulaStudio);
                    },
                  ),

                  const Divider(height: 24),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Text(
                      'THEME & APPEARANCE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),

                  _buildThemeTile(
                    title: 'Light Mode',
                    icon: Icons.light_mode_rounded,
                    color: const Color(0xFFF59E0B),
                    isSelected: themeController.themeMode == ThemeMode.light,
                    onTap: () => themeController.setThemeMode(ThemeMode.light),
                  ),
                  _buildThemeTile(
                    title: 'Dark Mode',
                    icon: Icons.dark_mode_rounded,
                    color: const Color(0xFF6366F1),
                    isSelected: themeController.themeMode == ThemeMode.dark,
                    onTap: () => themeController.setThemeMode(ThemeMode.dark),
                  ),
                  _buildThemeTile(
                    title: 'System Default',
                    icon: Icons.brightness_auto_rounded,
                    color: const Color(0xFF10B981),
                    isSelected: themeController.themeMode == ThemeMode.system,
                    onTap: () => themeController.setThemeMode(ThemeMode.system),
                  ),

                  const Divider(height: 24),

                  ListTile(
                    leading: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
                    title: const Text(
                      'Logout',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
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
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2FF)) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(icon, color: color, size: 20),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        trailing: isSelected ? const Icon(Icons.check_rounded, color: Color(0xFF4F46E5), size: 18) : null,
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = context.watch<AuthController>();
    final user = auth.currentUser;
    final userName = user?.name ?? TokenStorage.getUserName() ?? 'Scholar';

    final targetExam = _studentProfile?.targetExam ?? 'General Academic Excellence';
    final readiness = _studentProfile?.readinessScore ?? 75;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      drawer: _buildDrawer(context),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0.5,
        titleSpacing: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: Icon(Icons.menu_rounded, color: isDark ? Colors.white : const Color(0xFF0F172A)),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text('StudySilo', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'AI HUB',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF4F46E5)),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Autonomous AI Study Companion',
                  style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ],
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadStudentMemory();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // --- Hero Greeting & Prompt Bar ---
            Container(
              padding: const EdgeInsets.all(18),
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
                            Text(
                              'Hello, $userName ðŸ§ ',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              '6 Pedagogical Modes â€¢ Voice Doubt â€¢ KaTeX Math',
                              style: TextStyle(
                                color: Color(0xD9FFFFFF),
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => StudentMemorySheet.show(context).then((_) => _loadStudentMemory()),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.track_changes_rounded, size: 14, color: Color(0xFF38BDF8)),
                              const SizedBox(width: 4),
                              Text(
                                '$readiness% Ready',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Quick AI Doubt Input Box
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(color: Color(0x1A000000), blurRadius: 10, offset: Offset(0, 3)),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _quickPromptController,
                            style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13.5),
                            decoration: const InputDecoration(
                              hintText: 'Ask any question, formula or theorem...',
                              hintStyle: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                              prefixIcon: Icon(Icons.search_rounded, color: Color(0xFF4F46E5), size: 20),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 12),
                            ),
                            onSubmitted: _submitQuickPrompt,
                          ),
                        ),
                        VoiceRecordButton(
                          isRecording: false,
                          size: 19,
                          tooltip: 'Ask via Voice Doubt',
                          onPressed: () {
                            context.push(AppRoutes.aiChat);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_forward_rounded, color: Color(0xFF4F46E5)),
                          onPressed: () => _submitQuickPrompt(_quickPromptController.text),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Target Exam Badge Bar
                  InkWell(
                    onTap: () => StudentMemorySheet.show(context).then((_) => _loadStudentMemory()),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.school_outlined, size: 14, color: Color(0xFF38BDF8)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Target: $targetExam',
                              style: const TextStyle(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Edit Goal âž”',
                            style: TextStyle(fontSize: 10.5, color: Color(0xFF38BDF8), fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (_studentProfile != null && _studentProfile!.weakTopics.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.psychology_rounded, size: 13, color: Color(0xFF38BDF8)),
                              const SizedBox(width: 4),
                              const Expanded(
                                child: Text(
                                  'AI Drill Priority (Weak Topics):',
                                  style: TextStyle(fontSize: 10.5, color: Color(0xD9FFFFFF), fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              InkWell(
                                onTap: () => StudentMemorySheet.show(context).then((_) => _loadStudentMemory()),
                                child: const Text(
                                  'Manage',
                                  style: TextStyle(fontSize: 10.5, color: Color(0xFF38BDF8), fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _studentProfile!.weakTopics.take(3).map((topic) {
                              return InkWell(
                                onTap: () => _submitQuickPrompt('Explain $topic thoroughly with key formulas and exam traps'),
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                                  ),
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 180),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            topic,
                                            style: const TextStyle(fontSize: 10.5, color: Colors.white, fontWeight: FontWeight.w600),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.arrow_forward_rounded, size: 10, color: Color(0xFF38BDF8)),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // --- The 4 Core AI Pillars Grid ---
            const Text(
              'AI STUDY ENGINES',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF94A3B8),
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildEngineCard(
                    title: 'AI Socratic Tutor',
                    subtitle: 'Step-by-step guidance & KaTeX equations',
                    badge: '6 Modes',
                    icon: Icons.psychology_rounded,
                    gradient: const [Color(0xFF4F46E5), Color(0xFF6366F1)],
                    onTap: () => context.push(AppRoutes.aiChat),
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildEngineCard(
                    title: 'AI Quizzes',
                    subtitle: 'Adaptive recall tests with evaluation',
                    badge: 'Adaptive',
                    icon: Icons.quiz_rounded,
                    gradient: const [Color(0xFFF59E0B), Color(0xFFD97706)],
                    onTap: () => context.push(AppRoutes.quizzes),
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildEngineCard(
                    title: 'AI Mind Maps',
                    subtitle: 'Visual concept trees & hierarchy',
                    badge: 'Interactive',
                    icon: Icons.account_tree_rounded,
                    gradient: const [Color(0xFF0EA5E9), Color(0xFF0284C7)],
                    onTap: () => context.push(AppRoutes.diagram),
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildEngineCard(
                    title: 'Formula Studio',
                    subtitle: 'LaTeX equation sheets & SI legends',
                    badge: 'KaTeX Ready',
                    icon: Icons.functions_rounded,
                    gradient: const [Color(0xFF10B981), Color(0xFF059669)],
                    onTap: () => context.push(AppRoutes.formulaStudio),
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildEngineCard({
    required String title,
    required String subtitle,
    required String badge,
    required IconData icon,
    required List<Color> gradient,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return AiActionCard(
      title: title,
      subtitle: subtitle,
      badge: badge,
      icon: icon,
      gradient: gradient,
      onTap: onTap,
      isDark: isDark,
    );
  }}
