import 'package:flutter/material.dart';
import '../domain/safety_state_manager.dart';
import '../domain/emergency_session.dart';
import '../domain/session_storage_repository.dart';
import '../domain/onboarding_manager.dart';
import '../domain/firebase_auth_service.dart';
import '../domain/location_map_service.dart';
import '../domain/location_controller.dart';
import '../domain/evidence_controller.dart';
import '../domain/tamper_monitor.dart';
import '../presentation/onboarding_screen.dart';

class TelemetryInspectorScreen extends StatefulWidget {
  const TelemetryInspectorScreen({Key? key}) : super(key: key);

  @override
  State<TelemetryInspectorScreen> createState() => _TelemetryInspectorScreenState();
}

class _TelemetryInspectorScreenState extends State<TelemetryInspectorScreen> {
  @override
  void initState() {
    super.initState();
    SafetyStateManager.instance.addListener(_onStateChanged);
    OnboardingManager.instance.addListener(_onStateChanged);
    RealtimeLocationController.instance.addListener(_onStateChanged);
    EvidenceController.instance.addListener(_onStateChanged);
    TamperMonitorController.instance.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    SafetyStateManager.instance.removeListener(_onStateChanged);
    OnboardingManager.instance.removeListener(_onStateChanged);
    RealtimeLocationController.instance.removeListener(_onStateChanged);
    EvidenceController.instance.removeListener(_onStateChanged);
    TamperMonitorController.instance.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    setState(() {});
  }

  String _getStateLabel(SafetyState state) {
    switch (state) {
      case SafetyState.inactive:
        return "INACTIVE (STANDBY)";
      case SafetyState.starting:
        return "STARTING SESSION...";
      case SafetyState.active:
        return "EMERGENCY ACTIVE";
      case SafetyState.escalated:
        return "CRITICAL ESCALATED";
      case SafetyState.terminating:
        return "TERMINATING SESSION...";
    }
  }

  Color _getStateColor(SafetyState state) {
    switch (state) {
      case SafetyState.inactive:
        return const Color(0xFF2E1065);
      case SafetyState.starting:
        return Colors.orangeAccent;
      case SafetyState.active:
        return Colors.redAccent;
      case SafetyState.escalated:
        return Colors.deepOrange;
      case SafetyState.terminating:
        return Colors.amber;
    }
  }

