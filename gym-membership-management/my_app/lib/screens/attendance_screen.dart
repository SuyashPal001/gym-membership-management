import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../screens/member_detail_screen.dart';
import '../services/api_exception.dart';
import '../services/api_service.dart';
import '../models/member.dart';
import '../models/attendance_session.dart';
import 'package:google_fonts/google_fonts.dart';

class AttendanceScreen extends StatefulWidget {
  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  List<Member> _allFullMembers = [];
  Map<String, AttendanceSession> _liveSessions = {};
  Set<String> _completedTodayIds = {};
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
      final results = await Future.wait([
        ApiService.fetchMembers(),
        ApiService.fetchTodayAttendanceFull(),
      ]);
      final members = results[0] as List<Member>;
      final todayData = results[1] as Map<String, dynamic>;

      final liveMap = <String, AttendanceSession>{};
      for (var s in (todayData['currently_in'] as List)) {
        final session = AttendanceSession.fromJson(s);
        liveMap[session.memberId] = session;
      }

      final completedIds = <String>{};
      for (var s in (todayData['checked_out'] as List)) {
        final memberId = s['member_id']?.toString();
        if (memberId != null) completedIds.add(memberId);
      }

      if (!mounted) return;
      setState(() {
        _allFullMembers = members;
        _liveSessions = liveMap;
        _completedTodayIds = completedIds;
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
        final isPaymentDue = m.status == 'expired' || m.status == 'inactive' || (m.status == 'active' && !m.paymentCollected);
        if (_selectedFilter == 'Active') return m.status == 'active' && m.paymentCollected;
        if (_selectedFilter == 'Trial') return m.status == 'trial';
        if (_selectedFilter == 'Payment Due') return isPaymentDue;
        if (_selectedFilter == 'Expired') return m.status == 'expired' || m.status == 'inactive';
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
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Colors.white,
            size: 18,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text("IN GYM", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.white)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppColors.accent),
            onPressed: _loadData,
          )
        ],
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
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
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
      floatingActionButton: FloatingActionButton(
        onPressed: _showCheckInSheet,
        backgroundColor: AppColors.accent,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add, color: Colors.black, size: 28),
      ),
    );
  }

  Widget _buildContent() {
    final displayMembers = _filteredMembers;

    return RefreshIndicator(
      onRefresh: _loadData,
      color: Colors.orangeAccent,
      backgroundColor: AppColors.cardBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Neural Stat Header (Profile Sync)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.cardBackground.withOpacity(0.4),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withOpacity(0.03)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.orangeAccent.withOpacity(0.15),
                          AppColors.background,
                        ],
                      ),
                      border: Border.all(color: Colors.orangeAccent.withOpacity(0.3), width: 1.5),
                    ),
                    child: const Icon(Icons.sensors_rounded, color: Colors.orangeAccent, size: 24),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "PULSE MONITORING",
                          style: GoogleFonts.outfit(
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            color: Colors.orangeAccent,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "LIVE NOW",
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _liveSessions.length.toString(),
                    style: GoogleFonts.outfit(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Search Bar (Boutique Precision Sync)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                style: GoogleFonts.outfit(color: AppColors.primaryText, fontSize: 16),
                decoration: InputDecoration(
                  hintText: "Search people in gym right now...",
                  hintStyle: GoogleFonts.outfit(color: AppColors.secondaryText, fontSize: 15),
                  prefixIcon: Icon(Icons.search_rounded, color: AppColors.secondaryText.withOpacity(0.7), size: 22),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.only(left: 28, bottom: 16),
            child: Text(
              "ACTIVE SESSIONS",
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: AppColors.primaryText,
              ),
            ),
          ),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Row(
              children: ['All', 'Active', 'Trial', 'Payment Due', 'Expired'].map((filter) {
                final isSelected = _selectedFilter == filter;
                return GestureDetector(
                  onTap: () => setState(() => _selectedFilter = filter),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.orangeAccent.withOpacity(0.08) : Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: isSelected ? Colors.orangeAccent.withOpacity(0.4) : Colors.white.withOpacity(0.06),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      filter.toUpperCase(),
                      style: GoogleFonts.outfit(
                        color: isSelected ? Colors.orangeAccent : Colors.white38,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: displayMembers.isEmpty
                ? Container(
                    padding: const EdgeInsets.only(top: 100),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Icon(Icons.dashboard_customize_rounded, color: Colors.white.withOpacity(0.05), size: 48),
                          const SizedBox(height: 16),
                          Text(
                            "FEEDS CLEAR",
                            style: GoogleFonts.outfit(
                              color: Colors.white.withOpacity(0.2),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: displayMembers.length,
                    itemBuilder: (context, index) {
                      final member = displayMembers[index];
                      final session = _liveSessions[member.id];
                      bool isPaymentDue = member.status == 'expired' || member.status == 'inactive' || (member.status == 'active' && !member.paymentCollected);
                      bool isTrial = member.status == 'trial';

                      Color statusColor = AppColors.success;
                      String statusText = "ACTIVE";
                      if (isTrial) {
                        statusText = "TRIAL";
                        statusColor = Colors.orangeAccent;
                      } else if (member.status == 'inactive') {
                        statusText = "INACTIVE";
                        statusColor = AppColors.secondaryText;
                      } else if (isPaymentDue) {
                        statusText = "PAYMENT DUE";
                        statusColor = AppColors.error;
                      }

                      String checkInFormatted = '';
                      if (session != null) {
                        checkInFormatted = 'Checked in at ${DateFormat('h:mm a').format(session.checkInTime.toLocal())}';
                      }

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (_, __, ___) => MemberDetailScreen(memberName: member.memberName, member: member),
                              transitionDuration: Duration.zero,
                              reverseTransitionDuration: Duration.zero,
                            ),
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.cardBackground,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.border.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              // Flagship Avatar Hub
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  member.memberName.isNotEmpty ? member.memberName[0].toUpperCase() : '?',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                                ),
                              ),
                              const SizedBox(width: 14),
                              // Flagship Info Cluster
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            member.memberName,
                                            style: const TextStyle(
                                              color: AppColors.primaryText,
                                              fontSize: 17,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        // Flagship Badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: statusColor.withOpacity(0.10),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            statusText, // e.g. ACTIVE, TRIAL
                                            style: GoogleFonts.outfit(
                                              color: statusColor,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      checkInFormatted,
                                      style: TextStyle(
                                        color: AppColors.secondaryText.withOpacity(0.9),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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

  Future<void> _showCheckInSheet() async {
    String searchQuery = '';
    List<Member> filtered = List.from(_allFullMembers);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.75,
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[600],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Manual Check-In',
                      style: TextStyle(
                        color: AppColors.primaryText,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      autofocus: true,
                      onChanged: (val) {
                        setSheetState(() {
                          searchQuery = val.toLowerCase();
                          filtered = _allFullMembers
                              .where((m) =>
                                  m.memberName.toLowerCase().contains(searchQuery) ||
                                  (m.phone.toLowerCase().contains(searchQuery)))
                              .toList();
                        });
                      },
                      style: TextStyle(color: AppColors.primaryText),
                      decoration: InputDecoration(
                        hintText: 'Search by name or phone',
                        hintStyle: TextStyle(color: AppColors.secondaryText),
                        prefixIcon: Icon(Icons.search, color: AppColors.secondaryText),
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final member = filtered[index];
                          final alreadyIn = _liveSessions.containsKey(member.id);
                          final doneToday = _completedTodayIds.contains(member.id);
                          final blocked = alreadyIn || doneToday;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.accent.withOpacity(0.2),
                              child: Text(
                                member.memberName[0].toUpperCase(),
                                style: TextStyle(color: AppColors.accent),
                              ),
                            ),
                            title: Text(
                              member.memberName,
                              style: TextStyle(color: AppColors.primaryText),
                            ),
                            subtitle: Text(
                              alreadyIn ? 'Currently in gym' : doneToday ? 'Session completed today' : member.phone,
                              style: TextStyle(
                                color: alreadyIn ? AppColors.success : doneToday ? AppColors.secondaryText : AppColors.secondaryText,
                                fontSize: 12,
                              ),
                            ),
                            trailing: alreadyIn
                                ? Icon(Icons.sensors_rounded, color: AppColors.success)
                                : doneToday
                                    ? Icon(Icons.check_circle_outline, color: AppColors.secondaryText)
                                    : Icon(Icons.add_circle_outline, color: AppColors.secondaryText),
                            onTap: blocked
                                ? null
                                : () async {
                                    Navigator.pop(context);
                                    // Optimistic update — show member instantly
                                    final now = DateTime.now();
                                    final optimisticSession = AttendanceSession(
                                      id: 'optimistic_${member.id}',
                                      gymId: member.gymId ?? '',
                                      memberId: member.id ?? '',
                                      checkInTime: now,
                                      date: now.toIso8601String().substring(0, 10),
                                    );
                                    if (mounted) {
                                      setState(() {
                                        _liveSessions[member.id ?? ''] = optimisticSession;
                                      });
                                    }
                                    try {
                                      await ApiService.manualCheckIn(member.id ?? '');
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('${member.memberName} checked in ✓'),
                                            backgroundColor: AppColors.success,
                                          ),
                                        );
                                        _loadData(); // sync real data in background
                                      }
                                    } on ApiException catch (e) {
                                      // Rollback optimistic update on failure
                                      if (mounted) {
                                        setState(() => _liveSessions.remove(member.id));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text(e.message), backgroundColor: Colors.redAccent),
                                        );
                                      }
                                    }
                                  },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
