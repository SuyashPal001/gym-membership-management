import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import 'main_scaffold.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();

  final _studioNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();

  int _currentPage = 0;
  bool _isLoading = false;

  void _nextPage() {
    if (!_formKey.currentState!.validate()) return;
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutQuint,
      );
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutQuint,
      );
    }
  }

  Future<void> _handleLaunch() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final setupData = await ApiService.setupGym({
        'gym_name': _studioNameController.text.trim(),
        'owner_name': _ownerNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
      });

      final gymId = setupData['gym_id']?.toString();
      if (gymId != null) {
        await AuthService.storeGymId(gymId);
      }

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => MainScaffold()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Launch failed: $e', style: GoogleFonts.inter()),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [Color(0xFF1A1A1A), Color(0xFF000000)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom Top Navigation
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    if (_currentPage > 0)
                      IconButton(
                        onPressed: _isLoading ? null : _prevPage,
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                        tooltip: 'Back',
                      )
                    else
                      const SizedBox(width: 48),
                    
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 48.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: (_currentPage + 1) / 3,
                            backgroundColor: Colors.white.withOpacity(0.05),
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
                            minHeight: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),

              Expanded(
                child: Form(
                  key: _formKey,
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (idx) => setState(() => _currentPage = idx),
                    children: [
                      _buildStep(
                        headline: 'What should we call your studio?',
                        subtitle: 'Tell us about your studio.',
                        content: [
                          _buildInputField(
                            label: 'Studio Name',
                            controller: _studioNameController,
                            hint: 'e.g. Iron Paradise Gym',
                          ),
                          _buildInputField(
                            label: 'Owner Name',
                            controller: _ownerNameController,
                            hint: 'e.g. Rahul Sharma',
                          ),
                        ],
                      ),
                      _buildStep(
                        headline: 'Where are you located?',
                        subtitle: 'Where can members find you?',
                        content: [
                          _buildInputField(
                            label: 'City',
                            controller: _cityController,
                            hint: 'e.g. Mumbai',
                          ),
                          _buildInputField(
                            label: 'State / Region',
                            controller: _stateController,
                            hint: 'e.g. Maharashtra',
                          ),
                        ],
                      ),
                      _buildStep(
                        headline: 'Final touch: How can we reach you?',
                        subtitle: 'Share your business contact.',
                        content: [
                          _buildInputField(
                            label: 'Phone Number',
                            controller: _phoneController,
                            hint: 'e.g. 9876543210',
                            keyboardType: TextInputType.phone,
                            isPhone: true,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Navigation
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : (_currentPage == 2 ? _handleLaunch : _nextPage),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            _currentPage == 2 ? 'LAUNCH STUDIO 🚀' : 'CONTINUE',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              letterSpacing: 1,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep({
    required String headline,
    required String subtitle,
    required List<Widget> content,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            headline,
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.white.withOpacity(0.4),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 40),
          ...content,
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    bool isPhone = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 8),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: GoogleFonts.inter(fontSize: 15, color: Colors.white),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: Colors.white.withOpacity(0.04),
            hintText: hint,
            hintStyle: GoogleFonts.inter(color: Colors.white24, fontSize: 14),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
            ),
            errorStyle: const TextStyle(height: 0.8),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) return 'Required';
            if (isPhone && (value.length < 10 || !RegExp(r'^[0-9]+$').hasMatch(value))) {
              return 'Invalid Phone';
            }
            return null;
          },
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
