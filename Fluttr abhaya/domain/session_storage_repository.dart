import 'dart:convert';
import 'dart:io';
import 'emergency_session.dart';

/// Local Storage Repository for persisting and recovering active Emergency Sessions
class SessionStorageRepository {
  static final SessionStorageRepository instance = SessionStorageRepository._internal();
  SessionStorageRepository._internal();

  // In-memory persistent cache for quick fallback access
  String? _cachedSessionJson;
  File? _sessionFile;

  Future<File> _getFile() async {
    if (_sessionFile != null) return _sessionFile!;
    try {
      final Directory systemTemp = Directory.systemTemp;
      final String filePath = '${systemTemp.path}/abhaya_active_session.json';
      _sessionFile = File(filePath);
    } catch (_) {
      // Fallback path
      _sessionFile = File('abhaya_active_session.json');
    }
    return _sessionFile!;
  }

  /// Persists active EmergencySession to local storage
  Future<void> saveActiveSession(EmergencySession session) async {
    try {
      final String jsonStr = jsonEncode(session.toJson());
      _cachedSessionJson = jsonStr;
      final File file = await _getFile();
      await file.writeAsString(jsonStr);
    } catch (e) {
      // Fallback cache retains jsonStr
    }
  }

  /// Loads and deserializes active EmergencySession on app startup / re-entry
  Future<EmergencySession?> loadActiveSession() async {
    try {
      String? jsonStr = _cachedSessionJson;

      if (jsonStr == null || jsonStr.isEmpty) {
        final File file = await _getFile();
        if (await file.exists()) {
          jsonStr = await file.readAsString();
          _cachedSessionJson = jsonStr;
        }
      }

      if (jsonStr != null && jsonStr.isNotEmpty) {
        final Map<String, dynamic> map = jsonDecode(jsonStr) as Map<String, dynamic>;
        final EmergencySession session = EmergencySession.fromJson(map);
        
        // Recover only active or escalated sessions
        if (session.state == SafetyState.active || session.state == SafetyState.escalated) {
          return session;
        }
      }
    } catch (e) {
      // Return null on parsing or read failure
    }
    return null;
  }

  /// Clears active EmergencySession local storage upon clean session termination
  Future<void> clearActiveSession() async {
    try {
      _cachedSessionJson = null;
      final File file = await _getFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      _cachedSessionJson = null;
    }
  }

  /// Synchronous fallback check for cached active session
  bool get hasCachedActiveSession => _cachedSessionJson != null && _cachedSessionJson!.isNotEmpty;
}
