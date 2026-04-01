import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class PaymentsScreen extends StatelessWidget {
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
        title: Text("Payments & Revenue", style: TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 10),
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.cardBackground, AppColors.cardBackground.withOpacity(0.5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: AppColors.border, width: 1),
                borderRadius: BorderRadius.circular(16),
              ),
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Total Revenue (This Month)", style: TextStyle(color: AppColors.secondaryText, fontSize: 14)),
                  SizedBox(height: 8),
                  Text("\$4,250.00", style: TextStyle(color: AppColors.accent, fontSize: 36, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            SizedBox(height: 30),
            Text("Action Required", style: TextStyle(color: Colors.redAccent, fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            _buildOverdueCard('Mike Davis', 'Pending Dues: \$50.00'),
            SizedBox(height: 30),
            Text("Recent Transactions", style: TextStyle(color: AppColors.primaryText, fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  _buildTransaction('Alex Johnson', 'Membership Renew', '+ \$50.00', true),
                  _buildTransaction('Sarah Smith', 'Personal Training', '+ \$120.00', true),
                  _buildTransaction('Hardware Store', 'Equipment Maint', '- \$250.00', false),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildOverdueCard(String name, String details) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.bold, fontSize: 16)),
              SizedBox(height: 4),
              Text(details, style: TextStyle(color: Colors.redAccent, fontSize: 14)),
            ],
          ),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent.withOpacity(0.2),
              foregroundColor: Colors.redAccent,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: Text("Send Reminder"),
          ),
        ],
      ),
    );
  }

  Widget _buildTransaction(String title, String subtitle, String amount, bool isIncome) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isIncome ? AppColors.accent.withOpacity(0.1) : Colors.redAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                  color: isIncome ? AppColors.accent : Colors.redAccent,
                  size: 20,
                ),
              ),
              SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.w600, fontSize: 16)),
                  SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: AppColors.secondaryText, fontSize: 13)),
                ],
              ),
            ],
          ),
          Text(
            amount,
            style: TextStyle(
              color: isIncome ? AppColors.accent : Colors.redAccent,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
