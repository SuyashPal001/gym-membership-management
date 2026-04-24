import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../models/staff_models.dart';
import '../services/api_service.dart';
import '../services/api_exception.dart';
import 'staff_detail_screen.dart';

class StaffScreen extends StatefulWidget {
  const StaffScreen({Key? key}) : super(key: key);
  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  List<StaffMember> _staff = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final staff = await ApiService.fetchStaff();
      if (mounted) setState(() { _staff = staff; _isLoading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Something went wrong'; _isLoading = false; });
    }
  }

  Future<void> _toggleAttendance(StaffMember member) async {
    final idx = _staff.indexWhere((s) => s.id == member.id);
    if (idx == -1) return;

    // Optimistic update
    final prev = _staff[idx];
    final nextStatus = prev.todayAttendance == 'present' ? 'absent' : 'present';
    setState(() {
      _staff[idx] = prev.copyWith(
        todayAttendance: nextStatus,
        checkInTime: nextStatus == 'present' ? DateTime.now().toIso8601String() : null,
      );
    });

    try {
      await ApiService.toggleStaffAttendance(member.id!);
    } on ApiException {
      // Rollback
      if (mounted) setState(() => _staff[idx] = prev);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('STAFF', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.white)),
        actions: [
          IconButton(icon: Icon(Icons.refresh, color: AppColors.secondaryText, size: 20), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddStaffSheet(),
        backgroundColor: AppColors.accent,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.person_add_rounded, color: Colors.black, size: 24),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.primaryBlue, strokeWidth: 2))
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primaryBlue,
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(child: _buildHeader()),
                      _staff.isEmpty
                          ? SliverFillRemaining(child: _buildEmpty())
                          : SliverPadding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (ctx, i) => _buildStaffCard(_staff[i]),
                                  childCount: _staff.length,
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
    );
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

  Widget _buildHeader() {
    final present = _staff.where((s) => s.todayAttendance == 'present').length;
    final absent = _staff.where((s) => s.todayAttendance == 'absent').length;
    final unmarked = _staff.length - present - absent;
    
    const gold = Color(0xFFC9992A);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground.withOpacity(0.8),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 0.5),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.03),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          // Left Side: Total Staff
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "TOTAL STAFF",
                  style: GoogleFonts.outfit(
                    color: gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _staff.length.toString(),
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    letterSpacing: -1.5,
                  ),
                ),
              ],
            ),
          ),
          
          // Vertical Subtle Divider
          Container(
            height: 60,
            width: 0.5,
            color: Colors.white.withOpacity(0.1),
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),

          // Right Side: Attendance Stats
          Expanded(
            flex: 6,
            child: Column(
              children: [
                _buildCompactStat("PRESENT", present.toString(), AppColors.emerald),
                const SizedBox(height: 6),
                _buildCompactStat("ABSENT", absent.toString(), AppColors.error),
                const SizedBox(height: 6),
                _buildCompactStat("UNMARKED", unmarked.toString(), Colors.white),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.15), width: 0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              color: Colors.white.withOpacity(0.6),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.outfit(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffCard(StaffMember member) {
    final isPresent = member.todayAttendance == 'present';
    final isAbsent = member.todayAttendance == 'absent';

    Color roleColor = _roleColor(member.role);
    Color attendanceColor = isPresent ? AppColors.emerald : isAbsent ? AppColors.error : Colors.white;
    String attendanceLabel = isPresent ? 'PRESENT' : isAbsent ? 'ABSENT' : 'UNMARKED';

    String checkInLabel = '';
    if (isPresent && member.checkInTime != null) {
      try {
        final dt = DateTime.parse(member.checkInTime!).toLocal();
        checkInLabel = '· ${DateFormat('h:mm a').format(dt)}';
      } catch (_) {}
    }

    return GestureDetector(
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => StaffDetailScreen(staffId: member.id!)));
        _load();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border.withOpacity(0.3)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.02),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          children: [
            // Avatar with a more premium look
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [roleColor.withOpacity(0.2), roleColor.withOpacity(0.05)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: roleColor.withOpacity(0.3), width: 1),
              ),
              alignment: Alignment.center,
              child: Text(
                member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                style: TextStyle(color: roleColor, fontSize: 22, fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(member.name, 
                          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.5), 
                          overflow: TextOverflow.ellipsis
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: roleColor.withOpacity(0.12), 
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: roleColor.withOpacity(0.2), width: 0.5),
                        ),
                        child: Text(member.role.toUpperCase(), 
                          style: TextStyle(color: roleColor, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5)
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(Icons.watch_later_outlined, color: attendanceColor.withOpacity(0.7), size: 12),
                    const SizedBox(width: 6),
                    Text('$attendanceLabel $checkInLabel', 
                      style: GoogleFonts.outfit(color: attendanceColor, fontSize: 11, fontWeight: FontWeight.w700)
                    ),
                  ]),
                ],
              ),
            ),
            // Action Toggle
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => _toggleAttendance(member),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: isPresent ? AppColors.emerald.withOpacity(0.12) : isAbsent ? AppColors.error.withOpacity(0.12) : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isPresent ? AppColors.emerald.withOpacity(0.4) : isAbsent ? AppColors.error.withOpacity(0.4) : Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Icon(
                  isPresent ? Icons.check_circle_rounded : isAbsent ? Icons.cancel_rounded : Icons.radio_button_off_rounded,
                  color: isPresent ? AppColors.emerald : isAbsent ? AppColors.error : Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.people_outline_rounded, color: AppColors.secondaryText.withOpacity(0.15), size: 56),
        const SizedBox(height: 16),
        Text('No staff members yet', style: TextStyle(color: AppColors.secondaryText.withOpacity(0.4), fontSize: 14)),
        const SizedBox(height: 8),
        Text('Tap + to add your first staff member', style: TextStyle(color: AppColors.secondaryText.withOpacity(0.25), fontSize: 12)),
      ]),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.error_outline, color: AppColors.error.withOpacity(0.6), size: 48),
        const SizedBox(height: 16),
        Text(_error!, style: const TextStyle(color: AppColors.secondaryText)),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: _load,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text('RETRY', style: TextStyle(fontWeight: FontWeight.bold))),
      ]),
    );
  }

  // ─── Add Staff Sheet ────────────────────────────────────────────────────────

  void _showAddStaffSheet() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final salaryCtrl = TextEditingController();
    String selectedRole = 'Trainer';
    bool isSaving = false;
    String? nameError;
    String? phoneError;
    String? salaryError;

    final roles = ['Trainer', 'Receptionist', 'Cleaner', 'Manager', 'Other'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 32, height: 4, decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                Text('ADD STAFF MEMBER',
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
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
                      _buildPremiumField("Full Name", Icons.person_outline_rounded, nameCtrl, error: nameError),
                      _divider(),
                      _buildPremiumField("Phone Number", Icons.phone_iphone_rounded, phoneCtrl, error: phoneError, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)]),
                      _divider(),
                      _buildPremiumField("Monthly Salary", Icons.currency_rupee_rounded, salaryCtrl, error: salaryError, keyboardType: TextInputType.number),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _sectionLabel("ROLE"),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: roles.map((r) {
                    final sel = selectedRole == r;
                    final rc = _roleColor(r);
                    return GestureDetector(
                      onTap: () => setSheet(() {
                        selectedRole = r;
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: sel ? rc.withOpacity(0.15) : Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: sel ? rc.withOpacity(0.5) : Colors.white.withOpacity(0.08)),
                        ),
                        child: Text(r, style: GoogleFonts.outfit(color: sel ? rc : AppColors.secondaryText, fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isSaving ? null : () async {
                      final name = nameCtrl.text.trim();
                      final phone = phoneCtrl.text.trim();
                      final salary = double.tryParse(salaryCtrl.text.trim());

                      String? nErr, pErr, sErr;

                      if (name.isEmpty) nErr = 'Full name is required';
                      if (phone.isEmpty || phone.length != 10) pErr = 'Enter a valid 10-digit phone number';
                      if (salary == null || salary < 0) sErr = 'Valid monthly salary is required';

                      if (nErr != null || pErr != null || sErr != null) {
                        setSheet(() {
                          nameError = nErr;
                          phoneError = pErr;
                          salaryError = sErr;
                        });
                        return;
                      }

                      setSheet(() {
                        nameError = null;
                        phoneError = null;
                        salaryError = null;
                        isSaving = true;
                      });
                      try {
                        await ApiService.addStaff({
                          'name': name,
                          'phone': phone,
                          'role': selectedRole,
                          'monthly_salary': salary,
                        });
                        if (mounted) {
                          Navigator.pop(ctx);
                          _load();
                          _showSnackbar('Staff Member Added!', AppColors.success);
                        }
                      } on ApiException catch (e) {
                        if (mounted) _showSnackbar(e.message, AppColors.error);
                      } catch (_) {
                        if (mounted) _showSnackbar('Something went wrong', AppColors.error);
                      } finally {
                        if (mounted) setSheet(() => isSaving = false);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: isSaving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : Text('ADD STAFF MEMBER', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, letterSpacing: 1.0, fontSize: 14, color: Colors.black)),
                  ),
                ),
              ],
            ),
          ),
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

  Widget _buildPremiumField(String label, IconData icon, TextEditingController ctrl, {String? error, TextInputType? keyboardType, List<TextInputFormatter>? inputFormatters}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: ctrl,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
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

  Color _roleColor(String role) {
    switch (role) {
      case 'Trainer': return AppColors.primaryBlue;
      case 'Receptionist': return AppColors.infoBlue;
      case 'Manager': return AppColors.emerald;
      case 'Cleaner': return Colors.purpleAccent;
      default: return AppColors.warning;
    }
  }
}
