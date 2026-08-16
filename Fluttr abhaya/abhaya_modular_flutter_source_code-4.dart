import 'package:flutter/material.dart';
import 'abhaya_modular_flutter_source_code-5.dart';
import 'domain/security_vault_service.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({Key? key}) : super(key: key);

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> with SingleTickerProviderStateMixin {
  String _calcInput = "";
  String _calcExpression = "";
  String _calcResult = "0";

  late AnimationController _blinkController;
  late Animation<Color?> _blinkColorAnimation;
  Color _targetBlinkColor = Colors.greenAccent;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _updateBlinkAnimation();
    SecurityVaultService.instance.syncTriggersFromDatabase();
  }

  void _updateBlinkAnimation() {
    _blinkColorAnimation = TweenSequence<Color?>(
      [
        TweenSequenceItem(
          tween: ColorTween(begin: Colors.white, end: _targetBlinkColor),
          weight: 25,
        ),
        TweenSequenceItem(
          tween: ColorTween(begin: _targetBlinkColor, end: Colors.white),
          weight: 25,
        ),
        TweenSequenceItem(
          tween: ColorTween(begin: Colors.white, end: _targetBlinkColor),
          weight: 25,
        ),
        TweenSequenceItem(
          tween: ColorTween(begin: _targetBlinkColor, end: Colors.white),
          weight: 25,
        ),
      ],
    ).animate(_blinkController);
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  void _triggerDoubleBlink(Color color) {
    setState(() {
      _targetBlinkColor = color;
      _updateBlinkAnimation();
    });
    _blinkController.forward(from: 0);
  }

  String _evaluateExpression(String expr) {
    try {
      String clean = expr.replaceAll('×', '*').replaceAll('÷', '/').replaceAll(' ', '');
      if (clean == "99+99") return "198";
      if (clean == "11+11") return "22";

      if (clean.contains('+')) {
        var parts = clean.split('+');
        if (parts.length == 2) {
          double a = double.parse(parts[0]);
          double b = double.parse(parts[1]);
          return _formatNum(a + b);
        }
      } else if (clean.contains('-')) {
        var parts = clean.split('-');
        if (parts.length == 2 && parts[0].isNotEmpty) {
          double a = double.parse(parts[0]);
          double b = double.parse(parts[1]);
          return _formatNum(a - b);
        }
      } else if (clean.contains('*')) {
        var parts = clean.split('*');
        if (parts.length == 2) {
          double a = double.parse(parts[0]);
          double b = double.parse(parts[1]);
          return _formatNum(a * b);
        }
      } else if (clean.contains('/')) {
        var parts = clean.split('/');
        if (parts.length == 2) {
          double a = double.parse(parts[0]);
          double b = double.parse(parts[1]);
          if (b == 0) return "Error";
          return _formatNum(a / b);
        }
      }

      double val = double.parse(clean);
      return _formatNum(val);
    } catch (_) {
      return "Error";
    }
  }

  String _formatNum(double n) {
    if (n == n.toInt()) return n.toInt().toString();
    return n.toString();
  }

  void _onButtonPressed(String value) async {
    if (value == 'C') {
      setState(() {
        _calcInput = "";
        _calcExpression = "";
        _calcResult = "0";
      });
    } else if (value == '=') {
      if (_calcInput.isEmpty && _calcExpression.isEmpty) return;
      String rawExpr = _calcExpression.isNotEmpty ? _calcExpression : _calcInput;
      String normalized = rawExpr.replaceAll('×', '*').replaceAll('÷', '/').replaceAll(' ', '');

      final safetyMgr = SafetyStateManager.instance;
      final vault = SecurityVaultService.instance;

      // 1. Covert Activation Trigger (e.g. 99+99)
      // Flowchart: 99+99 -> GREEN BLINK x2 -> EMERGENCY SESSION (Location, Evidence, Monitoring)
      if (vault.verifyActivationTrigger(normalized)) {
        setState(() {
          _calcExpression = rawExpr;
          _calcResult = _evaluateExpression(rawExpr);
          _calcInput = "";
        });

        if (safetyMgr.isEmergencyActive) {
          // IF ALREADY ACTIVE/ESCALATED: Evaluates as normal calculation without blinking!
        } else if (safetyMgr.state == SafetyState.inactive) {
          // Trigger GREEN BLINK x2 immediately
          _triggerDoubleBlink(const Color(0xFF22C55E));
          // Start Emergency Session & Subsystems (Location, Evidence, Monitoring)
          safetyMgr.requestActivation();
        }
        return;
      }

      // 2. Covert Deactivation Trigger (e.g. 11+11)
      // Flowchart: 11+11 -> RED BLINK x2 -> SESSION TERMINATED -> CALCULATOR
      if (vault.verifyDeactivationTrigger(normalized)) {
        setState(() {
          _calcExpression = rawExpr;
          _calcResult = _evaluateExpression(rawExpr);
          _calcInput = "";
        });

        if (safetyMgr.isEmergencyActive) {
          // Trigger RED BLINK x2 immediately
          _triggerDoubleBlink(const Color(0xFFEF4444));
          // Terminate Emergency Session & Stop Services
          safetyMgr.requestDeactivation();
        } else {
          // IF INACTIVE: Evaluates as normal calculation without blinking!
        }
        return;
      }

      // 3. Normal Calculation
      setState(() {
        _calcExpression = rawExpr;
        _calcResult = _evaluateExpression(rawExpr);
        _calcInput = "";
      });
    } else if (value == '+/-') {
      setState(() {
        if (_calcInput.startsWith('-')) {
          _calcInput = _calcInput.substring(1);
        } else if (_calcInput.isNotEmpty) {
          _calcInput = '-$_calcInput';
        }
      });
    } else {
      setState(() {
        _calcInput += value;
        _calcExpression = "";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              child: const Icon(Icons.calculate, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Text('Calculator Disguise', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 2,
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF18181B),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF27272A)),
                ),
                alignment: Alignment.bottomRight,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _calcExpression.isEmpty ? " " : _calcExpression,
                      style: const TextStyle(fontSize: 14, color: Colors.grey, fontFamily: 'monospace'),
                    ),
                    const SizedBox(height: 8),
                    AnimatedBuilder(
                      animation: _blinkController,
                      builder: (context, child) {
                        return Text(
                          _calcInput.isEmpty ? _calcResult : _calcInput,
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            color: _blinkController.isAnimating ? _blinkColorAnimation.value : Colors.white,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _buildButton("C", color: Colors.grey[850], textColor: Colors.amber),
                        _buildButton("( )", color: Colors.grey[850]),
                        _buildButton("%", color: Colors.grey[850]),
                        _buildButton("÷", color: const Color(0xFF2E1065), textColor: const Color(0xFFC4B5FD)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildButton("7"),
                        _buildButton("8"),
                        _buildButton("9"),
                        _buildButton("×", color: const Color(0xFF2E1065), textColor: const Color(0xFFC4B5FD)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildButton("4"),
                        _buildButton("5"),
                        _buildButton("6"),
                        _buildButton("-", color: const Color(0xFF2E1065), textColor: const Color(0xFFC4B5FD)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildButton("1"),
                        _buildButton("2"),
                        _buildButton("3"),
                        _buildButton("+", color: const Color(0xFF2E1065), textColor: const Color(0xFFC4B5FD)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildButton("+/-"),
                        _buildButton("0"),
                        _buildButton("."),
                        _buildButton("=", color: const Color(0xFF7C3AED), textColor: Colors.white),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButton(String text, {Color? color, Color? textColor}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: color ?? const Color(0xFF27272A),
            foregroundColor: textColor ?? Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          onPressed: () => _onButtonPressed(text),
          child: Text(text, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}