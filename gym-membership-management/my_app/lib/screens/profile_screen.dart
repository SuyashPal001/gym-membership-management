import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../services/api_service.dart';
import '../services/api_exception.dart';
import '../main.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback onBack;

  const ProfileScreen({Key? key, required this.onBack}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _studioNameController = TextEditingController();
  final _ownerNameController  = TextEditingController();
  final _phoneController      = TextEditingController();
  final _cityController       = TextEditingController();
  final _stateController      = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isGlobalEditing = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _studioNameController.dispose();
    _ownerNameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final d = await ApiService.fetchGymProfile();
      _studioNameController.text = d['gym_name']   ?? '';
      _ownerNameController.text  = d['owner_name'] ?? '';
      _phoneController.text      = d['phone']      ?? '';
      _cityController.text       = d['city']       ?? '';
      _stateController.text      = d['state']      ?? '';
    } catch (e) {
      _snack(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAllFields() async {
    final studio = _studioNameController.text.trim();
    final owner  = _ownerNameController.text.trim();

    if (studio.isEmpty || owner.isEmpty) {
      _snack('Information required', error: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ApiService.updateGymProfile({
        'gym_name':   studio,
        'owner_name': owner,
        'phone':     _phoneController.text.trim(),
        'city':      _cityController.text.trim(),
        'state':     _stateController.text.trim(),
      });
      globalOwnerName = owner;
      setState(() {
        _isGlobalEditing = false;
        _isSaving     = false;
      });
      _snack('Profile Updated Successfully');
    } on ApiException catch (e) {
      _snack(e.message, error: true);
      setState(() => _isSaving = false);
    } catch (_) {
      _snack('Unexpected Error', error: true);
      setState(() => _isSaving = false);
    }
  }

  String _humanize(String fieldId) => fieldId
      .split('_')
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.of(context).padding.bottom + 24),
      backgroundColor: Colors.transparent,
      elevation: 0,
      content: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A).withOpacity(0.95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: error ? AppColors.error.withOpacity(0.3) : AppColors.emerald.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              error ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: error ? AppColors.error : AppColors.emerald,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
      ),
      duration: const Duration(seconds: 2),
    ));
  }

  void _cancelGlobalEditing() {
    setState(() {
      _isGlobalEditing = false;
    });
    _loadProfile(); // Revert changes
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // 1. ATMOSPHERIC BACKGROUND
          Positioned(
            top: -100, right: -50,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryBlue.withOpacity(0.05),
              ),
            ),
          ),
          _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue))
              : CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    _buildAppBar(),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            const SizedBox(height: 20),
                            _buildNeuralHeader(),
                            const SizedBox(height: 48),
                            _buildModuleHeader('IDENTITY'),
                            _buildModuleCard([
                              _buildInfoRow(
                                title: 'STUDIO NAME',
                                controller: _studioNameController,
                                icon: Icons.auto_awesome_mosaic_rounded,
                              ),
                              _buildInfoRow(
                                title: 'OWNER NAME',
                                controller: _ownerNameController,
                                icon: Icons.verified_user_rounded,
                                isLast: true,
                              ),
                            ]),
                            const SizedBox(height: 32),
                            _buildModuleHeader('CONTACT & LOCATION'),
                            _buildModuleCard([
                              _buildInfoRow(
                                title: 'PRIMARY CONTACT',
                                controller: _phoneController,
                                icon: Icons.phone_iphone_rounded,
                                isEditable: false,
                              ),
                              _buildInfoRow(
                                title: 'LOCATION CITY',
                                controller: _cityController,
                                icon: Icons.location_on_rounded,
                              ),
                              _buildInfoRow(
                                title: 'STATE / PROVINCE',
                                controller: _stateController,
                                icon: Icons.map_rounded,
                                isLast: true,
                              ),
                            ]),
                            const SizedBox(height: 60),
                            _buildFooter(),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      pinned: true,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: Colors.white),
        ),
        onPressed: widget.onBack,
      ),
      title: const Text(
        'STUDIO PROFILE',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
          color: Colors.white,
        ),
      ),
      centerTitle: true,
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_horiz_rounded, color: Colors.white, size: 22),
          color: AppColors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.white.withOpacity(0.06)),
          ),
          offset: const Offset(0, 44),
          onSelected: (value) {
            if (value == 'refresh') _loadProfile();
            if (value == 'edit') setState(() => _isGlobalEditing = true);
            if (value == 'delete') _showDeleteConfirmation();
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'refresh',
              child: Row(children: [
                Icon(Icons.refresh_rounded, color: Colors.white.withOpacity(0.7), size: 18),
                const SizedBox(width: 12),
                const Text('Refresh', style: TextStyle(color: Colors.white, fontSize: 14)),
              ]),
            ),
            if (!_isGlobalEditing)
              PopupMenuItem(
                value: 'edit',
                child: Row(children: [
                  Icon(Icons.edit_rounded, color: Colors.white.withOpacity(0.7), size: 18),
                  const SizedBox(width: 12),
                  const Text('Edit Profile', style: TextStyle(color: Colors.white, fontSize: 14)),
                ]),
              ),
            const PopupMenuDivider(height: 1),
            PopupMenuItem(
              value: 'delete',
              child: Row(children: [
                const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 18),
                const SizedBox(width: 12),
                Text('Delete', style: TextStyle(color: AppColors.error, fontSize: 14, fontWeight: FontWeight.w600)),
              ]),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showDeleteConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Account', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: const Text('This will permanently delete your studio profile and all associated data. This action cannot be undone.',
            style: TextStyle(color: AppColors.secondaryText)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL', style: TextStyle(color: AppColors.secondaryText)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('DELETE', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    
    try {
      await ApiService.deleteGymProfile();
      if (mounted) {
        _snack('Account deleted successfully');
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } on ApiException catch (e) {
      if (mounted) _snack(e.message, error: true);
    } catch (_) {
      if (mounted) _snack('Failed to delete account', error: true);
    }
  }

  Widget _buildNeuralHeader() {
    final gymName = _studioNameController.text.trim();
    final firstChar = gymName.isNotEmpty ? gymName[0].toUpperCase() : 'S';

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Layer 1: Outer Atmosphere
            Container(
              width: 140, height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primaryBlue.withOpacity(0.1), width: 1),
              ),
            ),
            // Layer 2: Main Orb Core
            Container(
              width: 110, height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primaryBlue.withOpacity(0.15),
                    AppColors.background,
                  ],
                ),
                border: Border.all(color: AppColors.primaryBlue.withOpacity(0.3), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withOpacity(0.08),
                    blurRadius: 40,
                    spreadRadius: 8,
                  ),
                ],
              ),
              child: Center(
                child: ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white,
                      AppColors.primaryBlue,
                    ],
                  ).createShader(bounds),
                  child: const Icon(
                    Icons.fitness_center_rounded,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        // RETAIN: Liquid Silver/Gold Gradient Text
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              Colors.white.withOpacity(0.7),
              AppColors.primaryBlue.withOpacity(0.8),
            ],
            stops: const [0.0, 0.4, 1.0],
          ).createShader(bounds),
          child: Text(
            gymName.toUpperCase(),
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primaryBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified_rounded, size: 12, color: AppColors.primaryBlue),
              const SizedBox(width: 8),
              Text(
                'ELITE STUDIO PARTNER',
                style: GoogleFonts.outfit(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  color: AppColors.primaryBlue,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModuleHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            color: AppColors.primaryText,
          ),
        ),
      ),
    );
  }

  Widget _buildModuleCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground.withOpacity(0.4),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.03)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildInfoRow({
    required String title,
    required TextEditingController controller,
    required IconData icon,
    bool isLast = false,
    bool isEditable = true,
  }) {
    final bool activeEdit = _isGlobalEditing && isEditable;

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: activeEdit ? AppColors.primaryBlue.withOpacity(0.03) : Colors.transparent,
            border: activeEdit ? Border.all(color: AppColors.primaryBlue.withOpacity(0.2), width: 1) : null,
            borderRadius: activeEdit ? BorderRadius.circular(16) : null,
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: activeEdit ? AppColors.primaryBlue : AppColors.secondaryText.withOpacity(0.4)),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: activeEdit ? AppColors.primaryBlue : AppColors.secondaryText.withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (activeEdit)
                      TextField(
                        controller: controller,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                        ),
                      )
                    else
                      Text(
                        controller.text.isEmpty ? '—' : controller.text,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isEditable ? Colors.white.withOpacity(0.9) : AppColors.secondaryText.withOpacity(0.3),
                          letterSpacing: 0.2,
                        ),
                      ),
                  ],
                ),
              ),
              if (!isEditable && _isGlobalEditing)
                Icon(Icons.lock_rounded, color: Colors.white.withOpacity(0.05), size: 14),
            ],
          ),
        ),
        if (!isLast && !activeEdit)
          Divider(color: Colors.white.withOpacity(0.02), height: 1, indent: 64),
      ],
    );
  }

  Widget _buildFooter() {
    if (_isGlobalEditing) {
      return Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: _cancelGlobalEditing,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('CANCEL', style: GoogleFonts.outfit(color: AppColors.secondaryText, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1.0)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveAllFields,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : Text('SAVE CHANGES', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, letterSpacing: 1.0, fontSize: 13, color: Colors.black)),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Container(
          width: 40, height: 2,
          decoration: BoxDecoration(
            color: AppColors.primaryBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'GYM-OPS ELITE PLATFORM',
          style: GoogleFonts.outfit(
            fontSize: 8,
            fontWeight: FontWeight.w900,
            letterSpacing: 4.0,
            color: AppColors.secondaryText.withOpacity(0.2),
          ),
        ),
      ],
    );
  }
}
