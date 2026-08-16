import 'package:flutter/material.dart';
import 'abhaya_modular_flutter_source_code-3.dart';
import 'abhaya_modular_flutter_source_code-5.dart';
import 'domain/onboarding_manager.dart';
import 'domain/location_controller.dart';
import 'domain/evidence_controller.dart';
import 'domain/tamper_monitor.dart';
import 'presentation/onboarding_screen.dart';

class AbhayaApp extends StatefulWidget {
  const AbhayaApp({Key? key}) : super(key: key);

  @override
  State<AbhayaApp> createState() => _AbhayaAppState();
}

class _AbhayaAppState extends State<AbhayaApp> {
  bool _isLoading = true;
  bool _isOnboarded = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // 1. Start listening to Real-time Location Service lifecycle triggers
    RealtimeLocationController.instance.startListening();

    // 2. Start listening to Evidence Capture Subsystem lifecycle triggers
    EvidenceController.instance.startListening();

    // 3. Start listening to Tamper Detection & Signal Debouncer
    TamperMonitorController.instance.startListening();

    // 4. Auto-recover persistent active emergency session on app launch
    await SafetyStateManager.instance.initialize();

    // 5. Evaluate one-time onboarding status
    final bool onboarded = await OnboardingManager.instance.checkOnboardingStatus();

    if (mounted) {
      setState(() {
        _isOnboarded = onboarded;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ABHAYA — Calculator Disguised Safety App',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121214),
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C3AED),
          brightness: Brightness.dark,
        ),
      ),
      home: _isLoading
          ? const Scaffold(
              backgroundColor: Color(0xFF121214),
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFF7C3AED)),
              ),
            )
          : (_isOnboarded ? const MainNavigatorScreen() : const OnboardingScreen()),
    );
  }
}