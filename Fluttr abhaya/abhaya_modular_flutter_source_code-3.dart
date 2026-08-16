import 'package:flutter/material.dart';
import 'abhaya_modular_flutter_source_code-4.dart';
import 'abhaya_modular_flutter_source_code-6.dart';

class MainNavigatorScreen extends StatefulWidget {
  const MainNavigatorScreen({Key? key}) : super(key: key);

  @override
  State<MainNavigatorScreen> createState() => _MainNavigatorScreenState();
}

class _MainNavigatorScreenState extends State<MainNavigatorScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const CalculatorScreen(),
    const TelemetryInspectorScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: const Color(0xFF18181B),
        indicatorColor: const Color(0xFF7C3AED).withOpacity(0.3),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calculate_outlined),
            selectedIcon: Icon(Icons.calculate, color: Color(0xFFC4B5FD)),
            label: 'Calculator',
          ),
          NavigationDestination(
            icon: Icon(Icons.shield_outlined),
            selectedIcon: Icon(Icons.shield, color: Color(0xFFC4B5FD)),
            label: 'Telemetry & SOS',
          ),
        ],
      ),
    );
  }
}