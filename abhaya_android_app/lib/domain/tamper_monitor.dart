import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'emergency_service_contracts.dart';
import 'emergency_session.dart';
import 'safety_state_manager.dart';
import 'abhaya_api_client.dart';

/// Tamper Monitor & Signal Debouncer Controller implementing ITamperDetectionService
class TamperMonitorController extends ChangeNotifier implements ITamperDetectionService {
  static final TamperMonitorController instance = TamperMonitorController._internal();
  TamperMonitorController._internal();

  StreamSubscription<EmergencySessionEvent>? _sessionSub;
  StreamSubscription<ServiceStatus>? _gpsServiceSub;
  bool _isArmed = true;
  DateTime? _lastTamperSignalTime;
  String? _lastTamperReason;
  int _tamperEventsCount = 0;

  final AbhayaApiClient _apiClient = AbhayaApiClient();

  bool get isArmed => _isArmed;
  int get tamperEventsCount => _tamperEventsCount;
  String? get lastTamperReason => _lastTamperReason;

  @override
  void armTamperMonitoring(EmergencySession session) {
    _isArmed = true;
    notifyListeners();
  }

  @override
  void disarmTamperMonitoring() {
    _isArmed = false;
    notifyListeners();
  }

  @override
  void onTamperDetected(String reason) {
    handleDeviceTamperSignal(sensorType: 'sensor_anomaly', reason: reason);
  }

  void startListening() {
    _sessionSub?.cancel();
    _sessionSub = SafetyStateManager.instance.sessionEvents.listen((event) {
      if (event is SessionTerminatedEvent) {
        _resetTamperState();
      }
    });

    _gpsServiceSub?.cancel();
    try {
      _gpsServiceSub = Geolocator.getServiceStatusStream().listen((ServiceStatus status) {
        if (status == ServiceStatus.disabled) {
          handleGpsDisabledTamper();
        }
      });
    } catch (_) {}
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
    final DateTime now = DateTime.now();

    // Signal Debouncing: Reject duplicate identical signals within a 3-second window
    if (_lastTamperSignalTime != null &&
        _lastTamperReason == reason &&
        now.difference(_lastTamperSignalTime!).inSeconds < 3) {
      return false;
    }

    _lastTamperSignalTime = now;
    _lastTamperReason = reason;
    _tamperEventsCount += 1;
    notifyListeners();

    // Ensure Emergency SOS Session is active
    if (!SafetyStateManager.instance.isEmergencyActive) {
      await SafetyStateManager.instance.requestActivation();
    }

    // Mutate local domain state machine to ESCALATED
    SafetyStateManager.instance.triggerTamperEscalation(reason: reason);

    // Post critical tamper escalation event to FastAPI backend
    final session = SafetyStateManager.instance.activeSession;
    final String targetSessionId = session?.id ?? "active_session";

    try {
      await _apiClient.recordTamperEvent(
        targetSessionId,
        sensorType: sensorType,
        reason: reason,
      );
    } catch (_) {}

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
    _gpsServiceSub?.cancel();
    super.dispose();
  }
}
