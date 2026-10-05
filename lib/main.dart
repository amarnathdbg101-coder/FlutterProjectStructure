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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await TokenStorage.init();
  await HiveStorage.init();

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
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
      title: 'StudySilo.in - Autonomous AI Study Assistant',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeController.themeMode,
      routerConfig: appRouter,
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
