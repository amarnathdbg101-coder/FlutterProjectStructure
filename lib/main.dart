import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as legacy_provider;
import 'core/routes/app_router.dart';
import 'core/storage/hive_storage.dart';
import 'core/storage/token_storage.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/ai_tutor/controllers/ai_tutor_controller.dart';
import 'features/auth/controllers/auth_controller.dart';
import 'features/diagram_viewer/controllers/diagram_controller.dart';
import 'features/health/controllers/health_controller.dart';
import 'features/quiz/controllers/quiz_controller.dart';
import 'core/services/ai_language_service.dart';
import 'features/student_memory/controllers/cognitive_profile_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await TokenStorage.init();
  await HiveStorage.init();
  await AILanguageService.init();

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return legacy_provider.MultiProvider(
      providers: [
        legacy_provider.ChangeNotifierProvider(create: (_) => ThemeController()),
        legacy_provider.ChangeNotifierProvider(create: (_) => AuthController()),
        legacy_provider.ChangeNotifierProvider(create: (_) => HealthController()),
        legacy_provider.ChangeNotifierProvider(create: (_) => AiTutorController()),
        legacy_provider.ChangeNotifierProvider(create: (_) => DiagramController()),
        legacy_provider.ChangeNotifierProvider(create: (_) => QuizController()),
        legacy_provider.ChangeNotifierProvider(create: (_) => CognitiveProfileController()),
      ],
      child: const StudySiloApp(),
    );
  }
}

class StudySiloApp extends StatelessWidget {
  const StudySiloApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();

    return MaterialApp.router(
      title: 'StudySilo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeController.themeMode,
      routerConfig: appRouter,
      scrollBehavior: AppScrollBehavior(),
      builder: (context, child) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: child,
        );
      },
    );
  }
}
