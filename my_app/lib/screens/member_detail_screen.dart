import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class MemberDetailScreen extends StatelessWidget {
  final String memberName;

  const MemberDetailScreen({Key? key, required this.memberName}) : super(key: key);

  Map<String, dynamic> _getMemberData(String name) {
    if (name.contains("Mike")) {
      return {
        'plan': 'Trial (Ends tomorrow)',
        'joined': 'Today',
        'visits': '1',
        'ltv': '\$0',
        'streak': '1st Visit',
        'isDebt': false,
        'isTrial': true,
        'amountDue': '\$0'
      };
    } else if (name.contains("Sarah")) {
      return {
        'plan': 'Active VIP',
        'joined': 'Mar 2023',
        'visits': '204',
        'ltv': '\$2.4K',
        'streak': '2 Days',
        'isDebt': false,
        'isTrial': false,
        'amountDue': '\$0'
      };
    } else {
      // Default / Alex
      return {
        'plan': 'Active Premium',
        'joined': 'Jan 2024',
        'visits': '142',
        'ltv': '\$1.2K',
        'streak': '3 Days in a row!',
        'isDebt': true,
        'isTrial': false,
        'amountDue': '\$50.00'
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _getMemberData(memberName);
    final bool isActionable = data['isDebt'] || data['isTrial'];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: AppColors.primaryText),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: 20),
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: AppColors.cardBackground,
                    child: Text(
                      memberName[0],
                      style: TextStyle(color: data['isDebt'] ? Colors.redAccent : AppColors.accent, fontSize: 40, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (data['isDebt'])
                    Positioned(
                      bottom: 0,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(10)),
                        child: Text("OWES MONEY", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: 16),
            Text(
              memberName,
              style: TextStyle(color: AppColors.primaryText, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: data['isTrial'] ? Colors.orangeAccent.withOpacity(0.1) : AppColors.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: data['isTrial'] ? Colors.orangeAccent : AppColors.accent),
              ),
              child: Text(data['plan'], style: TextStyle(color: data['isTrial'] ? Colors.orangeAccent : AppColors.accent, fontWeight: FontWeight.bold)),
            ),
            SizedBox(height: 30),
            
            // Stats Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                children: [
                  _buildStatCard("Joined", data['joined'], Icons.calendar_month),
                  SizedBox(width: 10),
                  _buildStatCard("Visits", data['visits'], Icons.directions_run),
                  SizedBox(width: 10),
                  _buildStatCard("LTV", data['ltv'], Icons.attach_money),
                ],
              ),
            ),
            
            SizedBox(height: 30),

            // Urgent Revenue Action
            if (isActionable)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(20),
                  margin: EdgeInsets.only(bottom: 30),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: data['isDebt'] ? Colors.redAccent : Colors.orangeAccent, width: 2),
                  ),
                  child: Column(
                    children: [
                      Text(
                        data['isDebt'] ? "Pending Dues: ${data['amountDue']}" : "Trial Expiring Soon",
                        style: TextStyle(
                          color: data['isDebt'] ? Colors.redAccent : Colors.orangeAccent,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {},
                              icon: Icon(Icons.chat, size: 16),
                              label: Text("WhatsApp", style: TextStyle(fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                side: BorderSide(color: AppColors.border),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {},
                              icon: Icon(Icons.campaign, size: 16),
                              label: Text("AI Call", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            
            // Insight Info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Current Streak", style: TextStyle(color: AppColors.secondaryText, fontSize: 14)),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.local_fire_department, color: Colors.orangeAccent),
                        SizedBox(width: 8),
                        Text(data['streak'], style: TextStyle(color: AppColors.primaryText, fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    SizedBox(height: 20),
                    Text("Top Engagement", style: TextStyle(color: AppColors.secondaryText, fontSize: 14)),
                    SizedBox(height: 8),
                    Text("Morning Classes", style: TextStyle(color: AppColors.primaryText, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),

            SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: Icon(Icons.autorenew),
                  label: Text("Renew Membership", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.secondaryText, size: 20),
            SizedBox(height: 8),
            Text(value, style: TextStyle(color: AppColors.primaryText, fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text(title, style: TextStyle(color: AppColors.secondaryText, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
