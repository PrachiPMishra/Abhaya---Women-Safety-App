import 'dart:async';
import 'package:flutter/foundation.dart';
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
  final AbhayaApiClient _apiClient = AbhayaApiClient();

  SafetyState get state => _state;
  EmergencySession? get activeSession => _activeSession;
  bool get isInitialized => _initialized;
  bool get isEmergencyActive => (_state == SafetyState.active || _state == SafetyState.escalated) && _activeSession != null;
  bool get isEscalated => _state == SafetyState.escalated;
  bool get canDeactivate => (_state == SafetyState.active || _state == SafetyState.escalated) && _activeSession != null;

  Stream<EmergencySessionEvent> get sessionEvents => _eventStreamController.stream;

  /// Startup State Reconciliation Protocol.
  /// Reconciles local disk cache with authoritative FastAPI backend session.
  Future<void> initialize() async {
    if (_initialized) return;

    // Step 1: Read local persistent emergency session from disk
    final EmergencySession? localSession = await SessionStorageRepository.instance.loadActiveSession();

    // Step 2: Re-establish user identity
    final String userId = FirebaseAuthService.instance.currentUser?.uid ?? 'usr_registered_01';

    // Step 3: Query FastAPI for authoritative server-side active emergency session
    Map<String, dynamic>? serverSessionData;
    try {
      serverSessionData = await _apiClient.fetchActiveEmergencySession();
    } catch (_) {
      // Backend temporarily unreachable -> Network Fallback: Preserve local emergency state
    }

    // Step 4: Reconcile Local and Server State
    if (localSession != null || serverSessionData != null) {
      if (serverSessionData != null) {
        final String serverStateStr = serverSessionData['state'] ?? 'active';
        final int serverEscLevel = serverSessionData['escalation_level'] ?? 0;
        final String sessionId = serverSessionData['session_id'] ?? localSession?.id ?? 'ses_recovered';

        SafetyState resolvedState = serverStateStr == 'escalated' ? SafetyState.escalated : SafetyState.active;
        int maxEscalationLevel = serverEscLevel;

        if (localSession != null) {
          if (localSession.state == SafetyState.escalated) {
            resolvedState = SafetyState.escalated;
          }
          if (localSession.escalationLevel > maxEscalationLevel) {
            maxEscalationLevel = localSession.escalationLevel;
          }
        }

        _activeSession = EmergencySession(
          id: sessionId,
          userId: userId,
          startTime: localSession?.startTime ?? DateTime.now(),
          state: resolvedState,
          escalationLevel: maxEscalationLevel,
        );
        _state = resolvedState;
      } else if (localSession != null) {
        // Network offline -> Fallback to persistent local disk cache session
        _activeSession = localSession;
        _state = localSession.state;
      }

      if (_activeSession != null) {
        await SessionStorageRepository.instance.saveActiveSession(_activeSession!);
        _eventStreamController.add(SessionStartedEvent(_activeSession!));
      }
    } else {
      // No active emergency session -> Inactive Standby (Calculator Mode)
      await SessionStorageRepository.instance.clearActiveSession();
      _activeSession = null;
      _state = SafetyState.inactive;
    }

    _initialized = true;
    notifyListeners();
  }

  /// Activates an emergency session.
  /// Transition: INACTIVE -> STARTING -> ACTIVE.
  Future<bool> requestActivation({String userId = 'usr_registered_01'}) async {
    if (_state != SafetyState.inactive || _activeSession != null) {
      // Reject duplicate activation if session already active or in transition
      return false;
    }

    // 1. INACTIVE -> STARTING
    _state = SafetyState.starting;
    notifyListeners();

    // 2. Create emergency session on backend & local store
    String sessionId = 'ses_srv_${DateTime.now().millisecondsSinceEpoch}';
    try {
      final Map<String, dynamic>? serverRes = await _apiClient.createEmergencySession(userId: userId);
      if (serverRes != null && serverRes['session_id'] != null) {
        sessionId = serverRes['session_id'];
      }
    } catch (_) {
      // Offline fallback: Generate local session ID
    }

    // 3. STARTING -> ACTIVE
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
    if (!canDeactivate || _activeSession == null) {
      return false;
    }

    final EmergencySession sessionToTerminate = _activeSession!;
    final SafetyState previousState = _state;

    // 1. ACTIVE/ESCALATED -> TERMINATING
    _state = SafetyState.terminating;
    notifyListeners();

    try {
      // 2. Terminate backend session
      await _apiClient.terminateSession(sessionToTerminate.id);

      final EmergencySession terminatedSession = sessionToTerminate.copyWith(
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
      // If termination fails, remain ACTIVE / ESCALATED without false RED confirmation
      _state = previousState;
      notifyListeners();
      return false;
    }
  }

  /// Escalates existing session when tampering or severe condition is detected.
  /// Transition: ACTIVE -> ESCALATED.
  bool triggerTamperEscalation({String reason = 'Device tamper event detected'}) {
    if (_state != SafetyState.active || _activeSession == null) {
      return false;
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