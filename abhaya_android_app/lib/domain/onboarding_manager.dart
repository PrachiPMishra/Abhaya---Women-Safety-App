import 'dart:io';
import 'package:flutter/foundation.dart';

class OnboardingManager extends ChangeNotifier {
  static final OnboardingManager instance = OnboardingManager._internal();
  OnboardingManager._internal();

  bool _isOnboardingCompleted = false;
  bool _isInitialized = false;

  bool get isOnboardingCompleted => _isOnboardingCompleted;
  bool get isInitialized => _isInitialized;

  File? _onboardingFile;

  Future<File> _getFile() async {
    if (_onboardingFile != null) return _onboardingFile!;
    try {
      final Directory systemTemp = Directory.systemTemp;
      _onboardingFile = File('${systemTemp.path}/abhaya_onboarding_status.txt');
    } catch (_) {
      _onboardingFile = File('abhaya_onboarding_status.txt');
    }
    return _onboardingFile!;
  }

  /// Initializes onboarding completion status on launch
  Future<bool> checkOnboardingStatus() async {
    try {
      final File file = await _getFile();
      if (await file.exists()) {
        final String content = await file.readAsString();
        _isOnboardingCompleted = content.trim() == "true";
      } else {
        _isOnboardingCompleted = false;
      }
    } catch (e) {
      _isOnboardingCompleted = false;
    }
    _isInitialized = true;
    notifyListeners();
    return _isOnboardingCompleted;
  }

  /// Persists onboarding completion flag
  Future<void> completeOnboarding() async {
    _isOnboardingCompleted = true;
    try {
      final File file = await _getFile();
      await file.writeAsString("true");
    } catch (_) {}
    notifyListeners();
  }

  /// Resets onboarding completion state (used for testing logout / re-entry)
  Future<void> resetOnboarding() async {
    _isOnboardingCompleted = false;
    try {
      final File file = await _getFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
    notifyListeners();
  }
}
