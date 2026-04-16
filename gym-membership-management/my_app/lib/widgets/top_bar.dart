import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/auth_service.dart';
import '../screens/login_screen.dart';
import 'api_server_dialog.dart';

class TopBar extends StatelessWidget {
  final String? name;
  
  const TopBar({Key? key, this.name}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final displayName = name ?? 'Owner';
    
    final hour = DateTime.now().hour;
    String greeting = 'Good Morning';
    if (hour >= 12 && hour < 17) {
      greeting = 'Good Afternoon';
    } else if (hour >= 17 || hour < 5) {
      greeting = 'Good Evening';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$greeting, $displayName 👋',
            style: TextStyle(
              color: AppColors.primaryText,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'API server',
                onPressed: () => showApiServerDialog(context),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.cardBackground,
                  foregroundColor: AppColors.primaryText,
                ),
                icon: Icon(Icons.dns, size: 22),
              ),
              SizedBox(width: 8),
              IconButton(
                tooltip: 'Sign Out',
                onPressed: () async {
                  await AuthService.signOut();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                },
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.cardBackground,
                  foregroundColor: Colors.redAccent,
                ),
                icon: Icon(Icons.logout, size: 22),
              ),
              SizedBox(width: 8),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.notifications_none,
                  color: AppColors.primaryText,
                  size: 24,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
