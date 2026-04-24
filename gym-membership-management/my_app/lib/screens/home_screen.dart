import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../widgets/top_bar.dart';
import '../widgets/category_row.dart';
import '../widgets/featured_card.dart';
import '../widgets/recent_activity.dart';
import '../screens/attendance_screen.dart';
import '../screens/payments_screen.dart';
import '../screens/member_list_screen.dart';
import '../screens/members_growth_screen.dart';
import '../screens/add_member_screen.dart';
import '../screens/unpaid_payments_screen.dart';
import '../screens/voice_log_screen.dart';
import '../screens/staff_screen.dart';
import '../services/api_service.dart';
import '../models/member.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);
  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  List<dynamic> _attentionMembers = [];
  bool _isLoadingAttention = true;
  bool _isLoaded = false;

  int _inGymCount = -1;
  int _activeMemberCount = -1;
  int _totalMembers = -1;
  double _pendingAmount = -1;
  String _userName = "";
  String _growthLabel = '--';

  bool get _isFirstVisit => _isLoaded && _totalMembers == 0;

  String _computeGrowthLabel(List<Member> members) {
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month);
    final lastMonth = DateTime(now.year, now.month - 1);

    int thisCount = 0;
    int lastCount = 0;
    for (final m in members) {
      if (m.joinDate == null) continue;
      final d = DateTime.tryParse(m.joinDate!);
      if (d == null) continue;
      final month = DateTime(d.year, d.month);
      if (month == thisMonth) thisCount++;
      if (month == lastMonth) lastCount++;
    }

    if (lastCount == 0) return thisCount > 0 ? '+$thisCount new' : '--';
    final pct = ((thisCount - lastCount) / lastCount * 100).round();
    return pct >= 0 ? '+$pct%' : '$pct%';
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void reload() => _loadData();

  Future<void> _loadData() async {
    setState(() {
      _isLoadingAttention = true;
    });

    try {
      await Future.wait<dynamic>([
        ApiService.fetchGymProfile().then((res) {
          if (mounted) setState(() => _userName = (res['owner_name'] as String?)?.trim() ?? '');
        }).catchError((_) {}),

        ApiService.fetchAttentionMembers().then((res) {
          if (mounted) setState(() { _attentionMembers = res; _isLoadingAttention = false; });
        }).catchError((_) {
          if (mounted) setState(() => _isLoadingAttention = false);
        }),

        ApiService.fetchLiveAttendance().then((res) {
          if (mounted) setState(() => _inGymCount = res.length);
        }).catchError((_) {
          if (mounted) setState(() => _inGymCount = 0);
        }),

        ApiService.fetchMembers().then((res) {
          if (mounted) setState(() {
            _totalMembers = res.length;
            _activeMemberCount = res.where((m) => m.status == 'active' || m.status == 'trial').length;
            _growthLabel = _computeGrowthLabel(res);
          });
        }).catchError((e) {
          debugPrint('[home] fetchMembers error: $e');
          if (mounted) setState(() { _totalMembers = 0; _activeMemberCount = 0; _growthLabel = '--'; });
        }),

        ApiService.fetchPaymentSummaries(expiryFilter: 'overdue').then((res) {
          if (mounted) setState(() => _pendingAmount = res.fold(0.0, (sum, p) => sum + p.planAmount));
        }).catchError((_) {
          if (mounted) setState(() => _pendingAmount = 0.0);
        }),
      ]);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingAttention = false;
          if (_inGymCount == -1) _inGymCount = 0;
          if (_activeMemberCount == -1) _activeMemberCount = 0;
          if (_pendingAmount == -1) _pendingAmount = 0.0;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppColors.accent,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: !_isLoaded
                ? SizedBox(
                    height: MediaQuery.of(context).size.height * 0.8,
                    child: const Center(
                      child: CircularProgressIndicator(color: AppColors.accent),
                    ),
                  )
                : _isFirstVisit
                    ? _buildFirstVisitLayout(context)
                    : _buildRegularLayout(context),
          ),
        ),
      ),
    );
  }

  // ─── First-time visitor layout ────────────────────────────────────────────

  Widget _buildFirstVisitLayout(BuildContext context) {
    return Column(
      children: [
        TopBar(name: _userName, isFirstVisit: true),
        _buildWelcomeBanner(context),
        const SizedBox(height: 32),
        
        // Horizontal Premium Quick Actions
        _buildSectionHeader("Essential Tools"),
        const SizedBox(height: 12),
        _buildPremiumQuickActions(context),
        
        const SizedBox(height: 40),
        
        // Analytics Teaser
        _buildAnalyticsTeaser(),
        
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildPremiumQuickActions(BuildContext context) {
    final actions = [
      {'label': 'New Member', 'icon': Icons.person_add_rounded, 'screen': AddMemberScreen()},
      {'label': 'Collect Fee', 'icon': Icons.diamond_rounded, 'screen': UnpaidPaymentsScreen()},
      {'label': 'Attendance', 'icon': Icons.door_front_door_rounded, 'screen': AttendanceScreen()},
      {'label': 'Staff', 'icon': Icons.badge_rounded, 'screen': const StaffScreen()},
      {'label': 'Ask AI', 'icon': Icons.auto_awesome_rounded, 'screen': const VoiceLogScreen()},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      clipBehavior: Clip.none,
      padding: const EdgeInsets.only(left: 20),
      child: Row(
        children: actions.map((act) {
          final isFirst = actions.indexOf(act) == 0;
          return Padding(
            padding: const EdgeInsets.only(right: 14),
            child: InkWell(
              onTap: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => act['screen'] as Widget));
                if (mounted) _loadData();
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 140,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isFirst ? AppColors.accent.withOpacity(0.5) : Colors.white.withOpacity(0.05),
                    width: isFirst ? 1.5 : 1.0,
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.03),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isFirst ? AppColors.accent.withOpacity(0.1) : Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        act['icon'] as IconData,
                        color: isFirst ? AppColors.accent : Colors.white.withOpacity(0.7),
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      act['label'] as String,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAnalyticsTeaser() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Blurred background card
          Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.cardBackground.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.02)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  // Mock lines to look like a chart
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 100,
                    child: CustomPaint(
                      painter: SparklinePainter(isGrowth: true),
                    ),
                  ),
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Foreground message
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Icon(Icons.lock_rounded, color: Colors.white.withOpacity(0.5), size: 24),
              ),
              const SizedBox(height: 16),
              Text(
                'Unlock your Ledger',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Analytics appear after your first member.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeBanner(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primaryBlue.withOpacity(0.18),
              AppColors.cardBackground,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primaryBlue.withOpacity(0.25), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primaryBlue.withOpacity(0.4)),
              ),
              child: const Text(
                'YOUR GYM IS LIVE',
                style: TextStyle(
                  color: AppColors.primaryBlue,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Set up in minutes.',
              style: TextStyle(
                color: AppColors.primaryText,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Add your first member to unlock the full dashboard.',
              style: TextStyle(
                color: AppColors.secondaryText,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => AddMemberScreen()));
                if (mounted) _loadData();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.person_add_rounded, color: Colors.black, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Add First Member',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  // ─── Regular user layout ──────────────────────────────────────────────────

  Widget _buildRegularLayout(BuildContext context) {
    return Column(
      children: [
        TopBar(name: _userName),
        _buildSectionHeader("Overview"),
        _buildMetricsRow(context),
        const SizedBox(height: 16),
        _buildSectionHeader("Quick Actions"),
        CategoryRow(onReturn: _loadData),
        const SizedBox(height: 10),
        RecentActivity(attentionMembers: _attentionMembers),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildMetricsRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _buildLargeMetricCard(
                "Members Growth",
                _totalMembers == -1 ? '--' : _totalMembers.toString(),
                _growthLabel,
                () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const MembersGrowthScreen()));
                  if (mounted) _loadData();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      "Members",
                      _activeMemberCount == -1 ? '--' : _activeMemberCount.toString(),
                      Icons.fitness_center_rounded,
                      () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => MemberListScreen()));
                        if (mounted) _loadData();
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _buildMetricCard(
                      "Live Now",
                      _inGymCount == -1 ? '--' : _inGymCount.toString(),
                      Icons.people_alt_rounded,
                      () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => AttendanceScreen()));
                        if (mounted) _loadData();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLargeMetricCard(String title, String value, String growth, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 90,
              width: double.infinity,
              child: CustomPaint(
                painter: SparklinePainter(isGrowth: growth.contains('+')),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.primaryText,
                fontSize: 34,
                fontWeight: FontWeight.w900,
                height: 1,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              growth,
              style: TextStyle(
                color: growth.startsWith('+') ? AppColors.emerald : AppColors.secondaryText,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title.toUpperCase(),
              textAlign: TextAlign.center,
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

  Widget _buildMetricCard(String title, String value, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: AppColors.primaryText,
                fontSize: 30,
                fontWeight: FontWeight.bold,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white.withOpacity(0.7), size: 14),
                const SizedBox(width: 4),
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
        child: Text(
          title,
          style: const TextStyle(
            color: AppColors.primaryText,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }
}

class _SetupStep {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  _SetupStep({required this.icon, required this.title, required this.subtitle, required this.onTap});
}

class SparklinePainter extends CustomPainter {
  final bool isGrowth;
  SparklinePainter({required this.isGrowth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withOpacity(0.15),
          Colors.white.withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final fillPath = Path();

    if (this.isGrowth) {
      path.moveTo(0, size.height * 0.8);
      path.cubicTo(size.width * 0.3, size.height * 0.9, size.width * 0.5, size.height * 0.6, size.width * 0.6, size.height * 0.3);
      path.cubicTo(size.width * 0.8, size.height * 0.1, size.width * 0.9, size.height * 0.2, size.width, size.height * 0.1);
      fillPath.moveTo(0, size.height);
      fillPath.lineTo(0, size.height * 0.8);
      fillPath.cubicTo(size.width * 0.3, size.height * 0.9, size.width * 0.5, size.height * 0.6, size.width * 0.6, size.height * 0.3);
      fillPath.cubicTo(size.width * 0.8, size.height * 0.1, size.width * 0.9, size.height * 0.2, size.width, size.height * 0.1);
      fillPath.lineTo(size.width, size.height);
      fillPath.close();
    } else {
      path.moveTo(0, size.height * 0.2);
      path.cubicTo(size.width * 0.3, size.height * 0.1, size.width * 0.5, size.height * 0.4, size.width * 0.6, size.height * 0.6);
      path.cubicTo(size.width * 0.8, size.height * 0.9, size.width * 0.9, size.height * 0.8, size.width, size.height * 0.9);
      fillPath.moveTo(0, size.height);
      fillPath.lineTo(0, size.height * 0.2);
      fillPath.cubicTo(size.width * 0.3, size.height * 0.1, size.width * 0.5, size.height * 0.4, size.width * 0.6, size.height * 0.6);
      fillPath.cubicTo(size.width * 0.8, size.height * 0.9, size.width * 0.9, size.height * 0.8, size.width, size.height * 0.9);
      fillPath.lineTo(size.width, size.height);
      fillPath.close();
    }

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final endY = this.isGrowth ? size.height * 0.1 : size.height * 0.9;
    canvas.drawCircle(Offset(size.width, endY), 4, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
