import 'dart:async';
import 'abhaya_api_client.dart';

/// Verification Service managing phone number OTP verification via real SMS Gateway and FastAPI backend.
class OtpVerificationService {
  static final OtpVerificationService instance = OtpVerificationService._internal();
  OtpVerificationService._internal();

  final AbhayaApiClient _apiClient = AbhayaApiClient();

  /// Generates 6-digit OTP, stores in SQLite database, and dispatches real SMS to target phone number
  Future<Map<String, dynamic>> requestOtp(String phoneNumber) async {
    final String clean = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    if (clean.length < 8) {
      return {
        "success": false,
        "message": "Invalid phone number format. Please provide full mobile phone number with country code.",
      };
    }

    try {
      return await _apiClient.requestOtp(clean);
    } catch (e) {
      return {
        "success": false,
        "message": "Network error requesting SMS OTP: $e",
      };
    }
  }

  /// Verifies OTP code entered for user or trusted emergency contact against backend SQLite database
  Future<bool> verifyOtp(String phoneNumber, String code) async {
    final String cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    final String cleanCode = code.trim();

    if (cleanCode.isEmpty || cleanCode.length != 6) {
      return false;
    }

    try {
      return await _apiClient.verifyOtp(cleanPhone, cleanCode);
    } catch (_) {
      return false;
    }
  }
}