  @override
  Widget build(BuildContext context) {
    final SafetyState state = SafetyStateManager.instance.state;
    final EmergencySession? session = SafetyStateManager.instance.activeSession;
    final bool active = SafetyStateManager.instance.isEmergencyActive;
    final bool hasStorage = SessionStorageRepository.instance.hasCachedActiveSession;
    final user = FirebaseAuthService.instance.currentUser;
    final locationCtrl = RealtimeLocationController.instance;
    final evidenceCtrl = EvidenceController.instance;
    final tamperCtrl = TamperMonitorController.instance;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Background Telemetry Inspector', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: ListView(
          children: [
            // Domain Safety State Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF18181B),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF27272A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.between,
                    children: [
                      const Text("Domain Safety State", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Chip(
                        label: Text(
                          _getStateLabel(state),
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                        backgroundColor: _getStateColor(state),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (session != null) ...[
                    Text("Session ID: ${session.id}", style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.amber)),
                    const SizedBox(height: 4),
                    Text("User ID: ${session.userId}", style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text("Started At: ${session.startTime.toLocal().toString().split('.').first}", style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text("Escalation Level: ${session.escalationLevel}", style: TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.bold, color: session.escalationLevel > 0 ? Colors.deepOrange : Colors.greenAccent)),
                    const SizedBox(height: 4),
                    Text("Disk Sync: ${hasStorage ? 'PERSISTED & RECOVERABLE' : 'MEM_ONLY'}", style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: hasStorage ? Colors.cyanAccent : Colors.grey)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStatusBadge("GPS", session.locationStatus),
                        _buildStatusBadge("SOS", session.notificationStatus),
                        _buildStatusBadge("Cam/Mic", session.evidenceStatus),
                        _buildStatusBadge("Tamper", session.tamperStatus),
                      ],
                    ),
                  ] else ...[
                    const Text("GPS Coordinate Broadcast: Standby", style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 8),
                    const Text(
                      "Status: Armed (Awaiting covert trigger)",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Tamper Detection & Critical Escalation Subsystem Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF18181B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF27272A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.between,
                    children: [
                      const Text("Tamper Detection Subsystem", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.deepOrangeAccent)),
                      Chip(
                        label: Text(
                          tamperCtrl.isArmed ? "SIGNAL MONITOR ARMED" : "STANDBY",
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                        backgroundColor: tamperCtrl.isArmed ? Colors.deepOrange[900] : Colors.grey[800],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text("Signal Debouncer: 5s Debounce Window Active", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text("Tamper Signal Events: ${tamperCtrl.tamperEventsCount} received", style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.amber)),
                  if (tamperCtrl.lastTamperReason != null) ...[
                    const SizedBox(height: 4),
                    Text("Last Event: ${tamperCtrl.lastTamperReason}", style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.deepOrange)),
                  ],
                  if (active) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepOrange.withOpacity(0.2),
                              foregroundColor: Colors.deepOrange,
                              side: const BorderSide(color: Colors.deepOrange),
                            ),
                            onPressed: () {
                              tamperCtrl.handleDeviceTamperSignal(
                                sensorType: 'accelerometer',
                                reason: 'Simulated High-G Physical Impact',
                              );
                            },
                            icon: const Icon(Icons.flash_on),
                            label: const Text("Simulate Impact Signal"),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Evidence Capture Subsystem Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF18181B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF27272A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.between,
                    children: [
                      const Text("Evidence Capture Subsystem", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.amberAccent)),
                      Chip(
                        label: Text(
                          evidenceCtrl.isCapturing ? "CAPTURING" : "STANDBY",
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                        backgroundColor: evidenceCtrl.isCapturing ? Colors.amber[900] : Colors.grey[800],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text("Hardware Access: Camera (ARMED) | Mic (ARMED)", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text("Direct Cloud Uploads: ${evidenceCtrl.capturedItemsCount} items registered", style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.greenAccent)),
                  if (evidenceCtrl.evidenceItems.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text("Latest Cloud Storage Metadata:", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: evidenceCtrl.evidenceItems.take(2).map((item) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              "${item.fileName} (${(item.fileSizeBytes / 1024).toStringAsFixed(0)} KB) -> ${item.storageUrl}",
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 9, color: Colors.lightBlueAccent),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Real-time GPS Location Stream Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF18181B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF27272A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.between,
                    children: [
                      const Text("Real-time GPS Location Stream", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.lightBlueAccent)),
                      Chip(
                        label: Text(
                          locationCtrl.isTracking ? "STREAMING LIVE" : "STANDBY",
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                        backgroundColor: locationCtrl.isTracking ? Colors.green : Colors.grey[800],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Coordinates: ${locationCtrl.latestLatitude.toStringAsFixed(4)}° N, ${locationCtrl.latestLongitude.toStringAsFixed(4)}° E",
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.amber),
                  ),
                  const SizedBox(height: 4),
                  Text("Accuracy: ±${locationCtrl.latestAccuracy.toStringAsFixed(1)} m", style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text("FastAPI Packets Sent: ${locationCtrl.packetsSentCount}", style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.greenAccent)),
                  const SizedBox(height: 4),
                  Text("Offline Buffer Queue: ${locationCtrl.bufferedQueueLength} fixes", style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: locationCtrl.bufferedQueueLength > 0 ? Colors.orangeAccent : Colors.grey)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: locationCtrl.isNetworkAvailable ? Colors.amber : Colors.greenAccent,
                            side: BorderSide(color: locationCtrl.isNetworkAvailable ? Colors.amber : Colors.greenAccent),
                          ),
                          onPressed: () {
                            locationCtrl.setNetworkAvailable(!locationCtrl.isNetworkAvailable);
                          },
                          icon: Icon(locationCtrl.isNetworkAvailable ? Icons.wifi_off : Icons.wifi),
                          label: Text(locationCtrl.isNetworkAvailable ? "Simulate Offline Network Drop" : "Restore Network (Flush Queue)"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Leaflet + OpenStreetMap Visualization
            const Text("Leaflet + OpenStreetMap Live Map", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 10),
            LeafletOsmMapService.instance.renderMapWidget(
              latitude: locationCtrl.latestLatitude,
              longitude: locationCtrl.latestLongitude,
            ),

            const SizedBox(height: 16),

            // User Profile Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF18181B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF27272A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Authenticated Identity & Profile", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.purpleAccent)),
                  const SizedBox(height: 8),
                  Text("Auth Provider: Firebase Auth", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  Text("OTP Service: Shelex/free-otp-api", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  Text("User Phone: ${user?.phoneNumber ?? '+1 555 019 2831'}", style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.white)),
                  Text("Firebase UID: ${user?.uid ?? 'fb_uid_15550192831'}", style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.amber)),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Simulation & Onboarding Controls
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple.withOpacity(0.2),
                foregroundColor: Colors.purpleAccent,
                side: const BorderSide(color: Colors.purpleAccent),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () async {
                await OnboardingManager.instance.resetOnboarding();
                if (mounted) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                  );
                }
              },
              icon: const Icon(Icons.logout),
              label: const Text("Reset Onboarding / Test Logout Flow", style: TextStyle(fontWeight: FontWeight.bold)),
            ),

            const SizedBox(height: 16),
            const Text("Configured Calculator Triggers", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 10),
            ListTile(
              tileColor: const Color(0xFF18181B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              title: const Text("Covert Activation Trigger"),
              subtitle: const Text("99 + 99 =  (Blinks GREEN x2 confirmation)", style: TextStyle(fontFamily: 'monospace', color: Colors.greenAccent)),
              trailing: const Icon(Icons.shield_outlined, color: Colors.greenAccent),
            ),
            const SizedBox(height: 10),
            ListTile(
              tileColor: const Color(0xFF18181B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              title: const Text("Covert Deactivation Trigger"),
              subtitle: const Text("11 + 11 =  (Blinks RED x2 confirmation when ACTIVE)", style: TextStyle(fontFamily: 'monospace', color: Colors.redAccent)),
              trailing: const Icon(Icons.lock_open, color: Colors.redAccent),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String label, ServiceModuleStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: status == ServiceModuleStatus.active ? Colors.green.withOpacity(0.2) : Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: status == ServiceModuleStatus.active ? Colors.green : Colors.grey,
        ),
      ),
      child: Text(
        "$label: ${status.name.toUpperCase()}",
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: status == ServiceModuleStatus.active ? Colors.greenAccent : Colors.grey,
        ),
      ),
    );
  }
}