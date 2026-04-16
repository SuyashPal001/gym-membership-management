import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../widgets/top_bar.dart';
import '../widgets/category_row.dart';
import '../widgets/featured_card.dart';
import '../widgets/recent_activity.dart';
import '../screens/attendance_screen.dart';
import '../screens/payments_screen.dart';
import '../screens/member_list_screen.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> _attentionMembers = [];
  bool _isLoadingAttention = true;

  int _inGymCount = -1;
  int _activeMemberCount = -1;
  double _pendingAmount = -1;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoadingAttention = true;
    });
    
    try {
      await Future.wait([
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

        ApiService.fetchMembers(filters: {'status': 'active'}).then((res) {
          if (mounted) setState(() => _activeMemberCount = res.length);
        }).catchError((_) {
          if (mounted) setState(() => _activeMemberCount = 0);
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
            physics: AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                TopBar(),
                _buildMetricsRow(context),
                SizedBox(height: 10),
                CategoryRow(),
                FeaturedCard(),
                RecentActivity(attentionMembers: _attentionMembers),
                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricsRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 5.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildMetricCard(
            context, 
            "In Gym", 
            _inGymCount == -1 ? '--' : _inGymCount.toString(), 
            Icons.people_alt, 
            AppColors.accent, 
            () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => AttendanceScreen()));
            }
          ),
          SizedBox(width: 10),
          _buildMetricCard(
            context, 
            "Active", 
            _activeMemberCount == -1 ? '--' : _activeMemberCount.toString(), 
            Icons.fitness_center, 
            Colors.white, 
            () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => MemberListScreen()));
            }
          ),
          SizedBox(width: 10),
          _buildMetricCard(
            context, 
            "Pending", 
            _pendingAmount == -1 ? '--' : '₹${_pendingAmount.toStringAsFixed(0)}', 
            Icons.warning_amber_rounded, 
            Colors.orangeAccent, 
            () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => PaymentsScreen()));
            }
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(BuildContext context, String title, String value, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 20),
              SizedBox(height: 12),
              Text(
                value,
                style: TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


