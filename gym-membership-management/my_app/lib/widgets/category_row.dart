import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../screens/voice_log_screen.dart';
import '../screens/add_member_screen.dart';
import '../screens/staff_screen.dart';
import '../screens/unpaid_payments_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class CategoryRow extends StatelessWidget {
  final VoidCallback? onReturn;
  const CategoryRow({Key? key, this.onReturn}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final categories = [
      {'label': 'Add Member', 'icon': Icons.person_add_rounded, 'screen': AddMemberScreen()},
      {'label': 'Staff', 'icon': Icons.badge_rounded, 'screen': const StaffScreen()},
      {'label': 'Collect', 'icon': Icons.diamond_rounded, 'screen': UnpaidPaymentsScreen()},
      {'label': 'Ask AI', 'icon': Icons.auto_awesome_rounded, 'screen': const VoiceLogScreen()},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: categories.map((category) {
          final icon = category['icon'] as IconData;
          final label = category['label'] as String;
          final screen = category['screen'] as Widget;
          return GestureDetector(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => screen),
              );
              onReturn?.call();
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.03),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Center(
                    child: Icon(icon, color: Colors.white, size: 24),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  label.toUpperCase(),
                  style: GoogleFonts.outfit(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
