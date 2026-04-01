import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../screens/member_detail_screen.dart';

class RecentActivity extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
          child: Text(
            'Attention Required',
            style: TextStyle(
              color: AppColors.primaryText,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ListView(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          children: [
            _buildListItem(
              context,
              Icons.warning_amber_rounded,
              'Alex Johnson',
              'Payment Failed • Tap to resolve',
              Colors.redAccent,
            ),
            _buildListItem(
              context,
              Icons.schedule,
              'Sarah Smith',
              'Membership expires in 3 days',
              Colors.orangeAccent,
            ),
            _buildListItem(
              context,
              Icons.directions_run,
              'Mike Davis',
              'Has not visited in 14 days',
              AppColors.secondaryText,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildListItem(BuildContext context, IconData icon, String title, String subtitle, Color iconColor) {
    return ListTile(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => MemberDetailScreen(memberName: title)));
      },
      leading: Container(
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: AppColors.secondaryText),
      ),
      trailing: Icon(Icons.chevron_right, color: AppColors.secondaryText),
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 5),
    );
  }
}
