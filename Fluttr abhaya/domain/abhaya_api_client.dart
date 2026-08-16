import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'emergency_session.dart';
import 'emergency_service_contracts.dart';

/// Dart HTTP API client implementing IBackendSyncService for FastAPI communication
class AbhayaApiClient implements IBackendSyncService {
  final String baseUrl;
  final String authToken;
  final HttpClient _httpClient = HttpClient();

  AbhayaApiClient({
    this.baseUrl = "http://localhost:8000",
    this.authToken = "token_usr_01",
  });

  Map<String, String> get _headers => {
        "Content-Type": "application/json",
        "Authorization": "Bearer $authToken",
      };

  @override
  Future<void> syncSessionState(EmergencySession session) async {
    try {
      await createEmergencySession(userId: session.userId);
    } catch (_) {}
  }

  @override
  Future<void> closeSession(EmergencySession session) async {
    await terminateSession(session.id);
  }

  Future<Map<String, dynamic>> checkPhoneExistence(String phoneNumber) async {
    try {
      final uri = Uri.parse("$baseUrl/users/check-phone");
      final request = await _httpClient.postUrl(uri);
      _headers.forEach((key, value) => request.headers.set(key, value));
      request.write(jsonEncode({"phone_number": phoneNumber}));

      final response = await request.close().timeout(const Duration(seconds: 4));
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        return jsonDecode(responseBody) as Map<String, dynamic>;
      }
      return {"exists": false};
    } catch (_) {
      return {"exists": false};
    }
  }

  Future<Map<String, dynamic>> requestOtp(String phoneNumber) async {
    try {
      final uri = Uri.parse("$baseUrl/users/otp/request");
      final request = await _httpClient.postUrl(uri);
      _headers.forEach((key, value) => request.headers.set(key, value));
      request.write(jsonEncode({"phone_number": phoneNumber}));

      final response = await request.close().timeout(const Duration(seconds: 5));
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        return jsonDecode(responseBody) as Map<String, dynamic>;
      }
      return {
        "success": false,
        "message": "Failed to dispatch SMS OTP: $responseBody",
      };
    } catch (e) {
      return {
        "success": false,
        "message": "Network error dispatching SMS OTP: $e",
      };
    }
  }

  Future<bool> verifyOtp(String phoneNumber, String code) async {
    try {
      final uri = Uri.parse("$baseUrl/users/otp/verify");
      final request = await _httpClient.postUrl(uri);
      _headers.forEach((key, value) => request.headers.set(key, value));
      request.write(jsonEncode({
        "phone_number": phoneNumber,
        "code": code,
      }));

      final response = await request.close().timeout(const Duration(seconds: 4));
      return (response.statusCode == 200);
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> fetchUserTriggers() async {
    try {
      final uri = Uri.parse("$baseUrl/users/triggers");
      final request = await _httpClient.getUrl(uri);
      _headers.forEach((key, value) => request.headers.set(key, value));

      final response = await request.close().timeout(const Duration(seconds: 3));
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        return jsonDecode(responseBody) as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> saveUserProfile({
    required String phoneNumber,
    required String fullName,
    String? dob,
    String? fullAddress,
    String? email,
    required String activationCode,
    required String deactivationCode,
    String? backupActivationCode,
    String? backupDeactivationCode,
    required List<Map<String, dynamic>> trustedContacts,
  }) async {
    try {
      final uri = Uri.parse("$baseUrl/users/profile");
      final request = await _httpClient.postUrl(uri);
      _headers.forEach((key, value) => request.headers.set(key, value));
      request.write(jsonEncode({
        "phone_number": phoneNumber,
        "full_name": fullName,
        "dob": dob,
        "full_address": fullAddress,
        "email": email,
        "activation_code": activationCode,
        "deactivation_code": deactivationCode,
        "backup_activation_code": backupActivationCode ?? "9999",
        "backup_deactivation_code": backupDeactivationCode ?? "1111",
        "trusted_contacts": trustedContacts,
      }));

      final response = await request.close().timeout(const Duration(seconds: 4));
      return (response.statusCode == 200 || response.statusCode == 201);
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> createEmergencySession({required String userId}) async {
    try {
      final uri = Uri.parse("$baseUrl/sessions");
      final request = await _httpClient.postUrl(uri);
      _headers.forEach((key, value) => request.headers.set(key, value));
      request.write(jsonEncode({"user_id": userId}));

      final response = await request.close().timeout(const Duration(seconds: 4));
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(responseBody) as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> terminateSession(String sessionId) async {
    try {
      final uri = Uri.parse("$baseUrl/sessions/$sessionId/terminate");
      final request = await _httpClient.postUrl(uri);
      _headers.forEach((key, value) => request.headers.set(key, value));
      request.write(jsonEncode({
        "reason": "covert_deactivation_triggered"
      }));

      final response = await request.close().timeout(const Duration(seconds: 4));
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      }
      throw Exception("Backend termination failed with status ${response.statusCode}: $responseBody");
    } catch (e) {
      rethrow;
    }
  }

  Future<void> pushLocationUpdate(String sessionId, double lat, double lng, double accuracy) async {
    try {
      final uri = Uri.parse("$baseUrl/sessions/$sessionId/location");
      final request = await _httpClient.postUrl(uri);
      _headers.forEach((key, value) => request.headers.set(key, value));
      request.write(jsonEncode({
        "location": {
          "latitude": lat,
          "longitude": lng,
          "accuracy_meters": accuracy,
          "timestamp": DateTime.now().toIso8601String(),
        }
      }));
      await request.close().timeout(const Duration(seconds: 3));
    } catch (_) {}
  }
}
