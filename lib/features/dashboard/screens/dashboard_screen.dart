import 'package:flutter/material.dart';
import '../presentation/screens/study_dashboard_screen.dart';

export '../controllers/dashboard_controller.dart';
export '../models/study_engine_model.dart';
export '../presentation/screens/study_dashboard_screen.dart';
export '../presentation/widgets/active_sprint_card.dart';
export '../presentation/widgets/dashboard_telemetry_bar.dart';
export '../presentation/widgets/omni_search_bar.dart';
export '../presentation/widgets/study_engine_card.dart';

/// Legacy alias for StudyDashboardScreen so all router references work seamlessly
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const StudyDashboardScreen();
  }
}
