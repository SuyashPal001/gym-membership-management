import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../models/staff_models.dart';
import '../services/api_service.dart';
import '../services/api_exception.dart';

class StaffDetailScreen extends StatefulWidget {
  final String staffId;
  const StaffDetailScreen({Key? key, required this.staffId}) : super(key: key);

  @override
  State<StaffDetailScreen> createState() => _StaffDetailScreenState();
}

class _StaffDetailScreenState extends State<StaffDetailScreen> {
  StaffStats? _stats;
  bool _isLoading = true;
  String? _error;
  bool _markingPaid = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final stats = await ApiService.fetchStaffStats(widget.staffId);
      if (mounted) setState(() { _stats = stats; _isLoading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Something went wrong'; _isLoading = false; });
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Staff Member', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: const Text('This will remove them from the active staff list. Are you sure?',
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
    setState(() => _deleting = true);
    try {
      await ApiService.deleteStaff(widget.staffId);
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
      );
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _markSalaryPaid() async {
    if (_markingPaid) return;
    setState(() => _markingPaid = true);
    try {
      await ApiService.markStaffSalaryPaid(widget.staffId);
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _markingPaid = false);
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'Trainer': return AppColors.primaryBlue;
      case 'Receptionist': return AppColors.infoBlue;
      case 'Manager': return AppColors.emerald;
      case 'Cleaner': return Colors.purpleAccent;
      default: return AppColors.warning;
    }
  }

  void _showEditSheet() {
    if (_stats == null) return;
    final s = _stats!.staff;
    final nameCtrl = TextEditingController(text: s.name);
    // Strip +91 prefix for display
    String rawPhone = s.phone ?? '';
    if (rawPhone.startsWith('+91')) rawPhone = rawPhone.substring(3);
    final phoneCtrl = TextEditingController(text: rawPhone);
    final salaryCtrl = TextEditingController(text: s.monthlySalary.toStringAsFixed(0));
    String selectedRole = s.role;
    final roles = ['Trainer', 'Receptionist', 'Cleaner', 'Manager', 'Other'];
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 32, height: 4, decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 20),
                  Text('EDIT STAFF MEMBER',
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
                        _buildPremiumField("Full Name", Icons.person_outline_rounded, nameCtrl),
                        _divider(),
                        _buildPremiumField("Phone Number", Icons.phone_iphone_rounded, phoneCtrl, keyboardType: TextInputType.number),
                        _divider(),
                        _buildPremiumField("Monthly Salary", Icons.currency_rupee_rounded, salaryCtrl, keyboardType: TextInputType.number),
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
                        onTap: () => setSheetState(() => selectedRole = r),
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
                      onPressed: saving ? null : () async {
                        setSheetState(() => saving = true);
                        try {
                          await ApiService.updateStaff(widget.staffId, {
                            'name': nameCtrl.text.trim(),
                            'phone': phoneCtrl.text.trim(),
                            'role': selectedRole,
                            'monthly_salary': double.tryParse(salaryCtrl.text) ?? s.monthlySalary,
                          });
                          if (mounted) Navigator.pop(ctx);
                          _load();
                        } on ApiException catch (e) {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.message), backgroundColor: AppColors.error));
                        } catch (_) {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Update failed'), backgroundColor: AppColors.error));
                        } finally {
                          setSheetState(() => saving = false);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: saving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                          : Text('SAVE CHANGES', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, letterSpacing: 1.0, fontSize: 14, color: Colors.black)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, top: 20.0),
      child: Text(text, style: GoogleFonts.outfit(color: AppColors.secondaryText, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
    );
  }

