import 'package:flutter/material.dart';
import 'domain/safety_state_manager.dart';
import 'domain/emergency_session.dart';
import 'domain/session_storage_repository.dart';
import 'domain/onboarding_manager.dart';
import 'domain/firebase_auth_service.dart';
import 'domain/location_map_service.dart';
import 'domain/location_controller.dart';
import 'domain/evidence_controller.dart';
import 'domain/tamper_monitor.dart';
import 'presentation/onboarding_screen.dart';

class TelemetryInspectorScreen extends StatefulWidget {
  const TelemetryInspectorScreen({Key? key}) : super(key: key);

  @override
  State<TelemetryInspectorScreen> createState() => _TelemetryInspectorScreenState();
}

class _TelemetryInspectorScreenState extends State<TelemetryInspectorScreen> {
  String _mapProviderLabel = "OpenStreetMap Tile Stream";

  String _getStateLabel(SafetyState state) {
    switch (state) {
      case SafetyState.inactive:
        return "INACTIVE";
      case SafetyState.starting:
        return "STARTING";
      case SafetyState.active:
        return "ACTIVE";
      case SafetyState.escalated:
        return "ESCALATED";
      case SafetyState.terminating:
        return "TERMINATING";
    }
  }

  Color _getStateColor(SafetyState state) {
    switch (state) {
      case SafetyState.inactive:
        return Colors.grey;
      case SafetyState.starting:
      case SafetyState.terminating:
        return Colors.amber;
      case SafetyState.active:
        return Colors.greenAccent;
      case SafetyState.escalated:
        return Colors.redAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final safetyManager = SafetyStateManager.instance;
    final state = safetyManager.state;
    final session = safetyManager.activeSession;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Safety Engine Inspector"),
        backgroundColor: const Color(0xFF18181B),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Domain Safety State Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF18181B),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF27272A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Domain Safety State", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Chip(
                        label: Text(
                          _getStateLabel(state),
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                        backgroundColor: _getStateColor(state).withOpacity(0.3),
                        side: BorderSide(color: _getStateColor(state)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text("Active Session ID: ${session?.id ?? 'None (Standby)'}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text("Escalation Level: ${session?.escalationLevel ?? 0}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Live Location Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF18181B),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF27272A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Trusted Contact Location", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(_mapProviderLabel, style: const TextStyle(fontSize: 10, color: Colors.purpleAccent)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 160,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF09090B),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF27272A)),
                    ),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.location_on, color: Colors.redAccent, size: 36),
                          SizedBox(height: 6),
                          Text("Live OpenStreetMap GPS Tracking Stream", style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tamper Simulation Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF18181B),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF27272A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Tamper Detection Simulation", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                      onPressed: () {
                        TamperMonitorController.instance.handlePowerOffAttempt();
                        setState(() {});
                      },
                      icon: const Icon(Icons.power_settings_new),
                      label: const Text("Simulate Power-Off Attempt"),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[800]),
                      onPressed: () {
                        TamperMonitorController.instance.handleGpsDisabledTamper();
                        setState(() {});
                      },
                      icon: const Icon(Icons.location_off),
                      label: const Text("Simulate Turning Off GPS"),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}