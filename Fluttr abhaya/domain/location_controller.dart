import 'dart:async';

import 'package:flutter/foundation.dart';

import 'abhaya_api_client.dart';
import 'emergency_service_contracts.dart';
import 'emergency_session.dart';
import 'safety_state_manager.dart';

class LocationPoint {
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime timestamp;

  LocationPoint({
    required this.latitude,
    required this.longitude,
    this.accuracy = 5.0,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Resilient Real-time Location Controller implementing ILocationService
class RealtimeLocationController extends ChangeNotifier implements ILocationService {
  static final RealtimeLocationController instance = RealtimeLocationController._internal();
  RealtimeLocationController._internal();

  Timer? _locationTimer;
  StreamSubscription<EmergencySessionEvent>? _sessionEventSub;

  bool _isTracking = false;
  LocationPoint? _latestLocation;
  int _packetsSentCount = 0;
  final List<LocationPoint> _offlineLocationBuffer = [];
  bool _isNetworkAvailable = true;

  bool get isTracking => _isTracking;
  LocationPoint? get latestLocation => _latestLocation;
  double get latestLatitude => _latestLocation?.latitude ?? 28.6139;
  double get latestLongitude => _latestLocation?.longitude ?? 77.2090;
  double get latestAccuracy => _latestLocation?.accuracy ?? 4.2;
  int get packetsSentCount => _packetsSentCount;
  int get bufferedQueueLength => _offlineLocationBuffer.length;
  bool get isNetworkAvailable => _isNetworkAvailable;

  final AbhayaApiClient _apiClient = AbhayaApiClient();

  /// Starts listening to session lifecycle events on app startup
  void startListening() {
    _sessionEventSub?.cancel();
    _sessionEventSub = SafetyStateManager.instance.sessionEvents.listen((event) {
      if (event is SessionStartedEvent) {
        startLiveTracking(event.session);
      } else if (event is SessionTerminatedEvent) {
        stopTracking();
      } else if (event is SessionEscalatedEvent) {
        // Continue tracking during escalation with priority flag
        if (!_isTracking) startLiveTracking(event.session);
      }
    });

    // If session was already recovered and active on startup, start tracking
    if (SafetyStateManager.instance.isEmergencyActive && SafetyStateManager.instance.activeSession != null) {
      startLiveTracking(SafetyStateManager.instance.activeSession!);
    }
  }

  @override
  Future<void> startLiveTracking(EmergencySession session) async {
    if (_isTracking) return;
    _isTracking = true;
    notifyListeners();

    // Base mock GPS movement simulation starting from initial location
    double baseLat = 28.6139;
    double baseLng = 77.2090;

    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!_isTracking) {
        timer.cancel();
        return;
      }

      // Simulate subtle GPS coordinate movement fix
      baseLat += (DateTime.now().second % 2 == 0 ? 0.0001 : -0.0001);
      baseLng += (DateTime.now().second % 3 == 0 ? 0.0001 : -0.0001);

      final point = LocationPoint(
        latitude: baseLat,
        longitude: baseLng,
        accuracy: 3.5 + (DateTime.now().second % 3),
        timestamp: DateTime.now(),
      );

      _latestLocation = point;

      // Stream update to FastAPI backend
      if (_isNetworkAvailable) {
        try {
          await _apiClient.pushLocationUpdate(
            session.id,
            point.latitude,
            point.longitude,
            point.accuracy,
          );
          _packetsSentCount += 1;

          // Flush any offline buffered location points if back online
          if (_offlineLocationBuffer.isNotEmpty) {
            await _flushOfflineBuffer(session.id);
          }
        } catch (e) {
          // Buffer location fix on network failure
          _offlineLocationBuffer.add(point);
        }
      } else {
        // Buffer location point while offline
        _offlineLocationBuffer.add(point);
      }

      notifyListeners();
    });
  }

  Future<void> _flushOfflineBuffer(String sessionId) async {
    while (_offlineLocationBuffer.isNotEmpty && _isNetworkAvailable) {
      final point = _offlineLocationBuffer.removeAt(0);
      try {
        await _apiClient.pushLocationUpdate(
          sessionId,
          point.latitude,
          point.longitude,
          point.accuracy,
        );
        _packetsSentCount += 1;
      } catch (_) {
        _offlineLocationBuffer.insert(0, point);
        break;
      }
    }
  }

  @override
  Future<void> stopTracking() async {
    _isTracking = false;
    _locationTimer?.cancel();
    _locationTimer = null;
    notifyListeners();
  }

  /// Toggle simulated network loss for resilience testing
  void setNetworkAvailable(bool available) {
    _isNetworkAvailable = available;
    notifyListeners();
  }

  @override
  void dispose() {
    _sessionEventSub?.cancel();
    _locationTimer?.cancel();
    super.dispose();
  }
}
