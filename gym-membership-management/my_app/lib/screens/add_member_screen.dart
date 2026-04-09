import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/app_colors.dart';
import '../models/member.dart';
import '../services/api_exception.dart';
import '../services/api_service.dart';
import '../widgets/api_server_dialog.dart';

class AddMemberScreen extends StatefulWidget {
  @override
  _AddMemberScreenState createState() => _AddMemberScreenState();
}

class _AddMemberScreenState extends State<AddMemberScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  
  List<MembershipType> _plans = [];
  MembershipType? _selectedPlan;
  bool _isTrial = false;
  bool _paymentCollected = true;
  bool _isLoading = false;
  bool _isFetchingPlans = true;
  String? _plansError;

  XFile? _imageFile;
  String? _base64Image;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() {
      _isFetchingPlans = true;
      _plansError = null;
    });
    try {
      final plans = await ApiService.fetchMembershipTypes();
      if (!mounted) return;
      setState(() {
        _plans = plans;
        _selectedPlan = null; // Always default to "Select plan" hint
        _plansError = null;
        _isFetchingPlans = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _plans = [];
        _selectedPlan = null;
        _plansError = e.message;
        _isFetchingPlans = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _plans = [];
        _selectedPlan = null;
        _plansError = e.toString();
        _isFetchingPlans = false;
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery, // Use gallery for web/prototype easily
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 80,
      );
      if (pickedFile != null) {
        final Uint8List bytes = await pickedFile.readAsBytes();
        setState(() {
          _imageFile = pickedFile;
          _base64Image = base64Encode(bytes);
        });
      }
    } catch (e) {
      print("Error picking image: $e");
    }
  }

  Future<void> _enrollMember() async {
    if (_nameController.text.isEmpty || _phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please fill in name and phone")),
      );
      return;
    }

    if (!_isTrial) {
      if (_plans.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _plansError != null
                  ? 'Fix API connection first, then reload plans.'
                  : 'No membership plans available. Add plans in the backend or retry.',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
      if (_selectedPlan == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Select a membership plan'), backgroundColor: Colors.redAccent),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    final member = Member(
      gymId: ApiService.defaultGymId,
      memberName: _nameController.text,
      phone: _phoneController.text,
      image: _base64Image,
      membershipTypeId: _isTrial ? null : _selectedPlan?.id,
      isTrial: _isTrial,
      paymentCollected: _paymentCollected,
    );

    try {
      await ApiService.enrollMember(member);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Member enrolled successfully!"), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
                  GestureDetector(
                    onTap: _pickImage,
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: AppColors.cardBackground,
                      backgroundImage: _base64Image != null 
                          ? MemoryImage(base64Decode(_base64Image!)) 
                          : null,
                      child: _base64Image == null 
                          ? Icon(Icons.person, size: 50, color: AppColors.secondaryText)
                          : null,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.camera_alt, size: 20, color: Colors.white),
                      ),
                    ),
                  )
                ],
              ),
            ),
            SizedBox(height: 30),
            Text("Personal Details", style: TextStyle(color: AppColors.secondaryText, fontSize: 14)),
            SizedBox(height: 12),
            _buildTextField("Full Name", Icons.person_outline, _nameController),
            SizedBox(height: 16),
            _buildTextField("Phone Number", Icons.phone_outlined, _phoneController),
            
            SizedBox(height: 30),
            Text("Membership Plan", style: TextStyle(color: AppColors.secondaryText, fontSize: 14)),
            SizedBox(height: 12),
            _buildMembershipPlanBlock(),

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
                    if (_isTrial) {
                      _paymentCollected = false;
                    }
                    // Removed automatic _selectedPlan assignment when toggled off
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
                onPressed: _isLoading ? null : _enrollMember,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading 
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text(
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

  Widget _buildMembershipPlanBlock() {
    if (_isFetchingPlans) {
      return Center(child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: CircularProgressIndicator(color: AppColors.accent),
      ));
    }

    if (_plansError != null) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Could not load plans',
              style: TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              _plansError!,
              style: TextStyle(color: AppColors.secondaryText, fontSize: 13),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () async {
                    await showApiServerDialog(context);
                    if (context.mounted) _loadPlans();
                  },
                  icon: Icon(Icons.dns, color: AppColors.accent),
                  label: Text('Set API server', style: TextStyle(color: AppColors.accent)),
                ),
                SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _loadPlans,
                  icon: Icon(Icons.refresh, color: AppColors.accent),
                  label: Text('Retry', style: TextStyle(color: AppColors.accent)),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (_plans.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No membership types returned',
              style: TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'The API responded but the list is empty. Seed membership_types in the database, then tap Retry.',
              style: TextStyle(color: AppColors.secondaryText, fontSize: 13),
            ),
            SizedBox(height: 12),
            TextButton.icon(
              onPressed: _loadPlans,
              icon: Icon(Icons.refresh, color: AppColors.accent),
              label: Text('Retry', style: TextStyle(color: AppColors.accent)),
            ),
          ],
        ),
      );
    }

    if (_isTrial) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
        ),
        child: Text(
          'Free trial is on — no paid plan is required. Turn off “Free Trial Period” below to pick a plan from the list.',
          style: TextStyle(color: AppColors.secondaryText, fontSize: 14),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<MembershipType>(
          value: _selectedPlan,
          hint: Text('Select plan', style: TextStyle(color: AppColors.secondaryText)),
          dropdownColor: AppColors.cardBackground,
          icon: Icon(Icons.arrow_drop_down, color: AppColors.secondaryText),
          isExpanded: true,
          style: TextStyle(color: AppColors.primaryText, fontSize: 16),
          onChanged: (MembershipType? newValue) {
            setState(() => _selectedPlan = newValue);
          },
          items: _plans.map<DropdownMenuItem<MembershipType>>((MembershipType plan) {
            return DropdownMenuItem<MembershipType>(
              value: plan,
              child: Text('${plan.name} (₹${plan.amount.toStringAsFixed(plan.amount.truncateToDouble() == plan.amount ? 0 : 2)})'),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTextField(String hint, IconData icon, TextEditingController controller) {
    return TextField(
      controller: controller,
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
