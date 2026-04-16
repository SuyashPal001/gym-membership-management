import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../screens/member_detail_screen.dart';

class RecentActivity extends StatelessWidget {
  final List<dynamic> attentionMembers;

  const RecentActivity({Key? key, required this.attentionMembers}) : super(key: key);

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('dd MMM').format(dt);
    } catch (_) {
      return '';
    }
  }

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
        if (attentionMembers.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20.0),
            child: Center(
              child: Text(
                'All members are up to date',
                style: TextStyle(color: Colors.green.withOpacity(0.7), fontWeight: FontWeight.w500),
              ),
            ),
          )
        else
          ListView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: attentionMembers.length,
            itemBuilder: (context, index) {
              final member = attentionMembers[index];
              final label = member['label'] as String;
              final expiryDate = _formatDate(member['expiry_date']);
              
              String subtitle = '';
              String badgeText = '';
              Color badgeColor = Colors.grey;
              IconData icon = Icons.info_outline;

              if (label == 'expiring') {
                subtitle = 'Expires on $expiryDate';
                badgeText = 'Expiring';
                badgeColor = Colors.orangeAccent;
                icon = Icons.schedule;
              } else if (label == 'trial') {
                subtitle = 'Trial member';
                badgeText = 'Trial';
                badgeColor = Colors.blueAccent;
                icon = Icons.timer;
              } else if (label == 'overdue') {
                subtitle = 'Expired on $expiryDate';
                badgeText = 'Overdue';
                badgeColor = Colors.redAccent;
                icon = Icons.warning_amber_rounded;
              }

              return _buildListItem(
                context,
                icon,
                member['member_name'] ?? 'Unknown',
                subtitle,
                badgeColor,
                badgeText,
              );
            },
          ),
      ],
    );
  }

  Widget _buildListItem(BuildContext context, IconData icon, String title, String subtitle, Color color, String badge) {
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
        child: Icon(icon, color: color, size: 20),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.w600),
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: color.withOpacity(0.5)),
            ),
            child: Text(
              badge,
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ],
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
