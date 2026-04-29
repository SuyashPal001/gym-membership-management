import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../screens/member_detail_screen.dart';

class AttendanceScreen extends StatelessWidget {
  final List<Map<String, dynamic>> _liveMembers = [
    {
      'name': 'Alex Johnson',
      'arrived': '10 mins ago (8:15 AM)',
      'status': 'debt',
      'statusText': '🔴 Owes \$50',
      'streak': '4 Days',
    },
    {
      'name': 'Sarah Smith',
      'arrived': '45 mins ago',
      'status': 'active',
      'statusText': '🟢 Active VIP',
      'streak': '2 Days',
    },
    {
      'name': 'Mike Davis',
      'arrived': '1 hour ago',
      'status': 'trial',
      'statusText': '🟡 Trial ends tomorrow',
      'streak': '1st Visit',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: AppColors.primaryText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Live Floor Activity", style: TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
            child: Text(
              "Currently in Gym: 32",
              style: TextStyle(color: AppColors.secondaryText, fontSize: 16),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(20),
              itemCount: _liveMembers.length,
              itemBuilder: (context, index) {
                final member = _liveMembers[index];
                bool isDebt = member['status'] == 'debt';
                bool isTrial = member['status'] == 'trial';

                return Container(
                  margin: EdgeInsets.only(bottom: 16),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDebt ? Colors.redAccent.withOpacity(0.5) : AppColors.border,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: isDebt ? Colors.redAccent.withOpacity(0.2) : AppColors.accent.withOpacity(0.2),
                                child: Icon(Icons.person, color: isDebt ? Colors.redAccent : AppColors.accent),
                              ),
                              SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    member['name'],
                                    style: TextStyle(
                                      color: AppColors.primaryText,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    "Arrived ${member['arrived']} • Streak: ${member['streak']}",
                                    style: TextStyle(
                                      color: AppColors.secondaryText,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            member['statusText'],
                            style: TextStyle(
                              color: isDebt ? Colors.redAccent : (isTrial ? Colors.orangeAccent : AppColors.accent),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Expanded(
                            child: Wrap(
                              alignment: WrapAlignment.end,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (isDebt || isTrial)
                                  ElevatedButton(
                                    onPressed: () {},
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isDebt ? Colors.redAccent : Colors.orangeAccent,
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.symmetric(horizontal: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    ),
                                    child: Text(isDebt ? "Collect Payment" : "Pitch Plan"),
                                  ),
                                OutlinedButton(
                                  onPressed: () {
                                    Navigator.push(context, MaterialPageRoute(builder: (context) => MemberDetailScreen(memberName: member['name'])));
                                  },
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: AppColors.border),
                                    padding: EdgeInsets.symmetric(horizontal: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  ),
                                  child: Text("Profile", style: TextStyle(color: AppColors.primaryText)),
                                ),
                              ],
                            ),
                          )
                        ],
                      )
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
