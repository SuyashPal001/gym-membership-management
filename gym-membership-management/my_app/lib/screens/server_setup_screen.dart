import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../constants/app_colors.dart';
import 'onboarding_screen.dart';

/// Shown on first launch until the user saves a working API base URL.
class ServerSetupScreen extends StatefulWidget {
  const ServerSetupScreen({super.key});

  @override
  State<ServerSetupScreen> createState() => _ServerSetupScreenState();
}

class _ServerSetupScreenState extends State<ServerSetupScreen> {
  /// Empty by default — a partial IP like "192.168.1." causes "Failed host lookup".
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _applyEmulatorDefault() async {
    setState(() {
      _controller.text = '10.0.2.2:5001';
      _error = null;
    });
  }

  Future<void> _testAndContinue() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final normalized = ApiConfig.normalizeBaseUrl(_controller.text);
      await ApiConfig.verifyBackendReachable(normalized);
      await ApiConfig.setSavedBaseUrl(_controller.text);
      if (!mounted) return;
      await ApiConfig.initialize();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => OnboardingScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Text(
                'Connect to your gym server',
                style: TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'The API runs on your PC. On the PC, open Command Prompt and run ipconfig — copy the '
                'full Wi‑Fi IPv4 (four numbers, e.g. 192.168.1.15), then add :5001.\n\n'
                'Type the full address below — do not stop at 192.168.1.\n\n'
                'Allow port 5001 in Windows Firewall (Private networks).\n\n'
                'Android emulator: tap the link below for 10.0.2.2:5001.',
                style: TextStyle(color: AppColors.secondaryText, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _controller,
                keyboardType: TextInputType.url,
                autocorrect: false,
                style: const TextStyle(color: AppColors.primaryText),
                decoration: InputDecoration(
                  labelText: 'PC address',
                  hintText: '192.168.x.x:5001',
                  labelStyle: const TextStyle(color: AppColors.secondaryText),
                  hintStyle: TextStyle(color: AppColors.secondaryText.withValues(alpha: 0.7)),
                  filled: true,
                  fillColor: AppColors.cardBackground,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : _testAndContinue,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _busy
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : const Text('Test connection & continue'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _busy ? null : _applyEmulatorDefault,
                child: Text(
                  'I use Android emulator → fill 10.0.2.2:5001',
                  style: TextStyle(color: AppColors.accent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