  Widget _buildPremiumField(String label, IconData icon, TextEditingController ctrl, {TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: label,
          hintStyle: GoogleFonts.outfit(color: AppColors.secondaryText.withOpacity(0.4), fontSize: 15),
          prefixIcon: Icon(icon, color: AppColors.secondaryText.withOpacity(0.6), size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }

  Widget _divider() => Divider(color: Colors.white.withOpacity(0.05), height: 1, indent: 48);

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
        title: const Text('STAFF PROFILE',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.white)),
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
              if (value == 'refresh') _load();
              if (value == 'edit') _showEditSheet();
              if (value == 'delete') _confirmDelete();
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
              PopupMenuItem(
                value: 'edit',
                child: Row(children: [
                  Icon(Icons.edit_rounded, color: Colors.white.withOpacity(0.7), size: 18),
                  const SizedBox(width: 12),
                  const Text('Edit Staff', style: TextStyle(color: Colors.white, fontSize: 14)),
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
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.primaryBlue, strokeWidth: 2))
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primaryBlue,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProfileCard(),
                        const SizedBox(height: 24),
                        _buildAttendanceCard(),
                        const SizedBox(height: 24),
                        _buildLast7Days(),
                        const SizedBox(height: 24),
                        _buildSalaryCard(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildProfileCard() {
    final s = _stats!.staff;
    final roleColor = _roleColor(s.role);

    String joinedLabel = '';
    if (s.joinDate != null) {
      try {
        final dt = DateTime.parse(s.joinDate!);
        joinedLabel = DateFormat('d MMM yyyy').format(dt);
      } catch (_) {
        joinedLabel = s.joinDate!;
      }
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: roleColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: roleColor.withOpacity(0.35), width: 1.5),
            ),
            alignment: Alignment.center,
            child: Text(
              s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
              style: TextStyle(color: roleColor, fontSize: 26, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.name,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: roleColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(s.role.toUpperCase(),
                    style: TextStyle(color: roleColor, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                ),
                const SizedBox(height: 8),
                if (s.phone != null && s.phone!.isNotEmpty)
                  Row(children: [
                    Icon(Icons.phone_rounded, color: AppColors.secondaryText, size: 13),
                    const SizedBox(width: 5),
                    Text(s.phone!, style: const TextStyle(color: AppColors.secondaryText, fontSize: 13)),
                  ]),
                if (joinedLabel.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.calendar_today_rounded, color: AppColors.secondaryText, size: 12),
                    const SizedBox(width: 5),
                    Text('Joined $joinedLabel', style: const TextStyle(color: AppColors.secondaryText, fontSize: 12)),
                  ]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceCard() {
    final daysPresent = _stats!.daysPresent;
    final total = _stats!.totalWorkingDays;
    final pct = total > 0 ? (daysPresent / total).clamp(0.0, 1.0) : 0.0;
    final month = DateFormat('MMMM yyyy').format(DateTime.now());

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('ATTENDANCE', style: GoogleFonts.outfit(
              color: AppColors.secondaryText, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
            Text(month, style: const TextStyle(color: AppColors.secondaryText, fontSize: 11)),
          ]),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _attendanceStat(daysPresent.toString(), 'PRESENT', AppColors.emerald),
            _verticalDivider(),
            _attendanceStat((total - daysPresent).toString(), 'ABSENT', AppColors.error),
            _verticalDivider(),
            _attendanceStat('$total', 'WORKING DAYS', AppColors.secondaryText),
          ]),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: Colors.white.withOpacity(0.06),
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.emerald),
            ),
          ),
          const SizedBox(height: 8),
          Text('${(pct * 100).toStringAsFixed(0)}% attendance this month',
            style: const TextStyle(color: AppColors.secondaryText, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _attendanceStat(String val, String label, Color color) {
    return Expanded(
      child: Column(children: [
        Text(val, style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.w800, height: 1)),
        const SizedBox(height: 5),
        Text(label, style: GoogleFonts.outfit(color: AppColors.secondaryText, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
      ]),
    );
  }

  Widget _verticalDivider() => Container(width: 1, height: 32, color: Colors.white.withOpacity(0.06));

  Widget _buildLast7Days() {
    final days = _stats!.last7Days;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('LAST 7 DAYS', style: GoogleFonts.outfit(
            color: AppColors.secondaryText, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: days.map((d) {
              Color dotColor;
              IconData icon;
              if (d.status == 'present') {
                dotColor = AppColors.emerald;
                icon = Icons.check_rounded;
              } else if (d.status == 'absent') {
                dotColor = AppColors.error;
                icon = Icons.close_rounded;
              } else {
                dotColor = Colors.white.withOpacity(0.06);
                icon = Icons.remove_rounded;
              }

              String dayLabel = '';
              try {
                final dt = DateTime.parse(d.date);
                dayLabel = DateFormat('EEE').format(dt).toUpperCase();
              } catch (_) {
                dayLabel = d.date.length >= 2 ? d.date.substring(d.date.length - 2) : d.date;
              }

              return Column(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: d.status != null ? dotColor.withOpacity(0.12) : Colors.white.withOpacity(0.03),
                    shape: BoxShape.circle,
                    border: Border.all(color: d.status != null ? dotColor.withOpacity(0.4) : Colors.white.withOpacity(0.06)),
                  ),
                  child: Icon(icon, color: d.status != null ? dotColor : AppColors.secondaryText.withOpacity(0.3), size: 16),
                ),
                const SizedBox(height: 6),
                Text(dayLabel, style: TextStyle(color: AppColors.secondaryText, fontSize: 9, fontWeight: FontWeight.w700)),
              ]);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSalaryCard() {
    final salary = _stats!.salary;
    final isPaid = salary.paid;
    final month = salary.month.isNotEmpty
        ? _formatSalaryMonth(salary.month)
        : DateFormat('MMMM yyyy').format(DateTime.now());

    String paidAtLabel = '';
    if (isPaid && salary.paidAt != null) {
      try {
        final dt = DateTime.parse(salary.paidAt!);
        paidAtLabel = 'Paid on ${DateFormat('d MMM').format(dt)}';
      } catch (_) {}
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('SALARY', style: GoogleFonts.outfit(
              color: AppColors.secondaryText, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
            Text(month, style: const TextStyle(color: AppColors.secondaryText, fontSize: 11)),
          ]),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('₹${NumberFormat('#,##,###').format(salary.amount.toInt())}',
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800, height: 1)),
                const SizedBox(height: 6),
                if (paidAtLabel.isNotEmpty)
                  Text(paidAtLabel, style: const TextStyle(color: AppColors.secondaryText, fontSize: 12))
                else
                  Text('Monthly Salary', style: const TextStyle(color: AppColors.secondaryText, fontSize: 12)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: isPaid ? AppColors.emerald.withOpacity(0.1) : AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isPaid ? AppColors.emerald.withOpacity(0.4) : AppColors.error.withOpacity(0.3)),
              ),
              child: Text(isPaid ? 'PAID' : 'UNPAID',
                style: TextStyle(
                  color: isPaid ? AppColors.emerald : AppColors.error,
                  fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.8,
                )),
            ),
          ]),
          if (!isPaid) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 35,
              child: ElevatedButton(
                onPressed: _markingPaid ? null : _markSalaryPaid,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: _markingPaid
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : Text('MARK AS PAID', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: 0.8, fontSize: 12)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatSalaryMonth(String month) {
    try {
      final parts = month.split('-');
      if (parts.length == 2) {
        final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]));
        return DateFormat('MMMM yyyy').format(dt);
      }
    } catch (_) {}
    return month;
  }

  Widget _buildError() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.error_outline, color: AppColors.error.withOpacity(0.6), size: 48),
        const SizedBox(height: 16),
        Text(_error!, style: const TextStyle(color: AppColors.secondaryText)),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _load,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('RETRY', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }
}
