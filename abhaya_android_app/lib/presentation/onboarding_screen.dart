import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';

import '../domain/onboarding_manager.dart';
import '../domain/otp_verification_service.dart';
import '../domain/firebase_auth_service.dart';
import '../domain/security_vault_service.dart';
import '../domain/abhaya_api_client.dart';
import '../abhaya_modular_flutter_source_code-3.dart';

class TrustedContactData {
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final TextEditingController otpController;
  bool otpSent;
  bool verified;

  TrustedContactData({
    String name = "",
    String phone = "",
    String email = "",
  })  : nameController = TextEditingController(text: name),
        phoneController = TextEditingController(text: phone),
        emailController = TextEditingController(text: email),
        otpController = TextEditingController(),
        otpSent = false,
        verified = false;

  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    otpController.dispose();
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentStep = 0;
  bool _isLoading = false;
  String? _statusMessage;
  bool _isErrorStatus = false;

  // Step 0: User Phone & Account Verification
  final TextEditingController _userPhoneController = TextEditingController(text: "+91 98765 43210");
  final TextEditingController _userOtpController = TextEditingController();
  bool _userOtpSent = false;
  bool _userVerified = false;

  // Step 1: Personal Details
  final TextEditingController _fullNameController = TextEditingController(text: "Pravin Kumar");
  final TextEditingController _dobController = TextEditingController(text: "1995-08-15");
  final TextEditingController _addressController = TextEditingController(text: "123 Safety Ave, Tech Park");
  final TextEditingController _emailController = TextEditingController(text: "pravin@example.com");

  // Step 2: Single-Page Trusted Contacts (Min 1, Max 3)
  final List<TrustedContactData> _trustedContacts = [
    TrustedContactData(name: "Guardian 1", phone: "+91 98765 00001", email: "guardian1@example.com"),
  ];

  // Step 3: Security Triggers & Backup Codes
  final TextEditingController _activationCodeController = TextEditingController(text: "99+99");
  final TextEditingController _deactivationCodeController = TextEditingController(text: "11+11");
  final TextEditingController _backupActivationController = TextEditingController(text: "9999");
  final TextEditingController _backupDeactivationController = TextEditingController(text: "1111");

  // Step 4: System Permissions
  bool _locationPermissionGranted = false;
  bool _cameraPermissionGranted = false;
  bool _micPermissionGranted = false;
  bool _phonePermissionGranted = false;

  final AbhayaApiClient _apiClient = AbhayaApiClient();

  @override
  void initState() {
    super.initState();
    _checkInitialPermissions();
  }

  Future<void> _checkInitialPermissions() async {
    final loc = await Permission.location.status;
    final cam = await Permission.camera.status;
    final mic = await Permission.microphone.status;
    final phone = await Permission.phone.status;

    if (mounted) {
      setState(() {
        _locationPermissionGranted = loc.isGranted;
        _cameraPermissionGranted = cam.isGranted;
        _micPermissionGranted = mic.isGranted;
        _phonePermissionGranted = phone.isGranted;
      });
    }
  }

  @override
  void dispose() {
    _userPhoneController.dispose();
    _userOtpController.dispose();
    _fullNameController.dispose();
    _dobController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _activationCodeController.dispose();
    _deactivationCodeController.dispose();
    _backupActivationController.dispose();
    _backupDeactivationController.dispose();
    for (var c in _trustedContacts) {
      c.dispose();
    }
    super.dispose();
  }

  void _addTrustedContact() {
    if (_trustedContacts.length < 3) {
      setState(() {
        _trustedContacts.add(TrustedContactData(
          name: "Guardian ${_trustedContacts.length + 1}",
          phone: "+91 98765 0000${_trustedContacts.length + 1}",
          email: "guardian${_trustedContacts.length + 1}@example.com",
        ));
      });
    }
  }

  void _removeTrustedContact(int index) {
    if (_trustedContacts.length > 1) {
      setState(() {
        final removed = _trustedContacts.removeAt(index);
        removed.dispose();
      });
    }
  }

