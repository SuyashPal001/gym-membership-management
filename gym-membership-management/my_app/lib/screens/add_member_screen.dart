import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../models/member.dart';
import '../services/api_exception.dart';
import '../services/api_service.dart';

class AddMemberScreen extends StatefulWidget {
  @override
  _AddMemberScreenState createState() => _AddMemberScreenState();
}

class _AddMemberScreenState extends State<AddMemberScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  
  List<MembershipType> _plans = [];
  MembershipType? _selectedPlan;
  bool _isTrial = false;
  bool _paymentCollected = true;
  bool _isLoading = false;
  bool _isFetchingPlans = true;
  String? _plansError;
  String? _nameError;
  String? _phoneError;
  String? _planError;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _loadPlans();
    _nameController.addListener(() {
      if (_nameError != null) setState(() { _nameError = null; });
    });
    _phoneController.addListener(() {
      if (_phoneError != null) setState(() { _phoneError = null; });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadPlans() async {
    setState(() {
      _isFetchingPlans = true;
      _plansError = null;
    });
    try {
      final plans = await ApiService.fetchMembershipTypes();
      debugPrint('[AddMember] plans loaded: ${plans.length}');
      if (!mounted) return;
      setState(() {
        _plans = plans;
        _selectedPlan = null;
        _plansError = null;
        _isFetchingPlans = false;
      });
    } on ApiException catch (e) {
      debugPrint('[AddMember] plans ApiException ${e.statusCode}: ${e.message}');
      if (!mounted) return;
      setState(() {
        _plans = [];
        _selectedPlan = null;
        _plansError = e.message;
        _isFetchingPlans = false;
      });
    } catch (e) {
      debugPrint('[AddMember] plans unexpected error: $e');
      if (!mounted) return;
      setState(() {
        _plans = [];
        _selectedPlan = null;
        _plansError = e.toString();
        _isFetchingPlans = false;
      });
    }
  }

  void _showSnackbar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info_outline, color: color, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                msg,
                style: TextStyle(
                  color: AppColors.primaryText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.cardBackground,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.border),
        ),
        margin: EdgeInsets.all(20),
        duration: Duration(seconds: 3),
      ),
    );
  }

  Future<void> _enrollMember() async {
    String? nameErr;
    String? phoneErr;
    String? planErr;

    if (_nameController.text.trim().isEmpty) {
      nameErr = "Full name is required";
    }

    final phone = _phoneController.text.trim();
    final digitsOnly = phone.replaceAll(RegExp(r'\D'), '');
    if (phone.isEmpty) {
      phoneErr = "Phone number is required";
    } else if (digitsOnly.length != 10) {
      phoneErr = "Enter a valid 10-digit phone number";
    }

    if (!_isTrial && _selectedPlan == null) {
      planErr = "Select a membership plan";
    }

    if (nameErr != null || phoneErr != null || planErr != null) {
      setState(() {
        _nameError = nameErr;
        _phoneError = phoneErr;
        _planError = planErr;
        _submitError = null;
      });
      return;
    }

    setState(() {
      _nameError = null;
      _phoneError = null;
      _planError = null;
      _submitError = null;
      _isLoading = true;
    });

    final normalizedPhone = '+91$digitsOnly';

    final member = Member(
      memberName: _nameController.text.trim(),
      phone: normalizedPhone,
      membershipTypeId: _isTrial ? null : _selectedPlan?.id,
      isTrial: _isTrial,
      paymentCollected: _paymentCollected,
    );

    try {
      await ApiService.enrollMember(member);
      if (!mounted) return;
      _showSnackbar("Member Enrolled Successfully!", AppColors.success);
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitError = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFC9992A);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text("ENROLL", style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.white)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AVATAR AREA
            Center(
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _nameController,
                builder: (_, value, __) {
                  final initial = value.text.trim();
                  return Container(
                    width: 90, height: 90,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.border, AppColors.cardBackground],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
                    ),
                    alignment: Alignment.center,
                    child: initial.isNotEmpty 
                      ? Text(initial[0].toUpperCase(), style: GoogleFonts.outfit(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900))
                      : Icon(Icons.add_a_photo_rounded, size: 30, color: Colors.white.withOpacity(0.2)),
                  );
                },
              ),
            ),
            
            const SizedBox(height: 32),
            _sectionLabel("ENROLLMENT TYPE"),
            const SizedBox(height: 16),
            
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.cardBackground.withOpacity(0.8),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.08), width: 0.5),
              ),
              child: Row(
                children: [
                  _buildTypeTab("FREE TRIAL", _isTrial, () => setState(() { _isTrial = true; _selectedPlan = null; _paymentCollected = false; })),
                  const SizedBox(width: 8),
                  _buildTypeTab("PAID PLAN", !_isTrial, () => setState(() => _isTrial = false)),
                ],
              ),
            ),

            const SizedBox(height: 32),
            _sectionLabel("PERSONAL DETAILS"),
            const SizedBox(height: 16),
            
            Container(
              decoration: BoxDecoration(
                color: AppColors.cardBackground.withOpacity(0.8),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withOpacity(0.08), width: 0.5),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.02),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                children: [
                  _buildPremiumField("Full Name", Icons.person_outline_rounded, _nameController, error: _nameError),
                  _divider(),
                  _buildPremiumField("Phone Number", Icons.phone_iphone_rounded, _phoneController, error: _phoneError, keyboardType: TextInputType.phone),
                ],
              ),
            ),
            
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: _isTrial
                  ? const SizedBox(height: 0)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 32),
                        _sectionLabel("SELECT MEMBERSHIP PLAN"),
                        const SizedBox(height: 16),
                        _buildPlansList(),
                        const SizedBox(height: 24),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.cardBackground.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white.withOpacity(0.08), width: 0.5),
                          ),
                          child: SwitchListTile(
                            controlAffinity: ListTileControlAffinity.trailing,
                            activeColor: Colors.white,
                            activeTrackColor: AppColors.emerald,
                            title: Text("Initial Payment Received", style: GoogleFonts.outfit(color: AppColors.primaryText, fontWeight: FontWeight.w700, fontSize: 14)),
                            subtitle: Text(_paymentCollected ? "Payment secured" : "Mark as pending", style: GoogleFonts.outfit(color: AppColors.secondaryText, fontSize: 12)),
                            value: _paymentCollected,
                            onChanged: (val) => setState(() => _paymentCollected = val),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                          ),
                        ),
                      ],
                    ),
            ),

            const SizedBox(height: 40),
            if (_submitError != null) ...[
              _buildErrorBox(_submitError!),
              const SizedBox(height: 16),
            ],

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _enrollMember,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isLoading 
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 3))
                  : Text(_isTrial ? "AUTHORIZE TRIAL" : "CONFIRM ENROLLMENT", style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.0)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: Text(text, style: GoogleFonts.outfit(color: AppColors.secondaryText, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
    );
  }

  Widget _buildTypeTab(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? AppColors.primaryBlue.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: active ? AppColors.primaryBlue.withOpacity(0.4) : Colors.transparent, width: 1),
          ),
          alignment: Alignment.center,
          child: Text(label, style: GoogleFonts.outfit(color: active ? AppColors.primaryBlue : AppColors.secondaryText, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
        ),
      ),
    );
  }

  Widget _buildPremiumField(String label, IconData icon, TextEditingController ctrl, {String? error, TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: ctrl,
            keyboardType: keyboardType,
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: label,
              hintStyle: GoogleFonts.outfit(color: AppColors.secondaryText.withOpacity(0.4), fontSize: 15),
              prefixIcon: Icon(icon, color: error != null ? AppColors.error : AppColors.secondaryText.withOpacity(0.6), size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 18),
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(48, 0, 16, 12),
              child: Text(error, style: GoogleFonts.outfit(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _divider() => Divider(color: Colors.white.withOpacity(0.05), height: 1, indent: 48);

  Widget _buildErrorBox(String msg) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.08), 
        borderRadius: BorderRadius.circular(20), 
        border: Border.all(color: AppColors.error.withOpacity(0.3))
      ),
      child: Row(children: [
        const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(msg, style: GoogleFonts.outfit(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.w500))),
      ]),
    );
  }

  Widget _buildPlansList() {
    if (_isFetchingPlans) return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: AppColors.primaryBlue)));
    if (_plansError != null) return _buildErrorBox(_plansError!);
    
    return Column(
      children: _plans.map((p) {
        final sel = _selectedPlan?.id == p.id;
        return GestureDetector(
          onTap: () => setState(() { _selectedPlan = p; _planError = null; }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: sel ? AppColors.primaryBlue.withOpacity(0.08) : AppColors.cardBackground.withOpacity(0.6),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: sel ? AppColors.primaryBlue.withOpacity(0.5) : Colors.white.withOpacity(0.06), width: 1),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                  child: Icon(Icons.stars_rounded, color: AppColors.primaryBlue, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.name, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text("\u20B9${p.amount.toInt()} \u2022 ${p.durationMonths} Months", style: GoogleFonts.outfit(color: AppColors.secondaryText, fontSize: 12)),
                ])),
                Icon(sel ? Icons.check_circle_rounded : Icons.radio_button_off_rounded, color: sel ? AppColors.primaryBlue : Colors.white.withOpacity(0.1), size: 22),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
