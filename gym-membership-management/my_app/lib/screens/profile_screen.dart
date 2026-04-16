import 'package:flutter/material.dart';
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

  bool    _isLoading    = true;
  bool    _isSaving     = false;
  String? _editingField; // 'studio_name' | 'owner_name' | 'city' | 'state' | null
  String  _originalValue = '';

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

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

  // ─── Data ──────────────────────────────────────────────────────────────────

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

  Future<void> _saveField(String fieldId) async {
    final studio = _studioNameController.text.trim();
    final owner  = _ownerNameController.text.trim();

    if (studio.isEmpty || owner.isEmpty) {
      _snack('Studio name and owner name are required', error: true);
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
      if (fieldId == 'owner_name') globalOwnerName = owner;
      setState(() {
        _editingField = null;
        _isSaving     = false;
      });
      _snack('${_humanize(fieldId)} updated');
    } on ApiException catch (e) {
      _snack(e.message, error: true);
      setState(() => _isSaving = false);
    } catch (_) {
      _snack('An unexpected error occurred', error: true);
      setState(() => _isSaving = false);
    }
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  String _humanize(String fieldId) => fieldId
      .split('_')
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.redAccent : AppColors.accent,
    ));
  }

  void _startEditing(String fieldId, TextEditingController ctrl) {
    setState(() {
      _editingField  = fieldId;
      _originalValue = ctrl.text;
    });
  }

  void _cancelEditing(TextEditingController ctrl) {
    setState(() {
      ctrl.text     = _originalValue;
      _editingField = null;
    });
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18, color: Colors.white),
          onPressed: widget.onBack,
        ),
        title: const Text(
          'Profile',
          style: TextStyle(
            fontSize:   22,
            fontWeight: FontWeight.bold,
            color:      AppColors.primaryText,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // FIX 1 & 2: Dynamic Avatar and no text below
                  const SizedBox(height: 32),
                  _buildAvatarOnly(),
                  const SizedBox(height: 24), // 24px gap between avatar and first field row

                  // 3. FIELD ROWS (BOX STYLE)
                  _buildFieldRow(
                    label:       'STUDIO NAME',
                    controller:  _studioNameController,
                    fieldId:     'studio_name',
                    hint:        'Enter studio name',
                  ),
                  _buildFieldRow(
                    label:       'OWNER NAME',
                    controller:  _ownerNameController,
                    fieldId:     'owner_name',
                    hint:        'Enter your name',
                  ),
                  _buildContactRow(),
                  _buildFieldRow(
                    label:       'CITY',
                    controller:  _cityController,
                    fieldId:     'city',
                    hint:        'Enter city',
                  ),
                  _buildFieldRow(
                    label:       'STATE',
                    controller:  _stateController,
                    fieldId:     'state',
                    hint:        'Enter state',
                  ),

                  // 4. VERSION TEXT
                  Padding(
                    padding: const EdgeInsets.only(top: 40, bottom: 24),
                    child: Center(
                      child: Text(
                        'Gym-Ops v1.0',
                        style: TextStyle(
                          fontSize: 12,
                          color:    AppColors.secondaryText.withOpacity(0.3),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildAvatarOnly() {
    final gymName = _studioNameController.text.trim();

    return Center(
      child: Container(
        width:  72,
        height: 72,
        decoration: BoxDecoration(
          color:        const Color(0xFF1A2E1A),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: gymName.isEmpty
            ? const Icon(Icons.store, color: AppColors.accent, size: 32)
            : Text(
                gymName[0].toUpperCase(),
                style: const TextStyle(
                  color:      AppColors.accent,
                  fontSize:   28,
                  fontWeight: FontWeight.w500,
                ),
              ),
      ),
    );
  }

  Widget _buildFieldRow({
    required String               label,
    required TextEditingController controller,
    required String               fieldId,
    required String               hint,
  }) {
    final bool isEditing = _editingField == fieldId;
    final bool hasValue  = controller.text.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color:      AppColors.accent,
              fontSize:   12,
              fontWeight: FontWeight.normal,
            ),
          ),
          const SizedBox(height: 8),

          if (isEditing)
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: controller,
                    autofocus:  true,
                    style: const TextStyle(
                      color:      AppColors.primaryText,
                      fontSize:   16,
                      fontWeight: FontWeight.w500,
                    ),
                    cursorColor: AppColors.accent,
                    decoration: InputDecoration(
                      filled:     true,
                      fillColor:  AppColors.cardBackground,
                      hintText:   hint,
                      hintStyle:  const TextStyle(
                        fontSize:   16,
                        fontWeight: FontWeight.normal,
                        color:      AppColors.secondaryText,
                      ),
                      isDense:    true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:   BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:   const BorderSide(color: AppColors.accent, width: 2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (_isSaving)
                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))
                else ...[
                  IconButton(
                    onPressed: () => _saveField(fieldId),
                    icon:      const Icon(Icons.check, color: AppColors.accent, size: 20),
                    padding:   EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _cancelEditing(controller),
                    icon:      const Icon(Icons.close, color: AppColors.secondaryText, size: 20),
                    padding:   EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ],
            )
          else
            GestureDetector(
              onTap: () => _startEditing(fieldId, controller),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width:  double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  color:        AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        hasValue ? controller.text : hint,
                        style: TextStyle(
                          fontSize:   16,
                          fontWeight: hasValue ? FontWeight.w500 : FontWeight.normal,
                          color:      hasValue ? AppColors.primaryText : AppColors.secondaryText,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 18, color: AppColors.secondaryText),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContactRow() {
    final bool hasValue = _phoneController.text.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CONTACT',
            style: TextStyle(
              color:      AppColors.accent,
              fontSize:   12,
              fontWeight: FontWeight.normal,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width:  double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color:        AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              hasValue ? _phoneController.text : '—',
              style: TextStyle(
                fontSize:   16,
                fontWeight: FontWeight.normal,
                color:      AppColors.secondaryText.withOpacity(0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
