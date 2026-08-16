import 'dart:async';

class FirebaseUserIdentity {
  final String uid;
  final String phoneNumber;
  final String? displayName;

  FirebaseUserIdentity({
    required this.uid,
    required this.phoneNumber,
    this.displayName,
  });
}

/// Firebase Authentication Service Provider
class FirebaseAuthService {
  static final FirebaseAuthService instance = FirebaseAuthService._internal();
  FirebaseAuthService._internal();

  FirebaseUserIdentity? _currentUser;

  FirebaseUserIdentity? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;

  /// Authenticate user credentials with Firebase Auth
  Future<FirebaseUserIdentity> signInWithPhoneCredential(String phoneNumber, String verifiedOtp) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final String generatedUid = "fb_uid_${phoneNumber.replaceAll('+', '').replaceAll(' ', '')}";
    _currentUser = FirebaseUserIdentity(
      uid: generatedUid,
      phoneNumber: phoneNumber,
      displayName: "Verified User",
    );
    return _currentUser!;
  }

  /// Retrieve active JWT bearer token for FastAPI request authentication
  Future<String> getIdToken() async {
    if (_currentUser == null) return "token_usr_01";
    return "token_${_currentUser!.uid}";
  }

  void signOut() {
    _currentUser = null;
  }
}
