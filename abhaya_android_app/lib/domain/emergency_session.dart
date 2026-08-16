import 'dart:math';
import '../abhaya_modular_flutter_source_code-5.dart'; // Imports SafetyState enum

enum ServiceModuleStatus { standby, active, error, disabled }

class EmergencySession {
  final String id;
  final String userId;
  final DateTime startTime;
  final DateTime? endTime;
  final SafetyState state;
  final int escalationLevel;
  final ServiceModuleStatus locationStatus;
  final ServiceModuleStatus notificationStatus;
  final ServiceModuleStatus evidenceStatus;
  final ServiceModuleStatus tamperStatus;
  final Map<String, dynamic> metadata;

  EmergencySession({
    required this.id,
    required this.userId,
    required this.startTime,
    this.endTime,
    required this.state,
    this.escalationLevel = 0,
    this.locationStatus = ServiceModuleStatus.standby,
    this.notificationStatus = ServiceModuleStatus.standby,
    this.evidenceStatus = ServiceModuleStatus.standby,
    this.tamperStatus = ServiceModuleStatus.standby,
    this.metadata = const {},
  });

  bool get isActive => state == SafetyState.active || state == SafetyState.escalated;

  /// Factory helper to generate a fresh EmergencySession
  factory EmergencySession.create({required String userId}) {
    final int timestamp = DateTime.now().millisecondsSinceEpoch;
    final int rand = Random().nextInt(899999) + 100000;
    final String generatedId = 'ses_${timestamp}_$rand';

    return EmergencySession(
      id: generatedId,
      userId: userId,
      startTime: DateTime.now(),
      state: SafetyState.active,
      escalationLevel: 0,
      locationStatus: ServiceModuleStatus.active,
      notificationStatus: ServiceModuleStatus.active,
      evidenceStatus: ServiceModuleStatus.active,
      tamperStatus: ServiceModuleStatus.active,
      metadata: {'init_source': 'calculator_covert_trigger'},
    );
  }

  EmergencySession copyWith({
    String? id,
    String? userId,
    DateTime? startTime,
    DateTime? endTime,
    SafetyState? state,
    int? escalationLevel,
    ServiceModuleStatus? locationStatus,
    ServiceModuleStatus? notificationStatus,
    ServiceModuleStatus? evidenceStatus,
    ServiceModuleStatus? tamperStatus,
    Map<String, dynamic>? metadata,
  }) {
    return EmergencySession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      state: state ?? this.state,
      escalationLevel: escalationLevel ?? this.escalationLevel,
      locationStatus: locationStatus ?? this.locationStatus,
      notificationStatus: notificationStatus ?? this.notificationStatus,
      evidenceStatus: evidenceStatus ?? this.evidenceStatus,
      tamperStatus: tamperStatus ?? this.tamperStatus,
      metadata: metadata ?? Map.from(this.metadata),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'state': state.name,
      'escalation_level': escalationLevel,
      'location_status': locationStatus.name,
      'notification_status': notificationStatus.name,
      'evidence_status': evidenceStatus.name,
      'tamper_status': tamperStatus.name,
      'metadata': metadata,
    };
  }

  factory EmergencySession.fromJson(Map<String, dynamic> json) {
    return EmergencySession(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: json['end_time'] != null ? DateTime.parse(json['end_time'] as String) : null,
      state: SafetyState.values.firstWhere(
        (e) => e.name == json['state'],
        orElse: () => SafetyState.inactive,
      ),
      escalationLevel: json['escalation_level'] as int? ?? 0,
      locationStatus: ServiceModuleStatus.values.firstWhere(
        (e) => e.name == json['location_status'],
        orElse: () => ServiceModuleStatus.standby,
      ),
      notificationStatus: ServiceModuleStatus.values.firstWhere(
        (e) => e.name == json['notification_status'],
        orElse: () => ServiceModuleStatus.standby,
      ),
      evidenceStatus: ServiceModuleStatus.values.firstWhere(
        (e) => e.name == json['evidence_status'],
        orElse: () => ServiceModuleStatus.standby,
      ),
      tamperStatus: ServiceModuleStatus.values.firstWhere(
        (e) => e.name == json['tamper_status'],
        orElse: () => ServiceModuleStatus.standby,
      ),
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
    );
  }
}
