import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../screens/member_detail_screen.dart';
import '../services/api_exception.dart';
import '../services/api_service.dart';
import '../models/member.dart';
import '../models/attendance_session.dart';
import '../utils/member_avatar.dart';
import '../widgets/api_server_dialog.dart';

class AttendanceScreen extends StatefulWidget {
  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  List<Member> _allFullMembers = [];
  Map<String, AttendanceSession> _liveSessions = {};
  bool _isLoading = true;
  String? _loadError;
  String _searchQuery = "";
  String _selectedFilter = "All";

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final gymId = ApiService.defaultGymId;
      final results = await Future.wait([
        ApiService.fetchMembers(gymId),
        ApiService.fetchLiveAttendance(gymId),
      ]);
      final members = results[0] as List<Member>;
      final sessions = results[1] as List<AttendanceSession>;

      final liveMap = <String, AttendanceSession>{};
      for (var s in sessions) {
        liveMap[s.memberId] = s;
      }

      if (!mounted) return;
      setState(() {
        _allFullMembers = members;
        _liveSessions = liveMap;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _allFullMembers = [];
        _liveSessions = {};
        _isLoading = false;
        _loadError = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _allFullMembers = [];
        _liveSessions = {};
        _isLoading = false;
        _loadError = e.toString();
      });
    }
  }

  List<Member> get _filteredMembers {
    // 1. First get only those who have a live session today
    final presentMembers = _allFullMembers.where((m) => m.id != null && _liveSessions.containsKey(m.id)).toList();

    // 2. Apply search query
    var filtered = presentMembers;
    if (_searchQuery.trim().isNotEmpty) {
      filtered = filtered.where((m) => m.memberName.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }

    // 3. Apply Chips Filter
    if (_selectedFilter != 'All') {
      filtered = filtered.where((m) {
        bool isDebt = m.status == 'expired' || (m.status == 'active' && !m.paymentCollected);
        bool isTrial = m.status == 'trial';
        if (_selectedFilter == 'Active') {
          return m.status == 'active' && m.paymentCollected;
        } else if (_selectedFilter == 'Trial') {
          return isTrial;
        } else if (_selectedFilter == 'Payment Due') {
          return isDebt;
        }
        return true;
      }).toList();
    }
    
    // 4. Sort by check-in time descending
    filtered.sort((a, b) {
      final sA = _liveSessions[a.id];
      final sB = _liveSessions[b.id];
      if (sA == null || sB == null) return 0;
      return sB.checkInTime.compareTo(sA.checkInTime);
    });

    return filtered;
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
        actions: [
          IconButton(
            tooltip: 'API server',
            icon: Icon(Icons.dns, color: AppColors.accent),
            onPressed: () async {
              await showApiServerDialog(context);
              if (mounted) _loadData();
            },
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: AppColors.accent),
            onPressed: _loadData,
          )
        ],
        title: Text("In Gym", style: TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _loadError!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.secondaryText),
                        ),
                        SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            FilledButton.icon(
                              onPressed: () async {
                                await showApiServerDialog(context);
                                if (mounted) _loadData();
                              },
                              icon: Icon(Icons.dns, size: 18),
                              label: Text('Set API server'),
                            ),
                            TextButton.icon(
                              onPressed: _loadData,
                              icon: Icon(Icons.refresh, color: AppColors.accent),
                              label: Text('Retry', style: TextStyle(color: AppColors.accent)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final displayMembers = _filteredMembers;

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.accent,
      backgroundColor: AppColors.cardBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
            child: Text(
              "Currently in Gym: ${_liveSessions.length}",
              style: TextStyle(color: AppColors.secondaryText, fontSize: 16),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: TextField(
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
              style: TextStyle(color: AppColors.primaryText),
              decoration: InputDecoration(
                hintText: "Search by name",
                hintStyle: TextStyle(color: AppColors.secondaryText),
                prefixIcon: Icon(Icons.search, color: AppColors.secondaryText),
                filled: true,
                fillColor: AppColors.cardBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
            child: Row(
              children: ['All', 'Active', 'Trial', 'Payment Due'].map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedFilter = filter;
                      });
                    },
                    backgroundColor: AppColors.cardBackground,
                    selectedColor: AppColors.accent.withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.accent : AppColors.secondaryText,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected ? AppColors.accent : AppColors.border,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: displayMembers.isEmpty
                ? Center(
                    child: Text(
                      "No members match the criteria.",
                      style: TextStyle(color: AppColors.secondaryText),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: displayMembers.length,
                    itemBuilder: (context, index) {
                      final member = displayMembers[index];
                      final session = _liveSessions[member.id];
                      final avatar = memberAvatarImageProvider(member.image);
                      
                      bool isDebt = member.status == 'expired' || (member.status == 'active' && !member.paymentCollected);
                      bool isTrial = member.status == 'trial';

                      String statusText = member.status.toUpperCase();
                      if (isTrial) statusText = "🟡 TRIAL";
                      if (isDebt && member.status == 'active') statusText = "🔴 PAYMENT DUE";
                      if (member.status == 'expired') statusText = "🔴 EXPIRED";
                      if (member.status == 'active' && member.paymentCollected) statusText = "🟢 ACTIVE VIP";

                      String checkInFormatted = '';
                      if (session != null) {
                        checkInFormatted = 'Checked in at ${DateFormat('h:mm a').format(session.checkInTime.toLocal())}';
                      }

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MemberDetailScreen(
                                memberName: member.memberName,
                                member: member,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          margin: EdgeInsets.only(bottom: 16),
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.cardBackground,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDebt ? Colors.redAccent.withOpacity(0.5) : AppColors.border,
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: isDebt ? Colors.redAccent.withOpacity(0.2) : AppColors.accent.withOpacity(0.2),
                                          backgroundImage: avatar,
                                          child: avatar == null
                                              ? Icon(Icons.person, color: isDebt ? Colors.redAccent : AppColors.accent)
                                              : null,
                                        ),
                                        SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                member.memberName,
                                                style: TextStyle(
                                                  color: AppColors.primaryText,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 16,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                checkInFormatted,
                                                style: TextStyle(
                                                  color: AppColors.secondaryText,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    statusText,
                                    style: TextStyle(
                                      color: isDebt ? Colors.redAccent : (isTrial ? Colors.orangeAccent : AppColors.accent),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (isDebt || isTrial)
                                    ElevatedButton(
                                      onPressed: () async {
                                        if (isTrial) {
                                          try {
                                            await ApiService.createManualReminder(
                                              ApiService.defaultGymId,
                                              member.id ?? '',
                                              'WHATSAPP',
                                              DateTime.now(),
                                              'Hi ${member.memberName}, since you are enjoying your trial, we have a special membership plan for you! (Phone: ${member.phone})',
                                            );
                                            if (!context.mounted) return;
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('WhatsApp Pitch sent to ${member.phone}'), backgroundColor: AppColors.accent),
                                            );
                                          } catch (e) {
                                            if (!context.mounted) return;
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                                            );
                                          }
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isDebt ? Colors.redAccent : Colors.orangeAccent,
                                        foregroundColor: Colors.white,
                                        padding: EdgeInsets.symmetric(horizontal: 16),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      ),
                                      child: Text(isDebt ? "Collect Payment" : "Pitch Plan"),
                                    ),
                                ],
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
