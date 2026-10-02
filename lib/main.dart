import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/routes/app_router.dart';
import 'core/storage/token_storage.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/controllers/auth_controller.dart';
import 'features/health/controllers/health_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await TokenStorage.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthController()),
        ChangeNotifierProvider(create: (_) => HealthController()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Flutter Starter App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
      // Global Tap Outside to Dismiss Keyboard across all screens
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
