import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../services/api_exception.dart';

class LogbookScanScreen extends StatefulWidget {
  @override
  _LogbookScanScreenState createState() => _LogbookScanScreenState();
}

class _LogbookScanScreenState extends State<LogbookScanScreen> {
  File? _image;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  List<dynamic> _extractedEntries = [];

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _image = File(pickedFile.path);
          _extractedEntries = [];
        });
      }
    } catch (e) {
      _showError("Failed to pick image: $e");
    }
  }

  Future<void> _processImage() async {
    if (_image == null) return;

    setState(() => _isLoading = true);
    try {
      final bytes = await _image!.readAsBytes();
      final base64String = base64Encode(bytes);
      
      final results = await ApiService.extractLogbook(base64String, 'image/jpeg');
      
      setState(() {
        _extractedEntries = results;
        _isLoading = false;
      });

      if (_extractedEntries.isEmpty) {
        _showInfo("No workout entries recognized. Try a clearer photo.");
      }
    } on ApiException catch (e) {
      _showError(e.message);
      setState(() => _isLoading = false);
    } catch (e) {
      _showError("An unexpected error occurred: $e");
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.blueAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Color(0xFF121212),
      appBar: AppBar(
        title: Text("Workout Log Scanner", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading 
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: theme.primaryColor),
                  SizedBox(height: 20),
                  Text(
                    "Analysing your logbook... this may take up to 30 seconds",
                    style: TextStyle(color: Colors.grey[400], fontSize: 13),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: _image == null 
                      ? _buildEmptyState() 
                      : _extractedEntries.isEmpty 
                          ? _buildImagePreview() 
                          : _buildResultsList(),
                ),
                _buildActionPanel(),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.description_outlined, size: 80, color: Colors.grey[700]),
          SizedBox(height: 20),
          Text(
            "Scan your handwritten logbook",
            style: TextStyle(color: Colors.white70, fontSize: 18),
          ),
          SizedBox(height: 10),
          Text(
            "Upload a photo to digitize your workout",
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      margin: EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        image: DecorationImage(image: FileImage(_image!), fit: BoxFit.cover),
        boxShadow: [
          BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 5)),
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    return ListView.builder(
      padding: EdgeInsets.all(15),
      itemCount: _extractedEntries.length,
      itemBuilder: (context, index) {
        final entry = _extractedEntries[index] as Map<String, dynamic>;
        return Card(
          color: Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          margin: EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      entry['exercise'] ?? "Unknown Exercise",
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    if (entry['date'] != null)
                      Text(
                        entry['date'],
                        style: TextStyle(color: Colors.blueAccent, fontSize: 14),
                      ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    _buildStatChip("${entry['sets'] ?? '--'} Sets"),
                    SizedBox(width: 10),
                    _buildStatChip("${entry['reps'] ?? '--'} Reps"),
                    SizedBox(width: 10),
                    if (entry['weight_kg'] != null)
                      _buildStatChip("${entry['weight_kg']} kg"),
                  ],
                ),
                if (entry['notes'] != null && entry['notes'].isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(
                      "Note: ${entry['notes']}",
                      style: TextStyle(color: Colors.grey[400], fontSize: 13, fontStyle: FontStyle.italic),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatChip(String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
      ),
      child: Text(label, style: TextStyle(color: Colors.blueAccent, fontSize: 12)),
    );
  }

  Widget _buildActionPanel() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_image != null && _extractedEntries.isEmpty)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _processImage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: Text("Extract Workout Data", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            if (_extractedEntries.isNotEmpty)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() { _image = null; _extractedEntries = []; }),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        side: BorderSide(color: Colors.grey),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      child: Text("Clear", style: TextStyle(color: Colors.grey)),
                    ),
                  ),
                  SizedBox(width: 15),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent[700],
                        padding: EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      child: Text("Save to Log", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            if (_image == null)
              Row(
                children: [
                  Expanded(
                    child: _buildIconButton(Icons.camera_alt, "Camera", () => _pickImage(ImageSource.camera)),
                  ),
                  SizedBox(width: 15),
                  Expanded(
                    child: _buildIconButton(Icons.photo_library, "Gallery", () => _pickImage(ImageSource.gallery)),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton(IconData icon, String label, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white),
      label: Text(label, style: TextStyle(color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey[800],
        padding: EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }
}
