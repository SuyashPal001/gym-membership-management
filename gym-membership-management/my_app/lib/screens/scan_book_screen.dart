import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/app_colors.dart';
import '../services/api_service.dart';

class ScanBookScreen extends StatefulWidget {
  @override
  _ScanBookScreenState createState() => _ScanBookScreenState();
}

class _ScanBookScreenState extends State<ScanBookScreen> {
  bool _isLoading = false;
  List<dynamic>? _results;
  String? _error;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickAndScan() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (image == null) return;

      setState(() {
        _isLoading = true;
        _error = null;
        _results = null;
      });

      final bytes = await image.readAsBytes();
      final base64 = base64Encode(bytes);

      final data = await ApiService.scanLedger(base64);

      setState(() {
        _results = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: AppColors.primaryText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("AI Ledger Scan", style: TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading 
        ? _buildLoading() 
        : (_results != null ? _buildResults() : _buildIdle()),
    );
  }

  Widget _buildIdle() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_awesome, color: AppColors.accent, size: 80),
          SizedBox(height: 24),
          Text(
            "Digitize Handwriting",
            style: TextStyle(color: AppColors.primaryText, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              "Upload a photo of your attendance ledger. AI will extract names and payments automatically.",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.secondaryText, fontSize: 14),
            ),
          ),
          SizedBox(height: 40),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(_error!, style: TextStyle(color: Colors.redAccent, fontSize: 12), textAlign: TextAlign.center),
            ),
          ElevatedButton.icon(
            onPressed: _pickAndScan,
            icon: Icon(Icons.camera_alt, color: Colors.white),
            label: Text("Select Ledger Image", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.accent),
          SizedBox(height: 24),
          Text("Gemini is reading ledger...", style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600)),
          SizedBox(height: 8),
          Text("This takes about 5 seconds", style: TextStyle(color: AppColors.secondaryText, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildResults() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 12),
              Text(
                "Extracted Data",
                style: TextStyle(color: AppColors.primaryText, fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _results!.length,
            padding: EdgeInsets.symmetric(horizontal: 20),
            itemBuilder: (context, index) {
              final item = _results![index];
              return Container(
                margin: EdgeInsets.only(bottom: 12),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.accent.withOpacity(0.1),
                      child: Text("${index + 1}", style: TextStyle(color: AppColors.accent)),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item['name'] ?? 'Unknown', style: TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.bold)),
                          Text("${item['phone'] ?? ''} • ${item['status'] ?? ''}", style: TextStyle(color: AppColors.secondaryText, fontSize: 12)),
                        ],
                      ),
                    ),
                    Text("₹${item['amount'] ?? '0'}", style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text("Done", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        )
      ],
    );
  }
}
