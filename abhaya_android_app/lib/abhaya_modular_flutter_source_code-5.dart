import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'domain/emergency_session.dart';
import 'domain/emergency_service_contracts.dart';
import 'domain/session_storage_repository.dart';
import 'domain/abhaya_api_client.dart';
import 'domain/firebase_auth_service.dart';

enum SafetyState {
  inactive,
  starting,
  active,
  escalated,
  terminating,
}

class SafetyStateManager extends ChangeNotifier {
  static final SafetyStateManager instance = SafetyStateManager._internal();
  SafetyStateManager._internal();

  SafetyState _state = SafetyState.inactive;
  EmergencySession? _activeSession;
  bool _initialized = false;

  final StreamController<EmergencySessionEvent> _eventStreamController = StreamController<EmergencySessionEvent>.broadcast();

  SafetyState get state => _state;
  EmergencySession? get activeSession => _activeSession;
  bool get isEmergencyActive => _state == SafetyState.active || _state == SafetyState.escalated;
  bool get isEscalated => _state == SafetyState.escalated;
  bool get canActivate => _state == SafetyState.inactive;
  bool get canDeactivate => _state == SafetyState.active || _state == SafetyState.escalated;
  Stream<EmergencySessionEvent> get sessionEvents => _eventStreamController.stream;

  final AbhayaApiClient _apiClient = AbhayaApiClient();

  /// Initializes state manager and restores persisted active session if process was interrupted
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final restoredSession = await SessionStorageRepository.instance.loadActiveSession();
      if (restoredSession != null && restoredSession.isActive) {
        _activeSession = restoredSession;
        _state = restoredSession.state;
        _eventStreamController.add(SessionRestoredEvent(restoredSession));
      } else {
        // Query FastAPI backend for state reconciliation
        final backendSessionMap = await _apiClient.fetchActiveEmergencySession();
        if (backendSessionMap != null && backendSessionMap['session_id'] != null) {
          final sId = backendSessionMap['session_id'];
          _activeSession = EmergencySession.create(userId: 'usr_registered_01').copyWith(id: sId);
          _state = SafetyState.active;
          await SessionStorageRepository.instance.saveActiveSession(_activeSession!);
        }
      }
    } catch (_) {}

    _initialized = true;
    notifyListeners();
  }

  /// Activates an emergency session.
  /// Transition: INACTIVE -> STARTING -> ACTIVE.
  Future<bool> requestActivation({String userId = 'usr_registered_01'}) async {
    if (_state != SafetyState.inactive && _activeSession != null) {
      return true;
    }

    // 1. INACTIVE -> STARTING
    _state = SafetyState.starting;
    notifyListeners();

    // 2. Fetch live GPS position for session creation
    double? initialLat;
    double? initialLng;
    try {
      Position pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      initialLat = pos.latitude;
      initialLng = pos.longitude;
    } catch (_) {}

    // 3. Create emergency session on backend & local store with live GPS coordinates
    String sessionId = 'ses_srv_${DateTime.now().millisecondsSinceEpoch}';
    try {
      final Map<String, dynamic>? serverRes = await _apiClient.createEmergencySession(
        userId: userId,
        latitude: initialLat,
        longitude: initialLng,
      );
      if (serverRes != null && serverRes['session_id'] != null) {
        sessionId = serverRes['session_id'];
      }
    } catch (_) {
      // Offline fallback: Generate local session ID
    }

    // 4. STARTING -> ACTIVE
    _activeSession = EmergencySession.create(userId: userId).copyWith(id: sessionId);
    _state = SafetyState.active;

    await SessionStorageRepository.instance.saveActiveSession(_activeSession!);
    _eventStreamController.add(SessionStartedEvent(_activeSession!));

    notifyListeners();
    return true;
  }

  /// Orderly deactivation of active emergency session.
  /// Transition: ACTIVE / ESCALATED -> TERMINATING -> INACTIVE.
  Future<bool> requestDeactivation() async {
    final String targetSessionId = _activeSession?.id ?? "active_session";

    // 1. ACTIVE/ESCALATED -> TERMINATING
    _state = SafetyState.terminating;
    notifyListeners();

    try {
      // 2. Terminate backend session & dispatch "Safe and Sound" SMS alert
      await _apiClient.terminateSession(targetSessionId);

      final EmergencySession terminatedSession = (_activeSession ?? EmergencySession.create(userId: 'usr_registered_01')).copyWith(
        endTime: DateTime.now(),
        state: SafetyState.inactive,
        locationStatus: ServiceModuleStatus.standby,
        notificationStatus: ServiceModuleStatus.standby,
        evidenceStatus: ServiceModuleStatus.standby,
        tamperStatus: ServiceModuleStatus.standby,
      );

      // 3. Stop session services & purge disk storage
      _eventStreamController.add(SessionTerminatedEvent(terminatedSession));
      await SessionStorageRepository.instance.clearActiveSession();

      // 4. TERMINATING -> INACTIVE
      _activeSession = null;
      _state = SafetyState.inactive;

      notifyListeners();
      return true;
    } catch (e) {
      _activeSession = null;
      _state = SafetyState.inactive;
      notifyListeners();
      return true;
    }
  }

  /// Escalates existing session when tampering or severe condition is detected.
  /// Transition: ACTIVE -> ESCALATED.
  bool triggerTamperEscalation({String reason = 'Device tamper event detected'}) {
    if (_activeSession == null) {
      _activeSession = EmergencySession.create(userId: 'usr_registered_01');
    }

    final int newLevel = _activeSession!.escalationLevel + 1;
    Map<String, dynamic> updatedMeta = Map.from(_activeSession!.metadata);
    updatedMeta['last_tamper_reason'] = reason;
    updatedMeta['tamper_timestamp'] = DateTime.now().toIso8601String();

    _activeSession = _activeSession!.copyWith(
      state: SafetyState.escalated,
      escalationLevel: newLevel,
      tamperStatus: ServiceModuleStatus.active,
      metadata: updatedMeta,
    );

    _state = SafetyState.escalated;
    SessionStorageRepository.instance.saveActiveSession(_activeSession!);
    _eventStreamController.add(SessionEscalatedEvent(_activeSession!, reason, newLevel));

    notifyListeners();
    return true;
  }

  /// Simulates an app process restart / re-entry to verify recovery mechanism
  Future<void> simulateProcessRestart() async {
    if (_activeSession != null) {
      await SessionStorageRepository.instance.saveActiveSession(_activeSession!);
    }

    _activeSession = null;
    _state = SafetyState.inactive;
    _initialized = false;
    notifyListeners();

    await initialize();
  }

  @override
  void dispose() {
    _eventStreamController.close();
    super.dispose();
  }
}