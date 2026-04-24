import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../models/member.dart';
import '../models/payment_models.dart';
import '../services/api_exception.dart';
import '../services/api_service.dart';
import 'package:lottie/lottie.dart';
import 'member_detail_screen.dart';

class PaymentsScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const PaymentsScreen({Key? key, this.onBack}) : super(key: key);

  @override
  _PaymentsScreenState createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  List<PaymentSummary> _allData = [];
  List<PaymentSummary> _filteredList = [];
  List<PaymentSummary> _paidList = [];
  bool _isLoading = true;
  String _activeFilter = 'All';
  int _activeTabIndex = 0;

  double _totalCollected = 0.0;
  int _expiringThisWeekCount = 0;
  int _overdueCount = 0;
  double _overdueAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        ApiService.fetchPaymentSummaries(),
        ApiService.fetchPaymentSummaries(paid: true),
        ApiService.fetchPaymentStats(),
      ]);
      final unpaid = results[0] as List<PaymentSummary>;
      final paid = results[1] as List<PaymentSummary>;
      final stats = results[2] as Map<String, dynamic>;

      if (!mounted) return;
      setState(() {
        _allData = unpaid;
        _filteredList = unpaid;
        _paidList = paid;
        _totalCollected = (stats['monthly_collected'] as num?)?.toDouble() ?? 0.0;
        _isLoading = false;
      });
      _computeGlobalStats();
    } on ApiException catch (e) {
      _showSnackbar(e.message, AppColors.error);
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _computeGlobalStats() {
    _expiringThisWeekCount = 0;
    _overdueCount = 0;
    _overdueAmount = 0.0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekLimit = today.add(const Duration(days: 7));

    for (final p in _allData) {
      if (p.expiryDate == null) continue;
      final exp = DateTime.tryParse(p.expiryDate!);
      if (exp == null) continue;
      if (exp.isBefore(today)) {
        _overdueCount++;
        _overdueAmount += p.planAmount;
      } else if (exp.isBefore(weekLimit)) {
        _expiringThisWeekCount++;
      }
    }
  }

  Future<void> _changeExpiryFilter(String filter) async {
    setState(() { _activeFilter = filter; _isLoading = true; });
    try {
      final param = (filter == 'All') ? null : filter.toLowerCase().replaceAll(' ', '_');
      final data = await ApiService.fetchPaymentSummaries(expiryFilter: param);
      if (mounted) setState(() { _filteredList = data; _isLoading = false; });
    } on ApiException catch (e) {
      _showSnackbar(e.message, AppColors.error);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackbar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info_outline, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(
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
          side: const BorderSide(color: AppColors.border),
        ),
        margin: const EdgeInsets.all(20),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _handleRemind(PaymentSummary item) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
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
            const SizedBox(height: 8),
            Text(
              item.primaryAction == 'convert'
                  ? "Select method to send conversion message to ${item.memberName}"
                  : "Select method to remind ${item.memberName} about unpaid \u20B9${item.planAmount.toStringAsFixed(0)}",
              style: TextStyle(color: AppColors.secondaryText, fontSize: 13),
            ),
            const SizedBox(height: 24),
            _buildReminderOption(
              icon: Icons.chat_bubble_outline,
              title: "WhatsApp",
              subtitle: "Send a text message reminder",
              onTap: () => _triggerReminder(item.id, 'WHATSAPP'),
            ),
            const SizedBox(height: 12),
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primaryBlue, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: AppColors.primaryText,
                          fontWeight: FontWeight.bold)),
                  Text(subtitle,
                      style: const TextStyle(
                          color: AppColors.secondaryText, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                color: AppColors.secondaryText.withOpacity(0.3), size: 14),
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
      shape: const RoundedRectangleBorder(
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
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              "Mark \u20B9${item.planAmount.toStringAsFixed(0)} as received from ${item.memberName}?",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.secondaryText, fontSize: 14),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  try {
                    await ApiService.markPaymentAsPaid(memberId: item.id);
                    _showSnackbar("Payment recorded successfully", AppColors.success);
                    _fetchInitialData();
                  } on ApiException catch (e) {
                    _showSnackbar(e.message, AppColors.error);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  "CONFIRM RECEIPT",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, letterSpacing: 1.0),
                ),
              ),
            ),
            const SizedBox(height: 8),
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
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Convert Member",
                  style: TextStyle(
                      color: AppColors.primaryText,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text("Select a membership plan to enroll ${item.memberName}",
                  style: TextStyle(
                      color: AppColors.secondaryText, fontSize: 13)),
              const SizedBox(height: 24),
              ...plans.map((p) {
                IconData getPlanIcon(String name) {
                  final n = name.toLowerCase();
                  if (n.contains('12') || n.contains('year') || n.contains('annual')) return Icons.workspace_premium_rounded;
                  if (n.contains('6') || n.contains('half')) return Icons.stars_rounded;
                  if (n.contains('3') || n.contains('quarter')) return Icons.bolt_rounded;
                  if (n.contains('1') || n.contains('month')) return Icons.fitness_center_rounded;
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
    final displayList = _activeTabIndex == 1 ? _paidList : _filteredList;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
          onPressed: () => widget.onBack != null
              ? widget.onBack!()
              : Navigator.of(context).pop(),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text(
          'PAYMENTS',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.white),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh,
                color: AppColors.secondaryText, size: 20),
            onPressed: _fetchInitialData,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSummaryStrip(),
          _buildFilterChips(),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              children: [
                _buildTab("Unpaid", 0),
                const SizedBox(width: 25),
                _buildTab("Paid History", 1),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _isLoading
                ? Center(
                    child: Lottie.asset(
                      'assets/animations/loader.json',
                      width: 200,
                      height: 200,
                      delegates: LottieDelegates(
                        values: [
                          ValueDelegate.colorFilter(
                            ['**'],
                            value: ColorFilter.mode(AppColors.primaryBlue, BlendMode.modulate),
                          ),
                        ],
                      ),
                    ),
                  )
                : displayList.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        itemCount: displayList.length,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        itemBuilder: (context, idx) =>
                            _buildMemberCard(displayList[idx]),
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
          Icon(Icons.done_all_rounded,
              color: AppColors.secondaryText.withOpacity(0.1), size: 48),
          const SizedBox(height: 16),
          Text(
            "No records found",
            style: TextStyle(
                color: AppColors.secondaryText.withOpacity(0.3), fontSize: 13),
          ),
        ],
      ),
    );
  }  Widget _buildSummaryStrip() {
    const gold = Color(0xFFC9992A);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withOpacity(0.05),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'STUDIO COLLECTION',
            style: GoogleFonts.outfit(
              color: gold,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '\u20B9${_totalCollected.toStringAsFixed(0)}',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.w800,
              height: 1,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildRoyalModule(
                  'EXPIRING', 
                  '$_expiringThisWeekCount members', 
                  AppColors.warning
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildRoyalModule(
                  'OVERDUE', 
                  '\u20B9${_overdueAmount.toStringAsFixed(0)}', 
                  AppColors.error
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoyalModule(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground.withOpacity(0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.15), width: 0.5),
        gradient: RadialGradient(
          center: const Alignment(-0.8, -0.8),
          radius: 1.5,
          colors: [
            color.withOpacity(0.12),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final options = ['All', 'Today', 'This Week'];
    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        itemCount: options.length,
        itemBuilder: (context, idx) {
          final opt = options[idx];
          final isActive = _activeFilter == opt;
          return Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: InkWell(
              onTap: () => _changeExpiryFilter(opt),
              borderRadius: BorderRadius.circular(30),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: isActive ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.02),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: isActive ? Colors.white.withOpacity(0.4) : Colors.white.withOpacity(0.08),
                    width: 1.2,
                  ),
                ),
                child: Center(
                  child: Text(
                    opt.toUpperCase(),
                    style: GoogleFonts.outfit(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: isActive ? Colors.white : Colors.white.withOpacity(0.4),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final isActive = _activeTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _activeTabIndex = index),
      child: Padding(
        padding: const EdgeInsets.only(right: 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: GoogleFonts.outfit(
                color: isActive ? Colors.white : Colors.white.withOpacity(0.3),
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isActive ? 20 : 0,
              height: 2,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberCard(PaymentSummary item) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final exp = item.expiryDate != null ? DateTime.tryParse(item.expiryDate!) : null;
    final diff = exp?.difference(today).inDays;

    // Badge color + text — mirrors collect page logic exactly
    Color dateColor = AppColors.secondaryText;
    String badgeText = "NO EXPIRY";
    String displayName = item.displayPlanName;

    if (item.lifecycleType == 'trial') {
      if (diff != null && diff < 0) {
        dateColor = AppColors.error;
        badgeText = "TRIAL ENDED";
      } else {
        dateColor = AppColors.infoBlue;
        badgeText = "TRIAL ONGOING";
      }
    } else if (item.paymentCollected) {
      dateColor = AppColors.success;
      badgeText = "PAID";
    } else if (item.lifetimeValue == 0) {
      dateColor = AppColors.error;
      final enrolled = item.joinDate != null ? DateTime.tryParse(item.joinDate!) : null;
      final overdueDays = enrolled != null
          ? today.difference(DateTime(enrolled.year, enrolled.month, enrolled.day)).inDays
          : 0;
      badgeText = overdueDays == 0
          ? "DUE TODAY"
          : "OVERDUE $overdueDays ${overdueDays == 1 ? 'DAY' : 'DAYS'}";
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
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
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
                    style: const TextStyle(
                        color: AppColors.primaryText,
                        fontWeight: FontWeight.bold,
                        fontSize: 18),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.memberName,
                        style: const TextStyle(
                            color: AppColors.primaryText,
                            fontWeight: FontWeight.w600,
                            fontSize: 17),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        displayName.toUpperCase(),
                        style: const TextStyle(
                            color: AppColors.secondaryText,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5),
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
                        style: const TextStyle(
                            color: AppColors.primaryText,
                            fontWeight: FontWeight.w800,
                            fontSize: 17),
                      ),
                    if (item.lifecycleType != 'trial' && item.planAmount > 0)
                      const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
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
                            letterSpacing: 0.8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (_activeTabIndex == 0) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => _handleRemind(item),
                      icon: const Icon(
                        Icons.notifications_active_outlined,
                        size: 16,
                        color: Colors.orangeAccent,
                      ),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.orangeAccent.withOpacity(0.1),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                              color: Colors.orangeAccent.withOpacity(0.5)),
                        ),
                      ),
                      label: const Text(
                        "REMIND",
                        style: TextStyle(
                            color: Colors.orangeAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: item.primaryAction == 'convert'
                          ? () => _handleConvert(item)
                          : () => _handleMarkPaid(item),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.07),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                              color: Colors.white.withOpacity(0.2)),
                        ),
                      ),
                      child: Text(
                        item.primaryAction == 'convert'
                            ? "CONVERT"
                            : "MARK PAID",
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
