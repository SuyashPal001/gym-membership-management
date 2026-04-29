import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class ScanBookScreen extends StatefulWidget {
  @override
  _ScanBookScreenState createState() => _ScanBookScreenState();
}

class _ScanBookScreenState extends State<ScanBookScreen> {
  bool _isScanning = false;
  bool _scanComplete = false;

  void _startScan() {
    setState(() {
      _isScanning = true;
    });
    
    // Simulate AI processing time
    Future.delayed(Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _scanComplete = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Dark camera UI
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("AI Notebook Digitizer", style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: _scanComplete ? _buildResultsView() : _buildCameraScanner(),
    );
  }

  Widget _buildCameraScanner() {
    return Stack(
      children: [
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.library_books, color: Colors.white24, size: 100),
              SizedBox(height: 20),
              if (_isScanning)
                CircularProgressIndicator(color: AppColors.accent)
              else
                Text(
                  "Align handwritten notebook entry",
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
            ],
          ),
        ),
        // Frame Guide
        Center(
          child: Container(
            height: 350,
            width: 300,
            decoration: BoxDecoration(
              border: Border.all(color: _isScanning ? AppColors.accent : Colors.white30, width: 3),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        // Capture Button
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 50.0),
            child: GestureDetector(
              onTap: _isScanning ? null : _startScan,
              child: Container(
                height: 80,
                width: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _isScanning ? AppColors.accent : Colors.white, width: 4),
                  color: Colors.white30,
                ),
                child: Center(
                  child: Container(
                    height: 60,
                    width: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isScanning ? AppColors.accent : Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultsView() {
    return Container(
      color: AppColors.background,
      width: double.infinity,
      height: double.infinity,
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: AppColors.accent, size: 28),
              SizedBox(width: 12),
              Text(
                "Scan Complete",
                style: TextStyle(color: AppColors.primaryText, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text("AI parsed 2 handwritten entries.", style: TextStyle(color: AppColors.secondaryText, fontSize: 16)),
          SizedBox(height: 30),
          
          _buildScannedEntry("Mike Davis", "Checked In at 9:00 AM", Icons.directions_run),
          SizedBox(height: 16),
          _buildScannedEntry("Alex Johnson", "Paid \$50 Cash", Icons.attach_money, isRevenue: true),
          
          Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text("Log All to Dashboard", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildScannedEntry(String title, String subtitle, IconData icon, {bool isRevenue = false}) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: isRevenue ? AppColors.accent.withOpacity(0.2) : Colors.blueAccent.withOpacity(0.2),
                child: Icon(icon, color: isRevenue ? AppColors.accent : Colors.blueAccent),
              ),
              SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.bold, fontSize: 16)),
                  SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: AppColors.secondaryText, fontSize: 14)),
                ],
              ),
            ],
          ),
          OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: Text("Verify", style: TextStyle(color: AppColors.primaryText)),
          ),
        ],
      ),
    );
  }
}
