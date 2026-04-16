import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/app_colors.dart';
import '../services/api_service.dart';
import '../services/api_exception.dart';

class ScanBookScreen extends StatefulWidget {
  @override
  _ScanBookScreenState createState() => _ScanBookScreenState();
}

class _ScanBookScreenState extends State<ScanBookScreen> {
  bool _isLoading = false;
  bool _isConfirming = false;
  List<dynamic>? _entries;
  String? _scanId;
  String? _error;
  bool _isParseFailed = false;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickAndScan(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 70,
      );

      if (image == null) return;

      setState(() {
        _isLoading = true;
        _error = null;
        _entries = null;
        _scanId = null;
        _isParseFailed = false;
      });

      final bytes = await image.readAsBytes();
      final base64 = base64Encode(bytes);

      final response = await ApiService.scanLedger(base64);

      setState(() {
        _scanId = response['scan_id'];
        _entries = (response['entries'] as List).map((e) {
          final entry = Map<String, dynamic>.from(e);
          
          // Auto-selection logic
          if (entry['requires_manual_selection'] == false) {
            final matches = entry['matches'] as List;
            if (matches.isNotEmpty && matches[0]['confidence'] >= 85) {
              entry['selected_member_id'] = matches[0]['id'];
            }
          }
          return entry;
        }).toList();
        _isLoading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _isLoading = false;
        if (e.message == 'PARSE_FAILED') {
          _isParseFailed = true;
        } else {
          _error = e.message;
        }
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmAll() async {
    if (_scanId == null || _entries == null) return;

    setState(() => _isConfirming = true);
    try {
      final response = await ApiService.confirmLedgerScan(_scanId!, _entries!.cast<Map<String, dynamic>>());
      
      setState(() => _isConfirming = false);
      
      if (!mounted) return;

      _showSummaryDialog(
        processed: response['processed'],
        skipped: response['skipped'],
        reasons: (response['skipped_reasons'] as List).cast<String>(),
      );
    } on ApiException catch (e) {
      setState(() => _isConfirming = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.redAccent),
      );
    }
  }

  void _showSummaryDialog({required int processed, required int skipped, required List<String> reasons}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text("Scan Complete", style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("✅ $processed entries saved", style: TextStyle(color: Colors.greenAccent)),
              Text("⚠️ $skipped entries skipped", style: TextStyle(color: Colors.orangeAccent)),
              if (reasons.isNotEmpty) ...[
                SizedBox(height: 15),
                Text("Skipped Reasons:", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ...reasons.map((r) => Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text("• $r", style: TextStyle(color: Colors.grey, fontSize: 12)),
                )),
              ]
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // close dialog
              Navigator.pop(context); // close screen
            },
            child: Text("Done", style: TextStyle(color: AppColors.accent)),
          )
        ],
      ),
    );
  }

  bool get _canConfirm {
    if (_entries == null) return false;
    return _entries!.every((e) => e['selected_member_id'] != null || e['action'] == 'skip');
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
      body: _isLoading || _isConfirming
        ? _buildLoading() 
        : (_isParseFailed ? _buildParseError() : (_entries != null ? _buildResults() : _buildIdle())),
    );
  }

  Widget _buildParseError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image_outlined, color: Colors.redAccent, size: 80),
          SizedBox(height: 24),
          Text(
            "Poor image quality",
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              "Please retake the photo in better lighting with the ledger flat.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
          SizedBox(height: 40),
          _buildPrimaryButton(
            label: "Retake Photo",
            onPressed: () => setState(() => _isParseFailed = false),
          ),
        ],
      ),
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
              "Process your attendance ledger. AI will extract names and payments automatically.",
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
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.camera_alt,
                    label: "Camera",
                    onPress: () => _pickAndScan(ImageSource.camera),
                  ),
                ),
                SizedBox(width: 15),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.photo_library,
                    label: "Gallery",
                    onPress: () => _pickAndScan(ImageSource.gallery),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, required VoidCallback onPress}) {
    return ElevatedButton(
      onPressed: onPress,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.cardBackground,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.border),
        ),
        elevation: 5,
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.accent, size: 32),
          SizedBox(height: 12),
          Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
          Text(
            _isConfirming ? "Saving records..." : "Gemini is reading ledger...", 
            style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600)
          ),
          SizedBox(height: 8),
          Text(
            _isConfirming ? "Finalizing transaction..." : "Analysing your ledger... this may take up to 30 seconds", 
            style: TextStyle(color: AppColors.secondaryText, fontSize: 12)
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Review Extracted Data",
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                "${_entries!.length} Rows Found",
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _entries!.length,
            padding: EdgeInsets.symmetric(horizontal: 16),
            itemBuilder: (context, index) {
              return _buildEntryCard(index);
            },
          ),
        ),
        _buildFooter(),
      ],
    );
  }

  Widget _buildEntryCard(int index) {
    final entry = _entries![index];
    final matches = entry['matches'] as List;
    final isSkipped = entry['action'] == 'skip';

    return Card(
      color: isSkipped ? Colors.grey[900]?.withOpacity(0.5) : AppColors.cardBackground,
      margin: EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(
          color: entry['requires_manual_selection'] == true && !isSkipped && entry['selected_member_id'] == null
              ? Colors.orangeAccent
              : AppColors.border,
          width: 2,
        ),
      ),
      child: Opacity(
        opacity: isSkipped ? 0.5 : 1.0,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("AI READ:", style: TextStyle(color: Colors.grey, fontSize: 10, letterSpacing: 1.2)),
                        Text(entry['ai_read_name'], style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _entries![index] = Map<String, dynamic>.from(entry)
                        ..['action'] = isSkipped ? null : 'skip';
                    }),
                    icon: Icon(isSkipped ? Icons.restore : Icons.block, size: 16, color: isSkipped ? Colors.greenAccent : Colors.redAccent),
                    label: Text(isSkipped ? "Restore" : "Skip", style: TextStyle(color: isSkipped ? Colors.greenAccent : Colors.redAccent, fontSize: 12)),
                  ),
                ],
              ),
              if (!isSkipped) ...[
                Divider(color: AppColors.border, height: 24),
                
                Text("LINK TO MEMBER:", style: TextStyle(color: Colors.grey, fontSize: 10, letterSpacing: 1.2)),
                SizedBox(height: 8),
                if (matches.isEmpty)
                  Text("No matches found in database", style: TextStyle(color: Colors.redAccent, fontSize: 13))
                else
                  ...matches.map((m) => _buildMemberMatchTile(index, m)),
                
                if (entry['requires_manual_selection'] == true && entry['selected_member_id'] == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 16),
                        SizedBox(width: 8),
                        Text("Duplicate names found. Please pick correct member.", style: TextStyle(color: Colors.orangeAccent, fontSize: 11)),
                      ],
                    ),
                  ),

                Divider(color: AppColors.border, height: 24),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildEntryToggle(
                      label: "Attended",
                      value: entry['attended'] == true,
                      onChanged: (val) => setState(() {
                        _entries![index] = Map<String, dynamic>.from(entry)
                          ..['attended'] = val;
                      }),
                    ),
                    _buildEntryToggle(
                      label: "Trial",
                      value: entry['is_trial'] == true,
                      onChanged: (val) => setState(() {
                        _entries![index] = Map<String, dynamic>.from(entry)
                          ..['is_trial'] = val;
                      }),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildReadOnlyField("Amount", "₹${entry['amount'] ?? 0}"),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: _buildReadOnlyField("Payment", (entry['payment_status'] ?? 'pending').toString().toUpperCase()),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: _buildReadOnlyField("Method", (entry['payment_method'] ?? 'cash').toString().toUpperCase()),
                    ),
                  ],
                ),
                if (entry['notes'] != null && entry['notes'].toString().trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: _buildReadOnlyField("Notes", entry['notes']),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMemberMatchTile(int entryIndex, Map<String, dynamic> match) {
    final entry = _entries![entryIndex];
    final isSelected = entry['selected_member_id'] == match['id'];
    
    // Partially mask phone: 987xx xxxxx
    String phone = match['phone'] ?? 'No Phone';
    if (phone.length >= 5) {
      phone = phone.substring(0, 3) + "xx xxxxx";
    }

    return GestureDetector(
      onTap: () => setState(() {
        _entries![entryIndex] = Map<String, dynamic>.from(entry)
          ..['selected_member_id'] = match['id'];
      }),
      child: Container(
        margin: EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent.withOpacity(0.15) : Colors.black26,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? AppColors.accent : Colors.transparent, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(isSelected ? Icons.check_circle : Icons.circle_outlined, color: isSelected ? AppColors.accent : Colors.grey, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(match['name'], style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      Text("${match['confidence']}% Match", style: TextStyle(color: isSelected ? AppColors.accent : Colors.grey, fontSize: 10)),
                    ],
                  ),
                  Text("$phone • Joined ${match['join_date'] ?? 'n/a'}", style: TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryToggle({required String label, required bool value, required Function(bool) onChanged}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.scale(
          scale: 0.8,
          child: Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.accent,
          ),
        ),
        Text(label, style: TextStyle(color: Colors.white70, fontSize: 13)),
      ],
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: TextStyle(color: Colors.grey, fontSize: 9, letterSpacing: 1.0)),
        SizedBox(height: 4),
        Text(value, style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 10)],
      ),
      child: SafeArea(
        top: false,
        child: _buildPrimaryButton(
          label: "Confirm All Records",
          onPressed: _canConfirm ? _confirmAll : null,
          color: _canConfirm ? Colors.greenAccent[700] : Colors.grey,
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({required String label, required VoidCallback? onPressed, Color? color}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? AppColors.accent,
          padding: EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          disabledBackgroundColor: Colors.grey[800],
        ),
        child: Text(label, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }
}
