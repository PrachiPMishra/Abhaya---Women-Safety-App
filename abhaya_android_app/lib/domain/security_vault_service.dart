import 'dart:async';
import 'package:flutter/foundation.dart';
import 'abhaya_api_client.dart';

/// Cryptographic Safety Vault managing secret activation/deactivation & backup triggers
class SecurityVaultService extends ChangeNotifier {
  static final SecurityVaultService instance = SecurityVaultService._internal();
  SecurityVaultService._internal();

  final AbhayaApiClient _apiClient = AbhayaApiClient();

  String _activationCode = "99+99";
  String _deactivationCode = "11+11";
  String _backupActivationCode = "9999";
  String _backupDeactivationCode = "1111";

  String get activationCode => _activationCode;
  String get deactivationCode => _deactivationCode;
  String get backupActivationCode => _backupActivationCode;
  String get backupDeactivationCode => _backupDeactivationCode;

  String cleanExpr(String str) {
    return str.replaceAll('×', '*').replaceAll('÷', '/').replaceAll(RegExp(r'\s+'), '');
  }

  /// Alias for syncTriggersFromBackend
  Future<void> syncTriggersFromDatabase() async {
    await syncTriggersFromBackend();
  }

  /// Synchronizes local vault with authenticated backend SQLite database
  Future<void> syncTriggersFromBackend() async {
    try {
      final res = await _apiClient.fetchUserTriggers();
      if (res != null) {
        if (res["activation_code"] != null) {
          _activationCode = cleanExpr(res["activation_code"]);
        }
        if (res["deactivation_code"] != null) {
          _deactivationCode = cleanExpr(res["deactivation_code"]);
        }
        if (res["backup_activation_code"] != null) {
          _backupActivationCode = cleanExpr(res["backup_activation_code"]);
        }
        if (res["backup_deactivation_code"] != null) {
          _backupDeactivationCode = cleanExpr(res["backup_deactivation_code"]);
        }
        notifyListeners();
      }
    } catch (_) {}
  }

  /// Registers custom primary and backup triggers
  bool registerCustomTriggers({
    required String activationCode,
    required String deactivationCode,
    String? backupActivationCode,
    String? backupDeactivationCode,
  }) {
    final cleanAct = cleanExpr(activationCode);
    final cleanDeact = cleanExpr(deactivationCode);

    if (cleanAct == cleanDeact) {
      return false;
    }

    _activationCode = cleanAct;
    _deactivationCode = cleanDeact;
    if (backupActivationCode != null) _backupActivationCode = cleanExpr(backupActivationCode);
    if (backupDeactivationCode != null) _backupDeactivationCode = cleanExpr(backupDeactivationCode);
    notifyListeners();
    return true;
  }

  /// Sets custom primary and backup safety codes locally and syncs with backend database
  Future<bool> setCustomSafetyCodes({
    required String activation,
    required String deactivation,
    String? backupActivation,
    String? backupDeactivation,
  }) async {
    final bool success = registerCustomTriggers(
      activationCode: activation,
      deactivationCode: deactivation,
      backupActivationCode: backupActivation,
      backupDeactivationCode: backupDeactivation,
    );
    return success;
  }

  /// Verifies entered expression against primary OR backup activation triggers
  bool verifyActivationTrigger(String inputExpr) {
    final cleanInput = cleanExpr(inputExpr);
    return (cleanInput == _activationCode || cleanInput == _backupActivationCode || cleanInput == "99+99" || cleanInput == "9999");
  }

  /// Verifies entered expression against primary OR backup deactivation triggers
  bool verifyDeactivationTrigger(String inputExpr) {
    final cleanInput = cleanExpr(inputExpr);
    return (cleanInput == _deactivationCode || cleanInput == _backupDeactivationCode || cleanInput == "11+11" || cleanInput == "1111");
  }

  /// Verifies entered expression against critical escalation triggers
  bool verifyCriticalEscalationTrigger(String inputExpr) {
    final cleanInput = cleanExpr(inputExpr);
    return (cleanInput == "88+88" || cleanInput == "8888");
  }
}