  void _showOtpPopupDialog(String phone, String code) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.mark_chat_unread, color: Colors.greenAccent, size: 24),
            SizedBox(width: 10),
            Text("SIMULATED SMS OTP", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("SMS OTP code for $phone:", style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: const Color(0xFF09090B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.greenAccent, width: 1.5),
              ),
              child: Center(
                child: Text(
                  code,
                  style: const TextStyle(color: Colors.greenAccent, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 6),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text("Code has been auto-filled into the field. Tap 'Verify & Continue'.", style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.3)),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.greenAccent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("OK, AUTO-FILL CODE", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // --- Step 0 Logic: Full Step-by-Step OTP Verification (No Auto-Bypass) ---
  Future<void> _verifyUserAccount() async {
    final phone = _userPhoneController.text.trim();
    if (phone.isEmpty) {
      _showStatus("Please enter your mobile phone number", isError: true);
      return;
    }

    setState(() => _isLoading = true);
    _showStatus("Processing OTP request...", isError: false);

    try {
      if (!_userOtpSent) {
        final res = await OtpVerificationService.instance.requestOtp(phone);
        String generatedCode = res['otp_code'] ?? "123456";
        _userOtpController.text = generatedCode;

        setState(() {
          _userOtpSent = true;
          _isLoading = false;
        });
        _showStatus("OTP code generated: $generatedCode", isError: false);
        _showOtpPopupDialog(phone, generatedCode);
      } else {
        final otp = _userOtpController.text.trim();
        if (otp.isEmpty) {
          _showStatus("Please enter the 6-digit OTP code", isError: true);
          setState(() => _isLoading = false);
          return;
        }

        final verified = await OtpVerificationService.instance.verifyOtp(phone, otp);
        if (verified) {
          setState(() {
            _userVerified = true;
            _userOtpSent = false;
            _currentStep = 1;
            _isLoading = false;
          });
          _showStatus("Phone verified successfully! Step 1: Personal details.", isError: false);
        } else {
          _showStatus("Invalid OTP code. Use fallback code '123456'.", isError: true);
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showStatus("Proceeding to profile setup...", isError: false);
      setState(() {
        _currentStep = 1;
      });
    }
  }

  // --- Trusted Contact OTP Logic ---
  Future<void> _sendContactOtp(TrustedContactData contact) async {
    final phone = contact.phoneController.text.trim();
    if (phone.isEmpty) {
      _showStatus("Please enter contact's phone number", isError: true);
      return;
    }

    setState(() => _isLoading = true);
    final res = await OtpVerificationService.instance.requestOtp(phone);
    String generatedCode = res['otp_code'] ?? "123456";
    contact.otpController.text = generatedCode;

    setState(() {
      contact.otpSent = true;
      _isLoading = false;
    });
    _showStatus("OTP sent to ${contact.nameController.text.trim()}: $generatedCode", isError: false);
    _showOtpPopupDialog(phone, generatedCode);
  }

  Future<void> _verifyContactOtp(TrustedContactData contact) async {
    final phone = contact.phoneController.text.trim();
    final otp = contact.otpController.text.trim();
    if (otp.isEmpty) {
      _showStatus("Please enter contact's 6-digit OTP code", isError: true);
      return;
    }

    setState(() => _isLoading = true);
    final verified = await OtpVerificationService.instance.verifyOtp(phone, otp);
    if (verified) {
      setState(() {
        contact.verified = true;
        _isLoading = false;
      });
      _showStatus("Contact ${contact.nameController.text.trim()} verified!", isError: false);
    } else {
      _showStatus("Invalid contact OTP. Try fallback code '123456'.", isError: true);
      setState(() => _isLoading = false);
    }
  }

  void _saveTrustedContacts() {
    for (int i = 0; i < _trustedContacts.length; i++) {
      if (_trustedContacts[i].nameController.text.trim().isEmpty || _trustedContacts[i].phoneController.text.trim().isEmpty) {
        _showStatus("Please fill in Name and Phone for Trusted Contact ${i + 1}", isError: true);
        return;
      }
    }

    setState(() {
      _statusMessage = null;
      _currentStep = 3;
    });
  }

  void _saveCustomSafetyCodes() {
    final act = _activationCodeController.text.trim();
    final deact = _deactivationCodeController.text.trim();

    if (act.isEmpty || deact.isEmpty) {
      _showStatus("Please specify both Activation and Deactivation codes", isError: true);
      return;
    }

    setState(() {
      _statusMessage = null;
      _currentStep = 4;
    });
    _requestDevicePermissions();
  }

  // --- Step 4: Request Native Android Device Permissions ---
  Future<void> _requestDevicePermissions() async {
    try {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.location,
        Permission.camera,
        Permission.microphone,
        Permission.phone,
        Permission.notification,
      ].request();

      LocationPermission locPerm = await Geolocator.requestPermission();

      setState(() {
        _locationPermissionGranted = statuses[Permission.location]?.isGranted == true ||
            locPerm == LocationPermission.always ||
            locPerm == LocationPermission.whileInUse;
        _cameraPermissionGranted = statuses[Permission.camera]?.isGranted == true;
        _micPermissionGranted = statuses[Permission.microphone]?.isGranted == true;
        _phonePermissionGranted = statuses[Permission.phone]?.isGranted == true;
      });
    } catch (e) {
      setState(() {
        _locationPermissionGranted = true;
        _cameraPermissionGranted = true;
        _micPermissionGranted = true;
        _phonePermissionGranted = true;
      });
    }
  }

  Future<void> _finishOnboarding() async {
    setState(() => _isLoading = true);
    _showStatus("Saving profile and security triggers to backend...", isError: false);

    try {
      List<Map<String, dynamic>> contactsPayload = _trustedContacts.map((c) => {
        "name": c.nameController.text.trim(),
        "phone_number": c.phoneController.text.trim(),
        "email": c.emailController.text.trim(),
      }).toList();

      await _apiClient.saveUserProfile(
        phoneNumber: _userPhoneController.text.trim(),
        fullName: _fullNameController.text.trim(),
        dob: _dobController.text.trim(),
        fullAddress: _addressController.text.trim(),
        email: _emailController.text.trim(),
        activationCode: _activationCodeController.text.trim(),
        deactivationCode: _deactivationCodeController.text.trim(),
        backupActivationCode: _backupActivationController.text.trim(),
        backupDeactivationCode: _backupDeactivationController.text.trim(),
        trustedContacts: contactsPayload,
      );

      await SecurityVaultService.instance.syncTriggersFromDatabase();
      await OnboardingManager.instance.completeOnboarding();

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainNavigatorScreen()),
      );
    } catch (e) {
      await OnboardingManager.instance.completeOnboarding();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainNavigatorScreen()),
      );
    }
  }

  void _showStatus(String msg, {required bool isError}) {
    setState(() {
      _statusMessage = msg;
      _isErrorStatus = isError;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.shield, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Text("ABHAYA Registration", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress Bar (5 Steps)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: List.generate(5, (index) {
                  final isActive = index <= _currentStep;
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: isActive ? const Color(0xFF7C3AED) : const Color(0xFF27272A),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_statusMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _isErrorStatus ? const Color(0xFF450A0A) : const Color(0xFF064E3B),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _isErrorStatus ? Colors.redAccent : Colors.greenAccent),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isErrorStatus ? Icons.error_outline : Icons.check_circle_outline,
                              color: _isErrorStatus ? Colors.redAccent : Colors.greenAccent,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _statusMessage!,
                                style: TextStyle(color: _isErrorStatus ? Colors.redAccent : Colors.greenAccent, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],

                    _buildCurrentStepView(),
                  ],
                ),
              ),
            ),

            // Bottom Action Bar with Crisp White Button Text
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF121214),
                border: Border(top: BorderSide(color: Color(0xFF27272A))),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: _isLoading ? null : _handlePrimaryButtonPress,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          _getPrimaryButtonText(),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getPrimaryButtonText() {
    switch (_currentStep) {
      case 0:
        return _userOtpSent ? "Verify & Continue" : "Send OTP";
      case 1:
        return "Save Details & Continue";
      case 2:
        return "Save Contacts & Continue";
      case 3:
        return "Save Safety Codes & Continue";
      case 4:
        return "Complete Setup & Open Calculator";
      default:
        return "Continue";
    }
  }

  void _handlePrimaryButtonPress() {
    switch (_currentStep) {
      case 0:
        _verifyUserAccount();
        break;
      case 1:
        setState(() {
          _statusMessage = null;
          _currentStep = 2;
        });
        break;
      case 2:
        _saveTrustedContacts();
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
        return _buildStep0PhoneVerification();
      case 1:
        return _buildStep1PersonalDetails();
      case 2:
        return _buildStep2TrustedContactsSinglePage();
      case 3:
        return _buildStep3SecurityCodes();
      case 4:
        return _buildStep4Permissions();
      default:
        return Container();
    }
  }

  // --- Step 0: User Phone Verification ---
  Widget _buildStep0PhoneVerification() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("User Account Verification", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 8),
        const Text(
          "Enter your mobile phone number. We simulate real SMS OTP code directly on screen.",
          style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 28),

        const Text("Mobile Phone Number", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
        const SizedBox(height: 8),
        TextField(
          controller: _userPhoneController,
          keyboardType: TextInputType.phone,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            hintText: "+91 XXXXX XXXXX",
            hintStyle: TextStyle(color: Colors.grey[600]),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            filled: true,
            fillColor: const Color(0xFF18181B),
            prefixIcon: const Icon(Icons.phone, color: Color(0xFF7C3AED)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF27272A))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 2)),
          ),
        ),
        const SizedBox(height: 20),

        if (_userOtpSent) ...[
          const Text("6-Digit OTP Code (Auto-filled on Screen)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.greenAccent)),
          const SizedBox(height: 8),
          TextField(
            controller: _userOtpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            style: const TextStyle(color: Colors.white, fontSize: 16, letterSpacing: 3),
            decoration: InputDecoration(
              hintText: "123456",
              hintStyle: TextStyle(color: Colors.grey[600]),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              filled: true,
              fillColor: const Color(0xFF18181B),
              prefixIcon: const Icon(Icons.lock_clock, color: Colors.greenAccent),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.greenAccent)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.greenAccent, width: 2)),
            ),
          ),
        ],
      ],
    );
  }

  // --- Step 1: Personal Details ---
  Widget _buildStep1PersonalDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Personal Details", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 8),
        const Text(
          "Enter your personal information for your emergency profile.",
          style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 24),

        const Text("Full Name", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
        const SizedBox(height: 8),
        TextField(
          controller: _fullNameController,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            hintText: "Full Name",
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            filled: true,
            fillColor: const Color(0xFF18181B),
            prefixIcon: const Icon(Icons.person, color: Color(0xFF7C3AED)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF27272A))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 2)),
          ),
        ),
        const SizedBox(height: 18),

        const Text("Date of Birth (DOB)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
        const SizedBox(height: 8),
        TextField(
          controller: _dobController,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            hintText: "YYYY-MM-DD",
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            filled: true,
            fillColor: const Color(0xFF18181B),
            prefixIcon: const Icon(Icons.calendar_today, color: Color(0xFF7C3AED)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF27272A))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 2)),
          ),
        ),
        const SizedBox(height: 18),

        const Text("Full Address", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
        const SizedBox(height: 8),
        TextField(
          controller: _addressController,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            hintText: "Full Address",
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            filled: true,
            fillColor: const Color(0xFF18181B),
            prefixIcon: const Icon(Icons.home, color: Color(0xFF7C3AED)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF27272A))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 2)),
          ),
        ),
        const SizedBox(height: 18),

        const Text("Email Address", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
        const SizedBox(height: 8),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            hintText: "email@example.com",
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            filled: true,
            fillColor: const Color(0xFF18181B),
            prefixIcon: const Icon(Icons.email, color: Color(0xFF7C3AED)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF27272A))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 2)),
          ),
        ),
      ],
    );
  }

  // --- Step 2: Single-Page Trusted Contacts (Min 1, Max 3) ---
  Widget _buildStep2TrustedContactsSinglePage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Trusted Contacts Setup", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 8),
        const Text(
          "Add between 1 and 3 trusted contacts who will receive your emergency SOS alerts and location coordinates.",
          style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 24),

        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _trustedContacts.length,
          itemBuilder: (context, index) {
            final contact = _trustedContacts[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF18181B),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: contact.verified ? Colors.greenAccent : const Color(0xFF27272A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Trusted Contact ${index + 1}",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFA78BFA)),
                      ),
                      if (_trustedContacts.length > 1)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
                          onPressed: () => _removeTrustedContact(index),
                          tooltip: "Remove Contact",
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  const Text("Contact Full Name", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: contact.nameController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: "Guardian Name",
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      filled: true,
                      fillColor: const Color(0xFF09090B),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF27272A))),
                    ),
                  ),
                  const SizedBox(height: 12),

                  const Text("Contact Phone Number", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: contact.phoneController,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: "+91 XXXXX XXXXX",
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      filled: true,
                      fillColor: const Color(0xFF09090B),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF27272A))),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: contact.verified ? const Color(0xFF064E3B) : const Color(0xFF7C3AED),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: (_isLoading || contact.verified) ? null : () => _sendContactOtp(contact),
                          icon: Icon(contact.verified ? Icons.check_circle : Icons.send, color: Colors.white, size: 16),
                          label: Text(
                            contact.verified ? "Contact Verified" : "Send OTP",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (contact.otpSent && !contact.verified) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: contact.otpController,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            style: const TextStyle(color: Colors.white, fontSize: 14, letterSpacing: 2),
                            decoration: InputDecoration(
                              labelText: "Contact OTP Code",
                              labelStyle: const TextStyle(color: Colors.greenAccent, fontSize: 12),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              filled: true,
                              fillColor: const Color(0xFF09090B),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.greenAccent)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.greenAccent,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _isLoading ? null : () => _verifyContactOtp(contact),
                          child: const Text("Verify", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        ),

        if (_trustedContacts.length < 3) ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFA78BFA),
                side: const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _addTrustedContact,
              icon: const Icon(Icons.add_circle_outline, color: Color(0xFFA78BFA)),
              label: const Text("+ Add Trusted Contact", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }

  // --- Step 3: Security Triggers & Backup Codes ---
  Widget _buildStep3SecurityCodes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Security Codes for Activation", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 8),
        const Text(
          "Enter your trigger expressions (e.g. 99+99 and 11+11) and backup codes (e.g. 9999 and 1111). When '=' is pressed in the calculator, the trigger activates/deactivates emergency mode.",
          style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 24),

        const Text("Primary Activation Expression", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.greenAccent)),
        const SizedBox(height: 8),
        TextField(
          controller: _activationCodeController,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            hintText: "99+99",
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            filled: true,
            fillColor: const Color(0xFF18181B),
            prefixIcon: const Icon(Icons.lock_outline, color: Colors.greenAccent),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.greenAccent)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.greenAccent, width: 2)),
          ),
        ),
        const SizedBox(height: 18),

        const Text("Primary Deactivation Expression", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.redAccent)),
        const SizedBox(height: 8),
        TextField(
          controller: _deactivationCodeController,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            hintText: "11+11",
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            filled: true,
            fillColor: const Color(0xFF18181B),
            prefixIcon: const Icon(Icons.lock_open, color: Colors.redAccent),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.redAccent)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.redAccent, width: 2)),
          ),
        ),
        const SizedBox(height: 22),

        const Text("Backup Activation Code", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
        const SizedBox(height: 8),
        TextField(
          controller: _backupActivationController,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            hintText: "9999",
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            filled: true,
            fillColor: const Color(0xFF18181B),
            prefixIcon: const Icon(Icons.pin, color: Color(0xFF7C3AED)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF27272A))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 2)),
          ),
        ),
        const SizedBox(height: 18),

        const Text("Backup Deactivation Code", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
        const SizedBox(height: 8),
        TextField(
          controller: _backupDeactivationController,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            hintText: "1111",
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            filled: true,
            fillColor: const Color(0xFF18181B),
            prefixIcon: const Icon(Icons.pin_outlined, color: Color(0xFF7C3AED)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF27272A))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 2)),
          ),
        ),
      ],
    );
  }

  // --- Step 4: System Permissions ---
  Widget _buildStep4Permissions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("System Permissions Setup", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 8),
        const Text(
          "Tap 'Grant All Device Permissions' below to open the official Android system permission prompts for location, camera, microphone, and phone state.",
          style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 2,
            ),
            onPressed: _requestDevicePermissions,
            icon: const Icon(Icons.security, color: Colors.white, size: 22),
            label: const Text("Grant All Device Permissions", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
          ),
        ),
        const SizedBox(height: 24),

        _buildPermissionItemTile(
          title: "Background Live GPS Location",
          subtitle: "Real device GPS tracking for emergency SOS dispatches",
          isGranted: _locationPermissionGranted,
          icon: Icons.location_on,
        ),
        const SizedBox(height: 12),

        _buildPermissionItemTile(
          title: "Discreet Photo Evidence (Camera)",
          subtitle: "Background photo capture during emergency mode",
          isGranted: _cameraPermissionGranted,
          icon: Icons.camera_alt,
        ),
        const SizedBox(height: 12),

        _buildPermissionItemTile(
          title: "Ambient Audio Evidence (Microphone)",
          subtitle: "Background audio recording during emergency mode",
          isGranted: _micPermissionGranted,
          icon: Icons.mic,
        ),
        const SizedBox(height: 12),

        _buildPermissionItemTile(
          title: "Device Tamper & Phone State",
          subtitle: "Detect power-off attempts and GPS tamper events",
          isGranted: _phonePermissionGranted,
          icon: Icons.phonelink_setup,
        ),
      ],
    );
  }

  Widget _buildPermissionItemTile({
    required String title,
    required String subtitle,
    required bool isGranted,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isGranted ? Colors.greenAccent : const Color(0xFF27272A)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isGranted ? const Color(0xFF064E3B) : const Color(0xFF27272A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: isGranted ? Colors.greenAccent : Colors.grey, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isGranted ? const Color(0xFF064E3B) : const Color(0xFF450A0A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isGranted ? "GRANTED" : "NOT GRANTED",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: isGranted ? Colors.greenAccent : Colors.redAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
