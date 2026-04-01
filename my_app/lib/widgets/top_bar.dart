import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../main.dart';

class TopBar extends StatelessWidget {
  final String? name;
  
  const TopBar({Key? key, this.name}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final displayName = name ?? (globalOwnerName.isNotEmpty ? globalOwnerName : 'Alex');
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Good Morning, $displayName 👋',
            style: TextStyle(
              color: AppColors.primaryText,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
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
    );
  }
}
