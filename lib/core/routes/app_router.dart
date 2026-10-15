import 'package:go_router/go_router.dart';
import '../../features/ai_tutor/screens/ai_tutor_chat_screen.dart';
import '../../features/ai_tutor/screens/formula_studio_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/diagram_viewer/screens/diagram_canvas_screen.dart';
import '../../features/quiz/screens/quiz_list_screen.dart';
import '../../features/quiz/screens/quiz_taker_screen.dart';
import '../../features/student_memory/screens/cognitive_hub_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String dashboard = '/dashboard';
  static const String aiChat = '/ai/chat';
  static const String diagram = '/diagram';
  static const String quizzes = '/quizzes';
  static const String quizTake = '/quizzes/take';
  static const String formulaStudio = '/formulas';
  static const String cognitiveProfile = '/profile/cognitive';
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.splash,
  routes: [
    GoRoute(
      path: AppRoutes.splash,
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: AppRoutes.login,
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: AppRoutes.register,
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: AppRoutes.dashboard,
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: AppRoutes.aiChat,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return AiTutorChatScreen(
          initialQuery: extra['initialQuery'] as String?,
          noteTitle: extra['noteTitle'] as String? ?? extra['topic'] as String?,
          noteContext: extra['noteContext'] as String?,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.diagram,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return DiagramCanvasScreen(
          initialTopic: extra['topic'] as String?,
          noteId: extra['noteId'] as String?,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.quizzes,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return QuizListScreen(
          initialTopic: extra['title'] as String? ?? extra['topic'] as String?,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.quizTake,
      builder: (context, state) => const QuizTakerScreen(),
    ),
    GoRoute(
      path: AppRoutes.formulaStudio,
      builder: (context, state) {
        String? topic;
        final extra = state.extra;
        if (extra is Map) {
          topic = extra['topic'] as String?;
        } else if (extra is String) {
          topic = extra;
        }
        return FormulaStudioScreen(initialTopic: topic);
      },
    ),
    GoRoute(
      path: AppRoutes.cognitiveProfile,
      builder: (context, state) => const CognitiveHubScreen(),
    ),
  ],
);
