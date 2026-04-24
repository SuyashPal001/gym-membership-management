import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/member.dart';
import '../models/reminder_models.dart';
import '../models/attendance_summary.dart';
import '../services/api_exception.dart';
import '../services/api_service.dart';
import '../constants/app_colors.dart';
import 'reminder_history_screen.dart';
import 'attendance_history_screen.dart';

String _planLabel(Member? member) {
  if (member == null) return '—';
  if (member.isTrial || member.status == 'trial') {
    if (member.expiryDate != null) {
      final exp = DateTime.tryParse(member.expiryDate!);
      if (exp != null) {
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);
        final expDate = DateTime(exp.year, exp.month, exp.day);
        final diff = expDate.difference(todayDate).inDays;
        if (diff < 0) return 'Trial Overdue by ${diff.abs()} days';
      }
    }
    return 'Ongoing Trial';
  }
  if (member.membershipType == null) return '—';
  return '${member.membershipType!.durationMonths} Month';
}

class MemberDetailScreen extends StatefulWidget {
  final String memberName;
  final Member? member;

  const MemberDetailScreen({Key? key, required this.memberName, this.member}) : super(key: key);

  @override
  _MemberDetailScreenState createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends State<MemberDetailScreen> {
  String get _memberId => widget.member?.id ?? '';

  AttendanceSummary? _attendanceSummary;
  List<ReminderHistory>? _reminders;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        ApiService.fetchMemberAttendanceSummary(_memberId),
        ApiService.fetchReminderHistory(_memberId),
      ]);
      setState(() {
        _attendanceSummary = results[0] as AttendanceSummary;
        _reminders = results[1] as List<ReminderHistory>;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ─── Actions ───────────────────────────────────────────────────────────────

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

  Future<void> _handleRenew() async {
    try {
      final plans = await ApiService.fetchMembershipTypes();
      if (!mounted) return;

      final selectedPlan = await showModalBottomSheet<MembershipType>(
        context: context,
        backgroundColor: AppColors.background,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (ctx) {
          MembershipType? picked;
          return StatefulBuilder(
            builder: (ctx, setSheet) => Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 32, height: 4, decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text("SELECT RENEWAL PLAN", style: GoogleFonts.outfit(color: AppColors.secondaryText, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  ),
                  const SizedBox(height: 16),
                  ...plans.map((p) {
                    final sel = picked?.id == p.id;
                    IconData getPlanIcon(String name) {
                      final n = name.toLowerCase();
                      if (n.contains('12') || n.contains('year') || n.contains('annual')) return Icons.workspace_premium_rounded;
                      if (n.contains('6') || n.contains('half')) return Icons.stars_rounded;
                      if (n.contains('3') || n.contains('quarter')) return Icons.bolt_rounded;
                      return Icons.fitness_center_rounded;
                    }
                    return GestureDetector(
                      onTap: () => setSheet(() => picked = p),
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
                              child: Icon(getPlanIcon(p.name), color: AppColors.primaryBlue, size: 20),
                            ),
                            const SizedBox(width: 16),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(p.name, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                              const SizedBox(height: 2),
                              Text("₹${p.amount.toInt()} • ${p.durationMonths} Months", style: GoogleFonts.outfit(color: AppColors.secondaryText, fontSize: 12)),
                            ])),
                            Icon(sel ? Icons.check_circle_rounded : Icons.radio_button_off_rounded, color: sel ? AppColors.primaryBlue : Colors.white.withOpacity(0.1), size: 22),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: picked == null ? null : () => Navigator.pop(ctx, picked),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.black,
                        disabledBackgroundColor: Colors.white.withOpacity(0.06),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: Text("CONFIRM RENEWAL", style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.0, color: picked == null ? AppColors.secondaryText : Colors.black)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );

      if (selectedPlan != null) {
        setState(() => _isLoading = true);
        await ApiService.renewMembership(_memberId, selectedPlan.id);
        _showSnackbar("Membership Renewed Successfully!", AppColors.success);
        _loadAllData();
      }
    } catch (e) {
      _showSnackbar("Renewal failed: $e", AppColors.error);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRemind(String method) async {
    try {
      await ApiService.postReminder(_memberId, method);
      _showSnackbar("${method.toUpperCase()} reminder sent!", AppColors.primaryBlue);
      _loadAllData();
    } catch (e) {
      _showSnackbar("Failed to send reminder: $e", AppColors.error);
    }
  }

  Future<void> _showDeleteConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Delete Member", style: TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.bold)),
        content: Text("Remove ${widget.memberName} permanently?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text("CANCEL", style: TextStyle(color: AppColors.secondaryText))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text("DELETE", style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ApiService.deleteMember(_memberId);
        Navigator.pop(context, true);
      } catch (e) {
        _showSnackbar("Error deleting member: $e", AppColors.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("PROFILE", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_horiz, color: AppColors.primaryText),
            color: AppColors.cardBackground,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (val) { if (val == 'delete') _showDeleteConfirmation(); },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'delete',
                child: Row(children: [Icon(Icons.delete_outline, color: AppColors.error, size: 18), SizedBox(width: 8), Text("DELETE MEMBER", style: TextStyle(color: AppColors.error, fontSize: 10, fontWeight: FontWeight.w900))]),
              ),
            ],
          ),
        ],
      ),
      body: _error != null ? Center(child: Text(_error!, style: TextStyle(color: Colors.white))) : _buildContent(),
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: _loadAllData,
      color: AppColors.primaryBlue,
      child: ListView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        children: [
          _buildHeroHeader(),
          SizedBox(height: 32),
          _buildActionPanel(),
          SizedBox(height: 32),
          _buildQuickStats(),
          SizedBox(height: 40),
          _buildSectionHeader("MEMBERSHIP & BILLING"),
          _buildMembershipInfo(),
          SizedBox(height: 32),
          _buildSectionHeader("ATTENDANCE INSIGHTS"),
          _buildAttendanceCard(),
          SizedBox(height: 32),
          _buildSectionHeader("COMMUNICATION LOG"),
          _buildReminderHistoryCard(),
          SizedBox(height: 60),
        ],
      ),
    );
  }

  bool get _isExpired {
    final status = widget.member?.status ?? '';
    if (status == 'inactive') return true;
    final expiryStr = widget.member?.expiryDate;
    if (expiryStr == null) return false;
    final expiry = DateTime.tryParse(expiryStr);
    if (expiry == null) return false;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final expiryDate = DateTime(expiry.year, expiry.month, expiry.day);
    return expiryDate.isBefore(todayDate);
  }

  String _formatExpiry(String? isoDate) {
    if (isoDate == null) return '—';
    final dt = DateTime.tryParse(isoDate);
    if (dt == null) return isoDate;
    return DateFormat('dd MMM yyyy').format(dt);
  }

  Widget _buildHeroHeader() {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.border, AppColors.cardBackground],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppColors.border, width: 2),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.memberName[0].toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        SizedBox(height: 20),
        Text(
          widget.memberName,
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.0,
          ),
        ),
        SizedBox(height: 8),
        Builder(builder: (_) {
          final status = widget.member?.status ?? '';
          Color badgeColor;
          switch (status.toLowerCase()) {
            case 'active':
              badgeColor = AppColors.emerald;
              break;
            case 'trial':
              badgeColor = AppColors.infoBlue;
              break;
            case 'expired':
              badgeColor = AppColors.error;
              break;
            case 'inactive':
              badgeColor = AppColors.secondaryText;
              break;
            default:
              badgeColor = AppColors.secondaryText;
          }
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              status.toUpperCase(),
              style: GoogleFonts.outfit(
                color: badgeColor,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildActionPanel() {
    final bool isTrial = widget.member?.isTrial ?? false;
    final bool isExpired = _isExpired;

    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _buildActionItem(
            "MESSAGE",
            Icons.chat_rounded,
            AppColors.primaryBlue,
            () => _handleRemind('whatsapp'),
          ),
          _buildActionVerticalDivider(),
          _buildActionItem(
            "AI CALL",
            Icons.support_agent_rounded,
            Colors.purpleAccent,
            () => _handleRemind('call'),
          ),
          if (isTrial || isExpired) ...[
            _buildActionVerticalDivider(),
            _buildActionItem(
              isTrial ? "UPGRADE" : "RENEW",
              Icons.stars_rounded,
              AppColors.success,
              _handleRenew,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionVerticalDivider() {
    return Container(
      height: 30,
      width: 1,
      color: AppColors.border,
    );
  }

  Widget _buildActionItem(String label, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    return Row(
      children: [
        _buildStatTile("TOTAL CHECK-INS", _attendanceSummary?.totalVisits.toString() ?? "0", Icons.bolt_rounded),
        SizedBox(width: 16),
        _buildStatTile("LIFE TIME VALUE", "₹${widget.member?.lifetimeValue.toInt() ?? 0}", Icons.account_balance_wallet_rounded),
      ],
    );
  }

  Widget _buildStatTile(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primaryBlue, size: 20),
            SizedBox(height: 16),
            Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: AppColors.secondaryText,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 16.0),
      child: Text(
        title,
        style: TextStyle(
          color: AppColors.secondaryText,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildMembershipInfo() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _buildInfoTile(
            "CURRENT PLAN",
            _planLabel(widget.member),
            Icons.card_membership_rounded,
          ),
          _buildInfoDivider(),
          _buildInfoTile(
            "CONTACT NUMBER",
            widget.member?.phone ?? "NOT PROVIDED",
            Icons.phone_iphone_rounded,
          ),
          _buildInfoDivider(),
          _buildInfoTile(
            "VALID UNTIL",
            _formatExpiry(widget.member?.expiryDate),
            Icons.event_available_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String label, String value, IconData icon, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.border.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.secondaryText, size: 18),
          ),
          SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: valueColor ?? Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoDivider() {
    return Divider(color: AppColors.border, height: 1, indent: 60);
  }

  Widget _buildAttendanceCard() {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AttendanceHistoryScreen(memberId: _memberId, memberName: widget.memberName))),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "LAST SEEN",
                  style: TextStyle(color: AppColors.secondaryText, fontSize: 10, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  _attendanceSummary?.lastArrival != null 
                    ? DateFormat('EEEE, dd MMM').format(_attendanceSummary!.lastArrival!) 
                    : "NEVER VISITED",
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            Spacer(),
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.history_rounded, color: AppColors.primaryBlue, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderHistoryCard() {
    final hasReminders = _reminders != null && _reminders!.isNotEmpty;
    final latest = hasReminders ? _reminders!.first : null;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_toggle_off_rounded, color: AppColors.primaryBlue, size: 18),
              SizedBox(width: 8),
              Text(
                "RECENT ACTIVITY",
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          SizedBox(height: 20),
          Text(
            latest != null
                ? "Last ${latest.method.toUpperCase()} reminder sent on ${latest.scheduledDate}"
                : "No communication logged for this warrior yet.",
            style: TextStyle(color: AppColors.secondaryText, fontSize: 13, height: 1.5),
          ),
          SizedBox(height: 20),
          InkWell(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => ReminderHistoryScreen(memberId: _memberId)));
            },
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 12),
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.border.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                "VIEW FULL LOGS",
                style: TextStyle(
                  color: AppColors.primaryBlue,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
