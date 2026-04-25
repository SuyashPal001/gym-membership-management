import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';
import '../models/member.dart';
import '../models/payment_models.dart';
import '../services/api_exception.dart';
import '../services/api_service.dart';
import 'member_detail_screen.dart';

class UnpaidPaymentsScreen extends StatefulWidget {
  @override
  _UnpaidPaymentsScreenState createState() => _UnpaidPaymentsScreenState();
}

class _UnpaidPaymentsScreenState extends State<UnpaidPaymentsScreen> {
  List<PaymentSummary> _allData = [];
  List<PaymentSummary> _filteredList = [];
  bool _isLoading = true;

  double _monthlyCollected = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.fetchPaymentSummaries();
      if (!mounted) return;
      setState(() {
        _allData = data;
        _filteredList = data;
      });
    } on ApiException catch (e) {
      _showSnackbar(e.message, AppColors.error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }

    // Stats are non-critical — failure must not blank the member list
    try {
      final stats = await ApiService.fetchPaymentStats();
      if (mounted) setState(() {
        _monthlyCollected = (stats['monthly_collected'] ?? 0).toDouble();
      });
    } catch (_) {}
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

  Future<void> _handleRemind(PaymentSummary item) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Send Reminder",
              style: TextStyle(
                color: AppColors.primaryText,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              item.primaryAction == 'convert'
                  ? "Select method to send conversion message to ${item.memberName}"
                  : "Select method to remind ${item.memberName} about unpaid \u20B9${item.planAmount.toStringAsFixed(0)}",
              style: TextStyle(color: AppColors.secondaryText, fontSize: 13),
            ),
            SizedBox(height: 24),
            _buildReminderOption(
              icon: Icons.chat_bubble_outline,
              title: "WhatsApp",
              subtitle: "Send a text message reminder",
              onTap: () => _triggerReminder(item.id, 'WHATSAPP'),
            ),
            SizedBox(height: 12),
            _buildReminderOption(
              icon: Icons.phone_in_talk_outlined,
              title: "AI Voice Call",
              subtitle: "Automated AI call follow-up",
              onTap: () => _triggerReminder(item.id, 'AI_CALL'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primaryBlue, size: 24),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: AppColors.primaryText,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: AppColors.secondaryText.withOpacity(0.3),
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _triggerReminder(String memberId, String method) async {
    Navigator.pop(context);
    try {
      await ApiService.postReminder(memberId, method);
      _showSnackbar("Reminder scheduled successfully", AppColors.success);
    } on ApiException catch (e) {
      _showSnackbar(e.message, AppColors.error);
    }
  }

  Future<void> _handleMarkPaid(PaymentSummary item) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Confirm Payment",
              style: TextStyle(
                color: AppColors.primaryText,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Text(
              "Mark \u20B9${item.planAmount.toStringAsFixed(0)} as received from ${item.memberName}?",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.secondaryText, fontSize: 14),
            ),
            SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  try {
                    await ApiService.markPaymentAsPaid(memberId: item.id);
                    _showSnackbar(
                      "Payment recorded successfully",
                      AppColors.success,
                    );
                    _fetchInitialData();
                  } on ApiException catch (e) {
                    _showSnackbar(e.message, AppColors.error);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.black,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  "CONFIRM RECEIPT",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
            SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _handleConvert(PaymentSummary item) async {
    try {
      final plans = await ApiService.fetchMembershipTypes();
      if (!mounted) return;

      final selectedPlan = await showModalBottomSheet<MembershipType>(
        context: context,
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => Container(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Convert Member",
                style: TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                "Select a membership plan to enroll ${item.memberName}",
                style: TextStyle(color: AppColors.secondaryText, fontSize: 13),
              ),
              SizedBox(height: 24),
              ...plans.map((p) {
                IconData getPlanIcon(String name) {
                  final n = name.toLowerCase();
                  if (n.contains('12') ||
                      n.contains('year') ||
                      n.contains('annual')) {
                    return Icons.workspace_premium_rounded;
                  }
                  if (n.contains('6') || n.contains('half')) {
                    return Icons.stars_rounded;
                  }
                  if (n.contains('3') || n.contains('quarter')) {
                    return Icons.bolt_rounded;
                  }
                  if (n.contains('1') || n.contains('month')) {
                    return Icons.fitness_center_rounded;
                  }
                  return Icons.star_border_rounded;
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: _buildReminderOption(
                    icon: getPlanIcon(p.name),
                    title: p.name,
                    subtitle: "Full enrollment • \u20B9${p.amount.toInt()}",
                    onTap: () => Navigator.pop(context, p),
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      );

      if (selectedPlan != null) {
        await ApiService.renewMembership(item.id, selectedPlan.id);
        _showSnackbar("Converted to ${selectedPlan.name}!", AppColors.success);
        _fetchInitialData();
      }
    } on ApiException catch (e) {
      _showSnackbar(e.message, AppColors.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final limitDate = today.add(Duration(days: 8));

    final displayList = _filteredList.where((p) {
      if (p.paymentCollected) return false;
      if (!p.hasMembershipPlan && p.lifecycleType != 'trial') return false;

      // Only show trial members whose trial has expired — ongoing trials have nothing to collect.
      if (p.lifecycleType == 'trial') {
        if (p.expiryDate == null) return false;
        final exp = DateTime.tryParse(p.expiryDate!);
        if (exp == null) return false;
        return exp.isBefore(today);
      }

      // Never-paid members always need collection regardless of expiry window
      if (p.lifetimeValue == 0) return true;

      if (p.expiryDate == null) return true;
      final exp = DateTime.tryParse(p.expiryDate!);
      if (exp == null) return true;

      return exp.isBefore(limitDate);
    }).toList();

    int getPriorityLevel(PaymentSummary item) {
      final exp = item.expiryDate != null ? DateTime.tryParse(item.expiryDate!) : null;
      final diff = exp?.difference(today).inDays;

      // Type 3: Enrolled with no initial payment -> RED (Priority 1)
      if (item.lifetimeValue == 0 && item.lifecycleType != 'trial') return 1;

      // Type 2: Trial overdue (ongoing trials are excluded from this list)
      if (item.lifecycleType == 'trial') return 1; // Trial Ended -> RED (Priority 1)

      // Type 1: Regular Paid Member
      if (diff == null || diff <= 0) return 1; // Overdue / Due Today -> RED (Priority 1)
      if (diff >= 1 && diff <= 3) return 2;    // Due in 1-3 days -> YELLOW (Priority 2)
      if (diff >= 4 && diff <= 6) return 3;    // Due in 4-6 days -> EMERALD (Priority 3)
      return 4;                                // Due in exactly 7 days -> GREY/WHITE (Priority 4)
    }

    displayList.sort((a, b) {
      final pA = getPriorityLevel(a);
      final pB = getPriorityLevel(b);

      if (pA != pB) return pA.compareTo(pB);

      if (a.expiryDate == null) return 1;
      if (b.expiryDate == null) return -1;
      return a.expiryDate!.compareTo(b.expiryDate!);
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Colors.white,
            size: 18,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text(
          'COLLECT',
          style: TextStyle(
            fontSize: 14, 
            fontWeight: FontWeight.w900, 
            letterSpacing: 1.5,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppColors.secondaryText, size: 20),
            onPressed: _fetchInitialData,
          )
        ],
      ),
      body: Column(
        children: [
          _buildHeroCard(),
          SizedBox(height: 10),
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: AppColors.accent,
                      strokeWidth: 2,
                    ),
                  )
                : displayList.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        itemCount: displayList.length,
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        itemBuilder: (context, idx) =>
                            _buildMemberRow(displayList[idx]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard() {
    final months = [
      'JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE',
      'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER',
    ];
    final currentMonthName = months[DateTime.now().month - 1];
    const gold = Color(0xFFC9992A);

    // Calculate mutually exclusive segments
    int overdueCount = _allData.where((p) => p.urgencyLabel.contains('OVERDUE')).length;
    int dueTodayCount = _allData.where((p) => p.urgencyLabel.contains('TODAY')).length;
    int upcomingCount = _allData.length - overdueCount - dueTodayCount;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
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
          // Left Side: Total Collected
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "COLLECTED IN $currentMonthName",
                  style: GoogleFonts.outfit(
                    color: gold,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "\u20B9 ${_monthlyCollected.toStringAsFixed(0)}",
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    letterSpacing: -1,
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

          // Right Side: Actionable Segments
          Expanded(
            flex: 6,
            child: Column(
              children: [
                _buildCompactStat("OVERDUE", overdueCount.toString(), AppColors.error),
                const SizedBox(height: 6),
                _buildCompactStat("DUE TODAY", dueTodayCount.toString(), AppColors.warning),
                const SizedBox(height: 6),
                _buildCompactStat("UPCOMING", upcomingCount.toString(), AppColors.emerald),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.done_all_rounded,
            color: AppColors.secondaryText.withOpacity(0.1),
            size: 48,
          ),
          SizedBox(height: 16),
          Text(
            "No pending payments",
            style: GoogleFonts.outfit(
              color: AppColors.secondaryText.withOpacity(0.3),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberRow(PaymentSummary item) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final exp = item.expiryDate != null ? DateTime.tryParse(item.expiryDate!) : null;
    final diff = exp?.difference(today).inDays;

    Color dateColor = AppColors.secondaryText;
    String badgeText = "NO EXPIRY";
    String displayName = item.displayPlanName;

    // Evaluate Frontend Rules
    if (item.lifecycleType == 'trial') {
      if (diff != null && diff < 0) {
        dateColor = AppColors.error;
        badgeText = "TRIAL ENDED";
      } else {
        dateColor = AppColors.infoBlue;
        badgeText = "TRIAL ONGOING";
      }
    } else if (item.lifetimeValue == 0) {
      dateColor = AppColors.error;
      final enrolled = item.joinDate != null ? DateTime.tryParse(item.joinDate!) : null;
      final overdueDays = enrolled != null
          ? today.difference(DateTime(enrolled.year, enrolled.month, enrolled.day)).inDays
          : 0;
      if (overdueDays == 0) {
        badgeText = "DUE TODAY";
      } else {
        badgeText = "OVERDUE $overdueDays ${overdueDays == 1 ? 'DAY' : 'DAYS'}";
      }
    } else {
      if (diff == null) {
        dateColor = AppColors.error;
        badgeText = "OVERDUE";
      } else if (diff < 0) {
        dateColor = AppColors.error;
        final d = diff.abs();
        badgeText = "OVERDUE $d ${d == 1 ? 'DAY' : 'DAYS'}";
      } else if (diff == 0) {
        dateColor = AppColors.error;
        badgeText = "DUE TODAY";
      } else if (diff >= 1 && diff <= 3) {
        dateColor = AppColors.infoBlue;
        badgeText = "DUE IN $diff ${diff == 1 ? 'DAY' : 'DAYS'}";
      } else if (diff >= 4 && diff <= 6) {
        dateColor = AppColors.emerald;
        badgeText = "DUE IN $diff DAYS";
      } else {
        dateColor = AppColors.secondaryText.withOpacity(0.7);
        badgeText = "DUE IN 7 DAYS";
      }
    }

    return InkWell(
      onTap: () {
        final shellMember = Member(
          id: item.id,
          memberName: item.memberName,
          phone: item.phone,
          status: item.status,
          expiryDate: item.expiryDate,
        );
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => MemberDetailScreen(memberName: item.memberName, member: shellMember),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    item.memberName[0].toUpperCase(),
                    style: TextStyle(
                      color: AppColors.primaryText,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.memberName,
                        style: TextStyle(
                          color: AppColors.primaryText,
                          fontWeight: FontWeight.w600,
                          fontSize: 17,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        displayName.toUpperCase(),
                        style: TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (item.lifecycleType != 'trial' && item.planAmount > 0)
                      Text(
                        "\u20B9 ${item.planAmount.toStringAsFixed(0)}",
                        style: TextStyle(
                          color: AppColors.primaryText,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                    if (item.lifecycleType != 'trial' && item.planAmount > 0) SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: dateColor.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badgeText,
                        style: GoogleFonts.outfit(
                          color: dateColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _handleRemind(item),
                    icon: Icon(
                      Icons.notifications_active_outlined,
                      size: 16,
                      color: Colors.orangeAccent,
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.orangeAccent.withOpacity(0.1),
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: Colors.orangeAccent.withOpacity(0.5),
                        ),
                      ),
                    ),
                    label: Text(
                      "REMIND",
                      style: TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => item.primaryAction == 'convert'
                        ? _handleConvert(item)
                        : _handleMarkPaid(item),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.07),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.white.withOpacity(0.2)),
                      ),
                    ),
                    child: Text(
                      item.primaryAction == 'convert' ? "CONVERT" : "MARK PAID",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
