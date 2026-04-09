import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../screens/voice_log_screen.dart';
import '../screens/add_member_screen.dart';
import '../screens/attendance_screen.dart';
import '../screens/scan_book_screen.dart';

class CategoryRow extends StatelessWidget {
  final List<Map<String, dynamic>> categories = [
    {'label': 'Check-In', 'icon': Icons.how_to_reg, 'screen': AttendanceScreen()},
    {'label': 'AI Ledger', 'icon': Icons.auto_awesome, 'screen': ScanBookScreen()},
    {'label': 'New Member', 'icon': Icons.person_add, 'screen': AddMemberScreen()},
    {'label': 'Ask AI', 'icon': Icons.graphic_eq, 'screen': VoiceLogScreen()},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      width: double.infinity,
      child: Center(
        child: ListView.builder(
          shrinkWrap: true, // center the items horizontally
          scrollDirection: Axis.horizontal,
          itemCount: categories.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.0),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => categories[index]['screen']),
                  );
                },
                child: Column(
                  children: [
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Icon(
                        categories[index]['icon'],
                        color: AppColors.accent,
                        size: 28,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      categories[index]['label'],
                      style: TextStyle(
                        color: AppColors.primaryText,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
