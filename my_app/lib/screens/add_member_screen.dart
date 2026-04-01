import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AddMemberScreen extends StatefulWidget {
  @override
  _AddMemberScreenState createState() => _AddMemberScreenState();
}

class _AddMemberScreenState extends State<AddMemberScreen> {
  String _selectedPlan = '1-Month Premium (\$50)';
  bool _isTrial = false;
  bool _paymentCollected = true;

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
        title: Text("Member Enrollment", style: TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.cardBackground,
                    child: Icon(Icons.person, size: 40, color: AppColors.secondaryText),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.camera_alt, size: 16, color: Colors.white),
                    ),
                  )
                ],
              ),
            ),
            SizedBox(height: 30),
            Text("Personal Details", style: TextStyle(color: AppColors.secondaryText, fontSize: 14)),
            SizedBox(height: 12),
            _buildTextField("Full Name", Icons.person_outline),
            SizedBox(height: 16),
            _buildTextField("Phone Number", Icons.phone_outlined),
            
            SizedBox(height: 30),
            Text("Membership Plan", style: TextStyle(color: AppColors.secondaryText, fontSize: 14)),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedPlan,
                  dropdownColor: AppColors.cardBackground,
                  icon: Icon(Icons.arrow_drop_down, color: AppColors.secondaryText),
                  isExpanded: true,
                  style: TextStyle(color: AppColors.primaryText, fontSize: 16),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedPlan = newValue!;
                    });
                  },
                  items: <String>['1-Month Premium (\$50)', '3-Month Bundle (\$130)', 'Annual VIP (\$400)']
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                ),
              ),
            ),
            
            SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _isTrial ? AppColors.accent : Colors.transparent),
              ),
              child: SwitchListTile(
                activeColor: AppColors.accent,
                title: Text("Free Trial Period", style: TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.bold)),
                subtitle: Text("7 days access. No payment required now.", style: TextStyle(color: AppColors.secondaryText, fontSize: 12)),
                value: _isTrial,
                onChanged: (bool value) {
                  setState(() {
                    _isTrial = value;
                    if (_isTrial) _paymentCollected = false; // Cannot collect payment on free trial
                  });
                },
              ),
            ),

            if (!_isTrial) ...[
              SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SwitchListTile(
                  activeColor: AppColors.accent,
                  title: Text("Initial Payment Collected", style: TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.bold)),
                  subtitle: Text(_paymentCollected ? "Logged as revenue." : "Will show in pending dues.", style: TextStyle(color: AppColors.secondaryText, fontSize: 12)),
                  value: _paymentCollected,
                  onChanged: (bool value) {
                    setState(() {
                      _paymentCollected = value;
                    });
                  },
                ),
              ),
            ],

            SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _isTrial ? "Start Free Trial" : "Enroll Member",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String hint, IconData icon) {
    return TextField(
      style: TextStyle(color: AppColors.primaryText),
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.cardBackground,
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.secondaryText),
        prefixIcon: Icon(icon, color: AppColors.secondaryText),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.accent, width: 2),
        ),
      ),
    );
  }
}
