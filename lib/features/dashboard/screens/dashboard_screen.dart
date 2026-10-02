import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/widgets/custom_dialog.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../health/controllers/health_controller.dart';
import '../../health/widgets/backend_status_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HealthController>().checkConnection();
      context.read<AuthController>().fetchProfile();
    });
  }

  Future<void> _logout() async {
    final confirm = await CustomDialog.confirm(
      context,
      title: 'Logout',
      message: 'Are you sure you want to log out of your session?',
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.currentUser;
    final userName = user?.name ?? TokenStorage.getUserName() ?? 'Developer';
    final userEmail = user?.email ?? TokenStorage.getUserEmail() ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // User Greeting Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.white24,
                      child: Text(
                        userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hello, $userName! 👋',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (userEmail.isNotEmpty)
                            Text(
                              userEmail,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Role: ${user?.role.toUpperCase() ?? "USER"}',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Backend Live Status Card
          const Text(
            'Backend Connectivity',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const BackendStatusCard(),

          const SizedBox(height: 24),
          const Text(
            'Quick Starter Actions',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          _buildActionTile(
            icon: Icons.alt_route_rounded,
            title: 'Declarative GoRouter',
            subtitle: 'context.go(AppRoutes.login), context.push(...)',
            onTap: () {},
          ),
          const SizedBox(height: 10),
          _buildActionTile(
            icon: Icons.add_box_rounded,
            title: 'Scaffold New Domain',
            subtitle: 'Run .\\scripts\\generate-feature.bat <Name> in terminal',
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary, size: 22),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        onTap: onTap,
      ),
    );
  }
}
