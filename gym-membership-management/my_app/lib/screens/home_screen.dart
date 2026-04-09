import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../widgets/top_bar.dart';
import '../widgets/search_bar.dart';
import '../widgets/category_row.dart';
import '../widgets/featured_card.dart';
import '../widgets/recent_activity.dart';
import '../widgets/bottom_nav_bar.dart';
import '../screens/attendance_screen.dart';
import '../screens/payments_screen.dart';
import '../screens/member_list_screen.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              TopBar(),
              _buildMetricsRow(context),
              CustomSearchBar(),
              SizedBox(height: 10),
              CategoryRow(),
              FeaturedCard(),
              RecentActivity(),
              SizedBox(height: 20),
            ],
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
          _buildMetricCard(context, "In Gym", "45", Icons.people_alt, AppColors.accent, () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => AttendanceScreen()));
          }),
          SizedBox(width: 10),
          _buildMetricCard(context, "Active", "120", Icons.fitness_center, Colors.white, () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => MemberListScreen()));
          }),
          SizedBox(width: 10),
          _buildMetricCard(context, "Pending", "\$450", Icons.warning_amber_rounded, Colors.orangeAccent, () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => PaymentsScreen()));
          }),
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

