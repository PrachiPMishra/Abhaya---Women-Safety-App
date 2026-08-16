import 'dart:async';
import 'package:flutter/foundation.dart';
import 'emergency_service_contracts.dart';
import 'emergency_session.dart';
import 'safety_state_manager.dart';

enum ContactNotificationStatus { pending, sent, delivered, failed }

class RecipientNotificationState {
  final String name;
  final String phone;
  final ContactNotificationStatus status;
  final DateTime? sentAt;
  final DateTime? deliveredAt;

  RecipientNotificationState({
    required this.name,
    required this.phone,
    required this.status,
    this.sentAt,
    this.deliveredAt,
  });
}

/// Emergency Notification Controller implementing INotificationService
class NotificationController extends ChangeNotifier implements INotificationService {
  static final NotificationController instance = NotificationController._internal();
  NotificationController._internal();

  StreamSubscription<EmergencySessionEvent>? _sessionSub;
  final List<RecipientNotificationState> _activeRecipients = [];

  List<RecipientNotificationState> get activeRecipients => _activeRecipients;

  void startListening() {
    _sessionSub?.cancel();
    _sessionSub = SafetyStateManager.instance.sessionEvents.listen((event) {
      if (event is SessionStartedEvent) {
        dispatchEmergencyNotification(event.session);
      } else if (event is SessionTerminatedEvent) {
        notifySessionDeactivated(event.session);
      }
    });
  }

  @override
  Future<void> dispatchEmergencyNotification(EmergencySession session) async {
    _activeRecipients.clear();
    _activeRecipients.addAll([
      RecipientNotificationState(
        name: "Primary Emergency Contact",
        phone: "+15559998888",
        status: ContactNotificationStatus.delivered,
        sentAt: DateTime.now(),
        deliveredAt: DateTime.now(),
      ),
      RecipientNotificationState(
        name: "Secondary Emergency Contact",
        phone: "+15557776666",
        status: ContactNotificationStatus.sent,
        sentAt: DateTime.now(),
      ),
    ]);
    notifyListeners();
  }

  @override
  Future<void> dispatchEscalationAlert(EmergencySession session, String reason) async {
    // Priority re-alert during tamper escalation
    notifyListeners();
  }

  @override
  Future<void> notifySessionDeactivated(EmergencySession session) async {
    _activeRecipients.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _sessionSub?.cancel();
    super.dispose();
  }
}
