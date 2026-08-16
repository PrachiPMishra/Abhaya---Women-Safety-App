import 'emergency_session.dart';

/// Base class for all session lifecycle events
abstract class EmergencySessionEvent {
  final EmergencySession session;
  final DateTime timestamp;

  EmergencySessionEvent(this.session) : timestamp = DateTime.now();
}

class SessionStartedEvent extends EmergencySessionEvent {
  SessionStartedEvent(EmergencySession session) : super(session);
}

class SessionEscalatedEvent extends EmergencySessionEvent {
  final String reason;
  final int escalationLevel;

  SessionEscalatedEvent(EmergencySession session, this.reason, this.escalationLevel) : super(session);
}

class SessionTerminatedEvent extends EmergencySessionEvent {
  SessionTerminatedEvent(EmergencySession session) : super(session);
}

/// Abstract contract for future Location Service
abstract class ILocationService {
  Future<void> startLiveTracking(EmergencySession session);
  Future<void> stopTracking();
}

/// Abstract contract for future Emergency Notification / SOS Service
abstract class INotificationService {
  Future<void> dispatchEmergencyNotification(EmergencySession session);
  Future<void> dispatchEscalationAlert(EmergencySession session, String reason);
  Future<void> notifySessionDeactivated(EmergencySession session);
}

/// Abstract contract for future Evidence Capture Service (Camera & Mic)
abstract class IEvidenceService {
  Future<void> startEvidenceCapture(EmergencySession session);
  Future<void> stopEvidenceCapture();
}

/// Abstract contract for future Tamper Detection Service
abstract class ITamperDetectionService {
  void armTamperMonitoring(EmergencySession session);
  void disarmTamperMonitoring();
  void onTamperDetected(String reason);
}

/// Abstract contract for future Backend Synchronization Service
abstract class IBackendSyncService {
  Future<void> syncSessionState(EmergencySession session);
  Future<void> closeSession(EmergencySession session);
}
