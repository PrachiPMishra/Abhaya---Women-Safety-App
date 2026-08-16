import 'package:flutter/material.dart';
import 'domain/safety_state_manager.dart';
import 'domain/security_vault_service.dart';
import 'domain/tamper_monitor.dart';

/// Covert Security Calculator Interface
class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({Key? key}) : super(key: key);

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  String _calcInput = "";
  String _calcExpression = "";
  String _calcResult = "0";

  Color _digitTextColor = Colors.white;
  bool _isBlinking = false;

  void _triggerDoubleBlink(Color color) async {
    if (_isBlinking) return;
    setState(() {
      _isBlinking = true;
      _digitTextColor = color;
    });

    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    setState(() => _digitTextColor = Colors.white);

    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    setState(() => _digitTextColor = color);

    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    setState(() {
      _digitTextColor = Colors.white;
      _isBlinking = false;
    });
  }

  void _onButtonPressed(String value) async {
    if (value == 'C') {
      // Clear All
      setState(() {
        _calcInput = "";
        _calcExpression = "";
        _calcResult = "0";
      });
    } else if (value == 'DEL' || value == '⌫' || value == 'BACKSPACE') {
      // Backspace: Delete single character
      setState(() {
        if (_calcInput.isNotEmpty) {
          _calcInput = _calcInput.substring(0, _calcInput.length - 1);
        }
      });
    } else if (value == '=') {
      if (_calcInput.isEmpty && _calcExpression.isEmpty) return;
      String rawExpr = _calcInput.isNotEmpty ? _calcInput : _calcExpression;
      String normalized = rawExpr.replaceAll('×', '*').replaceAll('÷', '/').replaceAll(' ', '');

      final safetyMgr = SafetyStateManager.instance;
      final vault = SecurityVaultService.instance;

      // 1. Covert Activation Trigger (e.g. 99+99 or 9999)
      if (vault.verifyActivationTrigger(normalized)) {
        setState(() {
          _calcExpression = rawExpr;
          _calcResult = _evaluateExpression(rawExpr);
          _calcInput = "";
        });

        _triggerDoubleBlink(const Color(0xFF22C55E)); // Bright Green digit blink
        await safetyMgr.requestActivation();
        return;
      }

      // 2. Covert Deactivation Trigger (e.g. 11+11 or 1111)
      if (vault.verifyDeactivationTrigger(normalized)) {
        setState(() {
          _calcExpression = rawExpr;
          _calcResult = _evaluateExpression(rawExpr);
          _calcInput = "";
        });

        _triggerDoubleBlink(const Color(0xFFEF4444)); // Bright Red digit blink
        await safetyMgr.requestDeactivation();
        return;
      }

      // 3. Covert Critical Escalation Trigger (e.g. 88+88 or 8888)
      if (vault.verifyCriticalEscalationTrigger(normalized)) {
        setState(() {
          _calcExpression = rawExpr;
          _calcResult = _evaluateExpression(rawExpr);
          _calcInput = "";
        });

        _triggerDoubleBlink(const Color(0xFFEF4444)); // Bright Red digit blink
        await TamperMonitorController.instance.handlePowerOffAttempt();
        return;
      }

      // 4. Normal Calculation
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

  String _evaluateExpression(String expr) {
    try {
      String clean = expr.replaceAll('×', '*').replaceAll('÷', '/').replaceAll(' ', '');
      if (clean.isEmpty) return "0";

      if (clean == "99+99") return "198";
      if (clean == "11+11") return "22";
      if (clean == "88+88") return "176";
      if (clean == "9999") return "9999";
      if (clean == "1111") return "1111";

      // Basic math operations evaluation
      if (clean.contains('+')) {
        final parts = clean.split('+');
        if (parts.length == 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
          double a = double.parse(parts[0]);
          double b = double.parse(parts[1]);
          return _formatNum(a + b);
        }
      } else if (clean.contains('-') && !clean.startsWith('-')) {
        final parts = clean.split('-');
        if (parts.length == 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
          double a = double.parse(parts[0]);
          double b = double.parse(parts[1]);
          return _formatNum(a - b);
        }
      } else if (clean.contains('*')) {
        final parts = clean.split('*');
        if (parts.length == 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
          double a = double.parse(parts[0]);
          double b = double.parse(parts[1]);
          return _formatNum(a * b);
        }
      } else if (clean.contains('/')) {
        final parts = clean.split('/');
        if (parts.length == 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
          double a = double.parse(parts[0]);
          double b = double.parse(parts[1]);
          if (b == 0) return "Error";
          return _formatNum(a / b);
        }
      } else if (clean.contains('%')) {
        final parts = clean.split('%');
        if (parts.length == 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
          double a = double.parse(parts[0]);
          double b = double.parse(parts[1]);
          return _formatNum(a % b);
        }
      }

      double singleVal = double.parse(clean);
      return _formatNum(singleVal);
    } catch (_) {
      return "0";
    }
  }

  String _formatNum(double n) {
    if (n == n.toInt()) {
      return n.toInt().toString();
    }
    return n.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: SafeArea(
        child: Column(
          children: [
            // Covert Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Calculator", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  Icon(Icons.calculate, color: Colors.grey[600], size: 20),
                ],
              ),
            ),

            // Display Area with ONLY DIGITS Blinking Colorfully
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                alignment: Alignment.bottomRight,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
 crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _calcExpression.isNotEmpty ? _calcExpression : (_calcInput.isEmpty ? "0" : _calcInput),
                      style: const TextStyle(fontSize: 28, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _calcResult,
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: _digitTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Keypad Grid
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF121214),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildButton("C", color: const Color(0xFF27272A), textColor: Colors.redAccent),
                      _buildButton("+/-", color: const Color(0xFF27272A)),
                      _buildButton("%", color: const Color(0xFF27272A)),
                      _buildButton("⌫", color: const Color(0xFF27272A), textColor: Colors.amber),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildButton("7"),
                      _buildButton("8"),
                      _buildButton("9"),
                      _buildButton("÷", color: const Color(0xFF7C3AED)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildButton("4"),
                      _buildButton("5"),
                      _buildButton("6"),
                      _buildButton("×", color: const Color(0xFF7C3AED)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildButton("1"),
                      _buildButton("2"),
                      _buildButton("3"),
                      _buildButton("-", color: const Color(0xFF7C3AED)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildButton("0"),
                      _buildButton("."),
                      _buildButton("+", color: const Color(0xFF7C3AED)),
                      _buildButton("=", color: const Color(0xFF7C3AED)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButton(
    String label, {
    Color color = const Color(0xFF18181B),
    Color textColor = Colors.white,
    int flex = 1,
  }) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: SizedBox(
          height: 62,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: textColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            onPressed: () => _onButtonPressed(label),
            child: label == "⌫"
                ? const Icon(Icons.backspace_outlined, color: Colors.amber, size: 22)
                : Text(label, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
          ),
        ),
      ),
    );
  }
}