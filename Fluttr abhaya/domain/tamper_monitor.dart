import 'dart:async';
import 'package:flutter/foundation.dart';
import 'emergency_service_contracts.dart';
import 'emergency_session.dart';
import 'safety_state_manager.dart';
import 'abhaya_api_client.dart';

/// Tamper Monitor & Signal Debouncer Controller implementing ITamperDetectionService
class TamperMonitorController extends ChangeNotifier implements ITamperDetectionService {
  static final TamperMonitorController instance = TamperMonitorController._internal();
  TamperMonitorController._internal();

  StreamSubscription<EmergencySessionEvent>? _sessionSub;
  bool _isArmed = true;
  DateTime? _lastTamperSignalTime;
  String? _lastTamperReason;
  int _tamperEventsCount = 0;

  final AbhayaApiClient _apiClient = AbhayaApiClient();

  bool get isArmed => _isArmed;
  int get tamperEventsCount => _tamperEventsCount;
  String? get lastTamperReason => _lastTamperReason;

  void startListening() {
    _sessionSub?.cancel();
    _sessionSub = SafetyStateManager.instance.sessionEvents.listen((event) {
      if (event is SessionTerminatedEvent) {
        _resetTamperState();
      }
    });
  }

  /// Triggers a power-off / device shutdown tamper event
  Future<bool> handlePowerOffAttempt() async {
    return handleDeviceTamperSignal(
      sensorType: 'power_off_attempt',
      reason: 'Attempted Power-Off / Device Shutdown during active SOS Mode',
    );
  }

  /// Triggers a GPS disabled tamper event
  Future<bool> handleGpsDisabledTamper() async {
    return handleDeviceTamperSignal(
      sensorType: 'gps_disabled',
      reason: 'Attempted Turning Off GPS / Location Provider during active SOS Mode',
    );
  }

  /// Evaluates incoming platform device signal and debounces duplicate identical signals
  Future<bool> handleDeviceTamperSignal({
    required String sensorType,
    required String reason,
  }) async {
    if (!SafetyStateManager.instance.isEmergencyActive) {
      // Ignore signals if no active emergency session
      return false;
    }

    final DateTime now = DateTime.now();

    // Signal Debouncing: Reject duplicate identical signals within a 5-second window
    if (_lastTamperSignalTime != null &&
        _lastTamperReason == reason &&
        now.difference(_lastTamperSignalTime!).inSeconds < 5) {
      return false; // Debounced as duplicate signal
    }

    _lastTamperSignalTime = now;
    _lastTamperReason = reason;
    _tamperEventsCount += 1;
    notifyListeners();

    // 1. Mutate local domain state machine (ACTIVE -> ESCALATED)
    SafetyStateManager.instance.triggerTamperEscalation(reason: reason);

    // 2. Post tamper escalation event to FastAPI backend
    final session = SafetyStateManager.instance.activeSession;
    if (session != null) {
      try {
        await _apiClient.recordTamperEvent(
          session.id,
          sensorType: sensorType,
          reason: reason,
        );
      } catch (_) {}
    }

    return true;
  }

  void _resetTamperState() {
    _lastTamperSignalTime = null;
    _lastTamperReason = null;
    _tamperEventsCount = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _sessionSub?.cancel();
    super.dispose();
  }
}
