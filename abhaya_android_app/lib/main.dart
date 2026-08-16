import 'package:flutter/material.dart';
import 'domain/onboarding_manager.dart';
import 'domain/safety_state_manager.dart';
import 'domain/tamper_monitor.dart';
import 'presentation/onboarding_screen.dart';
import 'abhaya_modular_flutter_source_code-3.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Check whether user has already completed registration once
  final bool isRegistered = await OnboardingManager.instance.checkOnboardingStatus();
  
  // Initialize SafetyStateManager & TamperMonitor listeners
  await SafetyStateManager.instance.initialize();
  TamperMonitorController.instance.startListening();

  runApp(AbhayaApp(isRegistered: isRegistered));
}

class AbhayaApp extends StatelessWidget {
  final bool isRegistered;
  const AbhayaApp({super.key, required this.isRegistered});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calculator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF09090B),
        primaryColor: const Color(0xFF7C3AED),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF7C3AED),
          surface: Color(0xFF121214),
        ),
      ),
      home: isRegistered ? const MainNavigatorScreen() : const OnboardingScreen(),
    );
  }
}
