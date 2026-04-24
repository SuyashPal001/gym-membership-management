import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import '../constants/app_colors.dart';
import '../models/member.dart';
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
  List<Member> _allMembers = [];
  List<MembershipType> _plans = [];
  Map<int, Map<String, String>> _errors = {};

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

      final results = await Future.wait([
        ApiService.scanLedger(base64),
        ApiService.fetchMembers(),
        ApiService.fetchMembershipTypes(),
      ]);
      final response = results[0] as Map<String, dynamic>;
      final members = results[1] as List<Member>;
      final plans = results[2] as List<MembershipType>;

      setState(() {
        _allMembers = members;
        _plans = plans;
        _scanId = response['scan_id'];
        _entries = (response['entries'] as List).map((e) {
          final entry = Map<String, dynamic>.from(e);

          // Auto-select best match when there's no ambiguity
          if (entry['requires_manual_selection'] == false) {
            final matches = entry['matches'] as List;
            if (matches.isNotEmpty) {
              entry['selected_member_id'] = matches[0]['id'];
            } else {
              entry['action'] = 'new_member';
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

  // Re-run client-side name search when user corrects an AI-read name
  void _rematch(int index, String newName) {
    if (_allMembers.isEmpty) return;
    final query = newName.trim().toLowerCase();
    final scored = _allMembers
        .map((m) {
          final mName = m.memberName.toLowerCase();
          int score = 0;
          if (mName == query) score = 100;
          else if (mName.startsWith(query)) score = 85;
          else if (mName.contains(query)) score = 70;
          else if (query.isNotEmpty && query.split('').every((c) => mName.contains(c))) score = 50;
          return (member: m, score: score);
        })
        .where((r) => r.score > 0)
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    final matches = scored.take(3).map((r) => {
      'id': r.member.id,
      'name': r.member.memberName,
      'phone': r.member.phone,
      'confidence': r.score,
      'join_date': r.member.joinDate,
    }).toList();

    setState(() {
      final entry = Map<String, dynamic>.from(_entries![index]);
      entry['ai_read_name'] = newName;
      entry['matches'] = matches;
      entry['requires_manual_selection'] = false;
      if (matches.isNotEmpty) {
        entry['selected_member_id'] = matches[0]['id'];
        entry.remove('action');
      } else {
        entry.remove('selected_member_id');
        entry['action'] = 'new_member';
      }
      _entries![index] = entry;
    });
  }

  bool _validate() {
    final newErrors = <int, Map<String, String>>{};
    for (int i = 0; i < _entries!.length; i++) {
      final entry = _entries![i];
      if (entry['action'] == 'skip') continue;
      final entryErrors = <String, String>{};

      final name = (entry['ai_read_name'] ?? '').toString().trim();
      if (name.isEmpty) {
        entryErrors['name'] = 'Name is required';
      } else if (name.length < 2) {
        entryErrors['name'] = 'Name is too short';
      }

      if (entry['action'] == 'new_member') {
        final digits = (entry['phone'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
        if (digits.isEmpty) {
          entryErrors['phone'] = 'Phone is required for new member';
        } else if (digits.length < 10) {
          entryErrors['phone'] = 'Enter a valid 10-digit number';
        }
        final isTrial = entry['is_trial'] == true;
        final hasPlan = entry['membership_type_id'] != null;
        if (!isTrial && !hasPlan) {
          entryErrors['plan'] = 'Select a plan or mark as trial';
        }
      }

      final rawAmount = entry['amount'];
      if (rawAmount != null && rawAmount is! num) {
        entryErrors['amount'] = 'Enter a valid amount';
      } else if (rawAmount != null && (rawAmount as num) < 0) {
        entryErrors['amount'] = 'Amount cannot be negative';
      }

      if (entryErrors.isNotEmpty) newErrors[i] = entryErrors;
    }
    setState(() => _errors = newErrors);
    return newErrors.isEmpty;
  }

  void _clearError(int index, String field) {
    if (_errors[index]?[field] == null) return;
    setState(() {
      final updated = Map<String, String>.from(_errors[index]!);
      updated.remove(field);
      _errors = Map.from(_errors)..[index] = updated;
    });
  }

  void _showSnackbar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info_outline, color: color, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                msg,
                style: TextStyle(
                  color: AppColors.primaryText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.cardBackground,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.border),
        ),
        margin: EdgeInsets.all(20),
        duration: Duration(seconds: 3),
      ),
    );
  }

  Future<void> _confirmAll() async {
    if (_scanId == null || _entries == null) return;
    if (!_validate()) {
      _showSnackbar('Fix the highlighted errors before confirming', AppColors.error);
      return;
    }
    setState(() => _isConfirming = true);
    try {
      final response = await ApiService.confirmLedgerScan(_scanId!, _entries!.cast<Map<String, dynamic>>());

      if (!mounted) return;

      final int processed = response['processed'];
      final int skipped = response['skipped'];
      final String msg = processed > 0
          ? '$processed saved${skipped > 0 ? ', $skipped skipped' : ''}'
          : 'No entries saved — $skipped skipped';

      setState(() {
        _isConfirming = false;
        _entries = null;
        _scanId = null;
        _error = null;
        _isParseFailed = false;
      });

      _showSnackbar(msg, processed > 0 ? AppColors.success : AppColors.warning);
    } on ApiException catch (e) {
      setState(() => _isConfirming = false);
      _showSnackbar(e.message, AppColors.error);
    } catch (e) {
      setState(() => _isConfirming = false);
      _showSnackbar('Something went wrong. Please try again.', AppColors.error);
    }
  }

  bool get _canConfirm => _entries != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: (_entries != null || _isParseFailed)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
                onPressed: () => setState(() {
                  _entries = null;
                  _scanId = null;
                  _error = null;
                  _isParseFailed = false;
                }),
              )
            : null,
        title: const Text("AI LEDGER SCAN", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.white)),
        centerTitle: true,
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 80),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
          Icon(Icons.auto_awesome, color: Colors.orangeAccent, size: 64),
          SizedBox(height: 32),
          Text(
            "DIGITIZE HANDWRITING",
            style: TextStyle(color: AppColors.primaryText, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1.5),
          ),
          SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              "Process your attendance ledger. AI will extract names and payments automatically.",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.secondaryText, fontSize: 16, height: 1.6),
            ),
          ),
          SizedBox(height: 48),
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
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, required VoidCallback onPress}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Material(
        color: AppColors.cardBackground,
        child: InkWell(
          onTap: onPress,
          splashColor: Colors.orangeAccent.withOpacity(0.25),
          highlightColor: Colors.orangeAccent.withOpacity(0.08),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 1.0),
            ),
            child: Column(
              children: [
                Icon(icon, color: Colors.orangeAccent, size: 28),
                SizedBox(height: 10),
                Text(
                  label.toUpperCase(),
                  style: TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1.0),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            'assets/animations/loader.json',
            width: 200,
            height: 200,
            delegates: LottieDelegates(
              values: [
                ValueDelegate.colorFilter(
                  ['**'],
                  value: ColorFilter.mode(AppColors.primaryBlue, BlendMode.modulate),
                ),
              ],
            ),
          ),
          SizedBox(height: 24),
          Text(
            _isConfirming ? "Saving records..." : "Flexy is reading ledger...", 
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
                "REVIEW EXTRACTED DATA",
                style: TextStyle(color: AppColors.primaryText, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.2),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
                ),
                child: Text(
                  "${_entries!.length} ROWS",
                  style: TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                ),
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

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isSkipped ? Colors.grey[900]?.withOpacity(0.5) : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: entry['requires_manual_selection'] == true && !isSkipped && entry['selected_member_id'] == null
              ? AppColors.warning
              : AppColors.border.withOpacity(0.3),
          width: 1,
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
                        Row(
                          children: [
                            Text("AI READ:", style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.w900)),
                            SizedBox(width: 6),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.edit_rounded, color: Colors.white54, size: 9),
                                  SizedBox(width: 3),
                                  Text("EDITABLE", style: TextStyle(color: Colors.white54, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        TextFormField(
                          initialValue: entry['ai_read_name'],
                          style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                            border: InputBorder.none,
                            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: _errors[index]?['name'] != null ? Colors.redAccent : Colors.white24, width: 1)),
                            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _errors[index]?['name'] != null ? Colors.redAccent : Colors.white60, width: 1.5)),
                          ),
                          onChanged: (val) {
                            entry['ai_read_name'] = val;
                            _clearError(index, 'name');
                          },
                          onEditingComplete: () {
                            _rematch(index, entry['ai_read_name']?.toString() ?? '');
                            FocusScope.of(context).unfocus();
                          },
                        ),
                        if (_errors[index]?['name'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(_errors[index]!['name']!, style: const TextStyle(color: Colors.redAccent, fontSize: 11)),
                          ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _entries![index] = Map<String, dynamic>.from(entry)
                        ..['action'] = isSkipped ? null : 'skip';
                    }),
                    icon: Icon(isSkipped ? Icons.restore : Icons.block, size: 16, color: isSkipped ? AppColors.success : AppColors.error),
                    label: Text(isSkipped ? "Restore" : "Skip", style: TextStyle(color: isSkipped ? AppColors.success : AppColors.error, fontSize: 12, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
              if (!isSkipped) ...[
                Divider(color: AppColors.border.withOpacity(0.3), height: 24),
                
                _buildMemberLinkSection(index, entry, matches),

                Divider(color: AppColors.border, height: 24),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildEntryToggle(
                      label: "Attended",
                      value: entry['attended'] == true,
                      activeColor: AppColors.success,
                      onChanged: (val) => setState(() {
                        _entries![index] = Map<String, dynamic>.from(entry)
                          ..['attended'] = val;
                      }),
                    ),
                    _buildEntryToggle(
                      label: "Trial",
                      value: entry['is_trial'] == true,
                      activeColor: AppColors.infoBlue,
                      onChanged: (val) => setState(() {
                        _entries![index] = Map<String, dynamic>.from(entry)
                          ..['is_trial'] = val;
                      }),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(
                      width: 120,
                      child: _buildEditableAmount(index),
                    ),
                    _buildToggleField(
                      label: "Payment",
                      value: (entry['payment_status'] ?? 'pending').toString().toUpperCase(),
                      options: ["PAID", "PENDING"],
                      onToggle: () => setState(() {
                        final current = entry['payment_status'] ?? 'pending';
                        _entries![index] = Map<String, dynamic>.from(entry)
                          ..['payment_status'] = current == 'paid' ? 'pending' : 'paid';
                      }),
                    ),
                    _buildToggleField(
                      label: "Method",
                      value: (entry['payment_method'] ?? 'cash').toString().toUpperCase(),
                      options: ["CASH", "UPI"],
                      onToggle: () => setState(() {
                        final current = entry['payment_method'] ?? 'cash';
                        _entries![index] = Map<String, dynamic>.from(entry)
                          ..['payment_method'] = current == 'cash' ? 'upi' : 'cash';
                      }),
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

  Widget _buildMemberLinkSection(int index, Map<dynamic, dynamic> entry, List matches) {
    final isNewMember = entry['action'] == 'new_member';

    if (isNewMember) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_add_rounded, color: Colors.white54, size: 11),
                    const SizedBox(width: 4),
                    Text("NEW MEMBER", style: TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                  ],
                ),
              ),
              const Spacer(),
              if (matches.isNotEmpty)
                GestureDetector(
                  onTap: () => setState(() {
                    final e = Map<String, dynamic>.from(_entries![index]);
                    e.remove('action');
                    e['selected_member_id'] = matches[0]['id'];
                    _entries![index] = e;
                  }),
                  child: Text("Link to existing", style: TextStyle(color: Colors.white38, fontSize: 11, decoration: TextDecoration.underline, decorationColor: Colors.white38)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Phone field
          Row(
            children: [
              Text("MOBILE NO.", style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9, letterSpacing: 1.0, fontWeight: FontWeight.w900)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                child: Text("REQUIRED", style: TextStyle(color: Colors.redAccent.withOpacity(0.8), fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextFormField(
            initialValue: entry['phone']?.toString() ?? '',
            keyboardType: TextInputType.phone,
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              isDense: true,
              hintText: '+91XXXXXXXXXX',
              hintStyle: TextStyle(color: Colors.white24, fontSize: 13),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: _errors[index]?['phone'] != null ? Colors.redAccent : Colors.white24, width: 1)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _errors[index]?['phone'] != null ? Colors.redAccent : Colors.white60, width: 1.5)),
            ),
            onChanged: (val) {
              entry['phone'] = val.trim();
              _clearError(index, 'phone');
            },
          ),
          if (_errors[index]?['phone'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(_errors[index]!['phone']!, style: const TextStyle(color: Colors.redAccent, fontSize: 11)),
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text("PLAN", style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9, letterSpacing: 1.0, fontWeight: FontWeight.w900)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: _errors[index]?['plan'] != null ? Colors.redAccent.withOpacity(0.15) : Colors.redAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text("REQUIRED", style: TextStyle(color: Colors.redAccent.withOpacity(0.8), fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              // Trial chip
              _buildPlanChip(
                label: "TRIAL",
                isSelected: entry['is_trial'] == true,
                onTap: () => setState(() {
                  final e = Map<String, dynamic>.from(_entries![index]);
                  e['is_trial'] = !(e['is_trial'] == true);
                  e.remove('membership_type_id');
                  _entries![index] = e;
                  _clearError(index, 'plan');
                }),
              ),
              ..._plans.map((plan) => _buildPlanChip(
                label: "${plan.name} · ₹${plan.amount.toInt()}",
                isSelected: entry['membership_type_id'] == plan.id,
                onTap: () => setState(() {
                  final e = Map<String, dynamic>.from(_entries![index]);
                  e['membership_type_id'] = e['membership_type_id'] == plan.id ? null : plan.id;
                  e['is_trial'] = false;
                  _entries![index] = e;
                  _clearError(index, 'plan');
                }),
              )),
            ],
          ),
          if (_errors[index]?['plan'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(_errors[index]!['plan']!, style: const TextStyle(color: Colors.redAccent, fontSize: 11)),
            ),
        ],
      );
    }

    // Existing member mode
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("LINK TO MEMBER:", style: TextStyle(color: Colors.grey, fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        ...matches.map((m) => _buildMemberMatchTile(index, m as Map<String, dynamic>)),
        if (entry['requires_manual_selection'] == true && entry['selected_member_id'] == null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 14),
                const SizedBox(width: 6),
                Text("Duplicate names — pick the correct one", style: TextStyle(color: AppColors.warning, fontSize: 11)),
              ],
            ),
          ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => setState(() {
            final e = Map<String, dynamic>.from(_entries![index]);
            e['action'] = 'new_member';
            e.remove('selected_member_id');
            _entries![index] = e;
          }),
          child: Text("Enroll as new member instead", style: TextStyle(color: Colors.white38, fontSize: 11, decoration: TextDecoration.underline, decorationColor: Colors.white38)),
        ),
      ],
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
        final currentSelection = entry['selected_member_id'];
        _entries![entryIndex] = Map<String, dynamic>.from(entry)
          ..['selected_member_id'] = (currentSelection == match['id']) ? null : match['id'];
      }),
      child: Container(
        margin: EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryBlue.withOpacity(0.12) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primaryBlue.withOpacity(0.5) : Colors.white.withOpacity(0.08), 
            width: 1
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined, 
              color: isSelected ? AppColors.primaryBlue : Colors.white24, 
              size: 20
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        match['name'], 
                        style: TextStyle(
                          color: Colors.white, 
                          fontWeight: FontWeight.bold, 
                          fontSize: 14
                        )
                      ),
                      Text(
                        "${match['confidence']}% Match", 
                        style: TextStyle(
                          color: isSelected ? AppColors.primaryBlue : Colors.white38, 
                          fontSize: 10,
                          fontWeight: FontWeight.w900
                        )
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "$phone • Joined ${match['join_date'] ?? 'n/a'}", 
                    style: TextStyle(
                      color: Colors.white60, 
                      fontSize: 11
                    )
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanChip({required String label, required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.white54 : Colors.white12,
            width: isSelected ? 1.2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white38,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildEntryToggle({required String label, required bool value, required Color activeColor, required Function(bool) onChanged}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.scale(
          scale: 0.8,
          child: Switch(
            value: value,
            onChanged: onChanged,
            activeColor: activeColor,
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

  Widget _buildEditableAmount(int index) {
    final entry = _entries![index];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text("AMOUNT", style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9, letterSpacing: 1.0, fontWeight: FontWeight.w900)),
            SizedBox(width: 6),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_rounded, color: Colors.white54, size: 9),
                  SizedBox(width: 3),
                  Text("EDITABLE", style: TextStyle(color: Colors.white54, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 4),
        TextFormField(
          initialValue: entry['amount']?.toString() ?? '0',
          keyboardType: TextInputType.number,
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
          decoration: InputDecoration(
            isDense: true,
            prefixText: '₹ ',
            prefixStyle: TextStyle(color: Colors.white70, fontWeight: FontWeight.w900, fontSize: 14),
            contentPadding: EdgeInsets.symmetric(vertical: 10),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: _errors[index]?['amount'] != null ? Colors.redAccent : Colors.white24, width: 1)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _errors[index]?['amount'] != null ? Colors.redAccent : Colors.white60, width: 1.5)),
          ),
          onChanged: (val) {
            final parsed = double.tryParse(val);
            entry['amount'] = parsed ?? entry['amount'];
            if (parsed != null) _clearError(index, 'amount');
          },
        ),
        if (_errors[index]?['amount'] != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(_errors[index]!['amount']!, style: const TextStyle(color: Colors.redAccent, fontSize: 11)),
          ),
      ],
    );
  }

  Widget _buildToggleField({
    required String label,
    required String value,
    required List<String> options,
    required VoidCallback onToggle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: TextStyle(color: Colors.grey, fontSize: 9, letterSpacing: 1.0)),
        SizedBox(height: 6),
        GestureDetector(
          onTap: onToggle,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.05),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.accent.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                ),
                SizedBox(width: 4),
                Icon(Icons.swap_horiz_rounded, color: AppColors.accent, size: 12),
              ],
            ),
          ),
        ),
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
          color: _canConfirm ? AppColors.accent : Colors.grey[700],
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
        child: Text(label, style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }
}
