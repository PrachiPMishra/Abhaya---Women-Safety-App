import 'package:flutter/material.dart';
import '../domain/onboarding_manager.dart';
import '../domain/otp_verification_service.dart';
import '../domain/firebase_auth_service.dart';
import '../domain/security_vault_service.dart';
import '../abhaya_modular_flutter_source_code-3.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentStep = 0;
  bool _isLoading = false;

  bool _userOtpSent = false;
  bool _contact1OtpSent = false;
  bool _contact2OtpSent = false;

  // Account & Contact Input Controllers
  final TextEditingController _userPhoneController = TextEditingController(text: "+1 555 019 2831");
  final TextEditingController _userOtpController = TextEditingController(text: "");
  final TextEditingController _userNameController = TextEditingController(text: "Pravin Kumar");

  // Contact 1 (Primary)
  final TextEditingController _contact1NameController = TextEditingController(text: "Guardian Contact 1");
  final TextEditingController _contact1PhoneController = TextEditingController(text: "+1 555 999 8888");
  final TextEditingController _contact1OtpController = TextEditingController(text: "");
  bool _contact1Verified = false;

  // Contact 2 (Secondary)
  final TextEditingController _contact2NameController = TextEditingController(text: "Guardian Contact 2");
  final TextEditingController _contact2PhoneController = TextEditingController(text: "+1 555 777 6666");
  final TextEditingController _contact2OtpController = TextEditingController(text: "");
  bool _contact2Verified = false;

  // User-Defined Safety Triggers
  final TextEditingController _activationCodeController = TextEditingController(text: "99+99");
  final TextEditingController _deactivationCodeController = TextEditingController(text: "11+11");

  bool _locationPermissionGranted = true;
  bool _cameraPermissionGranted = true;
  bool _micPermissionGranted = true;

  String? _statusMessage;

  @override
  void dispose() {
    _userPhoneController.dispose();
    _userOtpController.dispose();
    _userNameController.dispose();
    _contact1NameController.dispose();
    _contact1PhoneController.dispose();
    _contact1OtpController.dispose();
    _contact2NameController.dispose();
    _contact2PhoneController.dispose();
    _contact2OtpController.dispose();
    _activationCodeController.dispose();
    _deactivationCodeController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 4) {
      setState(() {
        _currentStep += 1;
        _statusMessage = null;
      });
    } else {
      _finishOnboarding();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep -= 1;
        _statusMessage = null;
      });
    }
  }

  Future<void> _requestUserOtp() async {
    setState(() => _isLoading = true);
    final res = await OtpVerificationService.instance.requestOtp(_userPhoneController.text);
    setState(() {
      _isLoading = false;
      _userOtpSent = true;
      _statusMessage = res["message"];
    });
  }

  Future<void> _verifyUserAccount() async {
    if (!_userOtpSent) {
      await _requestUserOtp();
      return;
    }
    setState(() => _isLoading = true);
    final bool verified = await OtpVerificationService.instance.verifyOtp(
      _userPhoneController.text,
      _userOtpController.text,
    );

    if (verified) {
      await FirebaseAuthService.instance.signInWithPhoneCredential(
        _userPhoneController.text,
        _userOtpController.text,
      );
      setState(() {
        _isLoading = false;
        _statusMessage = null;
      });
      _nextStep();
    } else {
      setState(() {
        _isLoading = false;
        _statusMessage = "Invalid verification code";
      });
    }
  }

  Future<void> _requestContact1Otp() async {
    setState(() => _isLoading = true);
    final res = await OtpVerificationService.instance.requestOtp(_contact1PhoneController.text);
    setState(() {
      _isLoading = false;
      _contact1OtpSent = true;
      _statusMessage = res["message"];
    });
  }

  Future<void> _verifyContact1() async {
    if (!_contact1OtpSent) {
      await _requestContact1Otp();
      return;
    }
    setState(() => _isLoading = true);
    final bool verified = await OtpVerificationService.instance.verifyOtp(
      _contact1PhoneController.text,
      _contact1OtpController.text,
    );

    if (verified) {
      setState(() {
        _contact1Verified = true;
        _isLoading = false;
        _statusMessage = "Primary emergency contact verified!";
      });
      _nextStep();
    } else {
      setState(() {
        _isLoading = false;
        _statusMessage = "Contact verification failed. Please check code.";
      });
    }
  }

  Future<void> _requestContact2Otp() async {
    setState(() => _isLoading = true);
    final res = await OtpVerificationService.instance.requestOtp(_contact2PhoneController.text);
    setState(() {
      _isLoading = false;
      _contact2OtpSent = true;
      _statusMessage = res["message"];
    });
  }

  Future<void> _verifyContact2() async {
    if (!_contact2OtpSent) {
      await _requestContact2Otp();
      return;
    }
    setState(() => _isLoading = true);
    final bool verified = await OtpVerificationService.instance.verifyOtp(
      _contact2PhoneController.text,
      _contact2OtpController.text,
    );

    if (verified) {
      setState(() {
        _contact2Verified = true;
        _isLoading = false;
        _statusMessage = "Secondary emergency contact verified!";
      });
      _nextStep();
    } else {
      setState(() {
        _isLoading = false;
        _statusMessage = "Contact verification failed. Please check code.";
      });
    }
  }

  void _saveCustomSafetyCodes() {
    final String act = _activationCodeController.text.trim();
    final String deact = _deactivationCodeController.text.trim();

    if (act.isEmpty || deact.isEmpty) {
      setState(() => _statusMessage = "Please enter both activation and deactivation expressions");
      return;
    }

    if (act == deact) {
      setState(() => _statusMessage = "Activation and deactivation expressions must be different!");
      return;
    }

    final bool success = SecurityVaultService.instance.registerCustomTriggers(
      activationCode: act,
      deactivationCode: deact,
    );

    if (success) {
      setState(() => _statusMessage = null);
      _nextStep();
    } else {
      setState(() => _statusMessage = "Failed to register trigger expressions");
    }
  }

  Future<void> _finishOnboarding() async {
    setState(() => _isLoading = true);
    await OnboardingManager.instance.completeOnboarding();
    setState(() => _isLoading = false);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainNavigatorScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121214),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              // Header Indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.shield, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        "Account & Safety Setup",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.2),
                      ),
                    ],
                  ),
                  Text(
                    "Step ${_currentStep + 1} of 5",
                    style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Progress Bar
              LinearProgressIndicator(
                value: (_currentStep + 1) / 5,
                backgroundColor: const Color(0xFF27272A),
                color: const Color(0xFF7C3AED),
                minHeight: 4,
              ),
              const SizedBox(height: 28),

              // Step Content Area
              Expanded(
                child: SingleChildScrollView(
                  child: _buildCurrentStepView(),
                ),
              ),

              if (_statusMessage != null) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _statusMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: (_statusMessage!.contains("Invalid") || _statusMessage!.contains("must be different") || _statusMessage!.contains("failed"))
                          ? Colors.redAccent
                          : Colors.greenAccent,
                    ),
                  ),
                ),
              ],

              // Footer Action Bar
              Row(
                children: [
                  if (_currentStep > 0) ...[
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _isLoading ? null : _previousStep,
                      child: const Text("Back", style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 14),
                  ],
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 4,
                      ),
                      onPressed: _isLoading ? null : _handlePrimaryButtonPress,
                      child: _isLoading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : Text(
                              _currentStep == 4 ? "Complete Setup & Open Calculator" : "Continue",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handlePrimaryButtonPress() {
    switch (_currentStep) {
      case 0:
        _verifyUserAccount();
        break;
      case 1:
        _verifyContact1();
        break;
      case 2:
        _verifyContact2();
        break;
      case 3:
        _saveCustomSafetyCodes();
        break;
      case 4:
        _finishOnboarding();
        break;
    }
  }

  Widget _buildCurrentStepView() {
    switch (_currentStep) {
      case 0:
        return _buildStep0UserAccount();
      case 1:
        return _buildStep1PrimaryContact();
      case 2:
        return _buildStep2SecondaryContact();
      case 3:
        return _buildStep3CustomSafetyCodes();
      case 4:
        return _buildStep4Permissions();
      default:
        return Container();
    }
  }

  Widget _buildStep0UserAccount() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("User Account Verification", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text("Enter your account details and verify your mobile phone number.", style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4)),
        const SizedBox(height: 24),
        TextField(
          controller: _userNameController,
          decoration: InputDecoration(
            labelText: "Full Name",
            labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            filled: true,
            fillColor: const Color(0xFF18181B),
            prefixIcon: const Icon(Icons.person, color: Color(0xFF7C3AED)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF27272A))),
          ),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _userPhoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: "Mobile Phone Number",
            labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            filled: true,
            fillColor: const Color(0xFF18181B),
            prefixIcon: const Icon(Icons.phone, color: Color(0xFF7C3AED)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF27272A))),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _requestUserOtp,
            icon: const Icon(Icons.send),
            label: const Text("Send Verification SMS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ),
        if (_userOtpSent) ...[
          const SizedBox(height: 24),
          TextField(
            controller: _userOtpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: InputDecoration(
              labelText: "Enter 6-Digit SMS OTP",
              labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.greenAccent),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              filled: true,
              fillColor: const Color(0xFF18181B),
              prefixIcon: const Icon(Icons.lock_clock, color: Colors.greenAccent),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.greenAccent)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStep1PrimaryContact() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Primary Emergency Contact", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text("Every emergency contact must be independently verified via phone OTP.", style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4)),
        const SizedBox(height: 24),
        TextField(
          controller: _contact1NameController,
          decoration: InputDecoration(
            labelText: "Primary Contact Full Name",
            labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            filled: true,
            fillColor: const Color(0xFF18181B),
            prefixIcon: const Icon(Icons.contact_phone, color: Color(0xFF7C3AED)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _contact1PhoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: "Contact Phone Number",
            labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            filled: true,
            fillColor: const Color(0xFF18181B),
            prefixIcon: const Icon(Icons.phone_android, color: Color(0xFF7C3AED)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _requestContact1Otp,
            icon: const Icon(Icons.send),
            label: const Text("Verify Contact Phone via OTP", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ),
        if (_contact1OtpSent) ...[
          const SizedBox(height: 24),
          TextField(
            controller: _contact1OtpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: InputDecoration(
              labelText: "Enter Contact Verification OTP",
              labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.greenAccent),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              filled: true,
              fillColor: const Color(0xFF18181B),
              prefixIcon: const Icon(Icons.verified, color: Colors.greenAccent),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStep2SecondaryContact() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Secondary Emergency Contact", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text("Independently verify phone number for secondary emergency contact.", style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4)),
        const SizedBox(height: 24),
        TextField(
          controller: _contact2NameController,
          decoration: InputDecoration(
            labelText: "Secondary Contact Full Name",
            labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            filled: true,
            fillColor: const Color(0xFF18181B),
            prefixIcon: const Icon(Icons.contact_phone, color: Color(0xFF7C3AED)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _contact2PhoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: "Contact Phone Number",
            labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            filled: true,
            fillColor: const Color(0xFF18181B),
            prefixIcon: const Icon(Icons.phone_android, color: Color(0xFF7C3AED)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _requestContact2Otp,
            icon: const Icon(Icons.send),
            label: const Text("Verify Contact Phone via OTP", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ),
        if (_contact2OtpSent) ...[
          const SizedBox(height: 24),
          TextField(
            controller: _contact2OtpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: InputDecoration(
              labelText: "Enter Contact Verification OTP",
              labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.greenAccent),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              filled: true,
              fillColor: const Color(0xFF18181B),
              prefixIcon: const Icon(Icons.verified, color: Colors.greenAccent),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStep3CustomSafetyCodes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Configure Safety Expressions", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text("Choose your secret calculator activation and deactivation expressions. They must be different and will be encrypted securely.", style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4)),
        const SizedBox(height: 24),
        TextField(
          controller: _activationCodeController,
          decoration: InputDecoration(
            labelText: "Activation Expression (e.g. 99+99 or 88*88)",
            labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            filled: true,
            fillColor: const Color(0xFF18181B),
            prefixIcon: const Icon(Icons.lock_outline, color: Colors.greenAccent),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _deactivationCodeController,
          decoration: InputDecoration(
            labelText: "Deactivation Expression (e.g. 11+11 or 55-55)",
            labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            filled: true,
            fillColor: const Color(0xFF18181B),
            prefixIcon: const Icon(Icons.lock_open, color: Colors.redAccent),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    );
  }

  Widget _buildStep4Permissions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Safety Capabilities & Disguise Setup", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text("Enable required background services for emergency session protection.", style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4)),
        const SizedBox(height: 24),
        SwitchListTile(
          value: _locationPermissionGranted,
          onChanged: (v) => setState(() => _locationPermissionGranted = v),
          title: const Text("Background Live GPS Location", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          subtitle: const Text("Real-time location stream for emergency sessions", style: TextStyle(fontSize: 12, color: Colors.grey)),
          activeColor: const Color(0xFF7C3AED),
          tileColor: const Color(0xFF18181B),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        const SizedBox(height: 14),
        SwitchListTile(
          value: _cameraPermissionGranted,
          onChanged: (v) => setState(() => _cameraPermissionGranted = v),
          title: const Text("Discreet Photo Evidence", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          subtitle: const Text("Background photo capture during emergency", style: TextStyle(fontSize: 12, color: Colors.grey)),
          activeColor: const Color(0xFF7C3AED),
          tileColor: const Color(0xFF18181B),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        const SizedBox(height: 14),
        SwitchListTile(
          value: _micPermissionGranted,
          onChanged: (v) => setState(() => _micPermissionGranted = v),
          title: const Text("Ambient Audio Evidence", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          subtitle: const Text("Background audio recording during emergency", style: TextStyle(fontSize: 12, color: Colors.grey)),
          activeColor: const Color(0xFF7C3AED),
          tileColor: const Color(0xFF18181B),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ],
    );
  }
}
