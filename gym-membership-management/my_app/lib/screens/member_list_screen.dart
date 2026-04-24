import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../models/member.dart';
import '../services/api_service.dart';
import '../services/api_exception.dart';
import 'member_detail_screen.dart';
import 'add_member_screen.dart';

String _planLabel(Member member) {
  if (member.isTrial || member.status == 'trial') {
    if (member.expiryDate != null) {
      final exp = DateTime.tryParse(member.expiryDate!);
      if (exp != null) {
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);
        final expDate = DateTime(exp.year, exp.month, exp.day);
        final diff = expDate.difference(todayDate).inDays;
        if (diff < 0) return 'Trial Overdue by ${diff.abs()} days';
      }
    }
    return 'Ongoing Trial';
  }
  return '${member.membershipType?.durationMonths ?? '—'} Month';
}

class MemberListScreen extends StatefulWidget {
  @override
  _MemberListScreenState createState() => _MemberListScreenState();
}

class _MemberListScreenState extends State<MemberListScreen> {
  List<Member> _allMembers = [];
  List<Member> _filteredMembers = [];
  bool _isLoading = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();

  String _appliedStatus = 'All';
  String _appliedPlanId = 'All';
  String _appliedExpiry = 'All';
  List<MembershipType> _availablePlans = [];
  int _activeFilterCount = 0;

  @override
  void initState() {
    super.initState();
    _loadMembers();
    _loadMembershipTypes();
  }

  Future<void> _loadMembershipTypes() async {
    try {
      final types = await ApiService.fetchMembershipTypes();
      if (mounted) setState(() => _availablePlans = types);
    } catch (_) {}
  }

  Future<void> _loadMembers() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final Map<String, String> filters = {};
      int activeCount = 0;

      if (_appliedStatus != 'All') {
        // 'inactive' is computed server-side from 'expired'; send 'expired' and filter locally
        filters['status'] = _appliedStatus == 'Inactive' ? 'expired' : _appliedStatus.toLowerCase();
        activeCount++;
      }
      if (_appliedPlanId != 'All') {
        filters['membership_type_id'] = _appliedPlanId;
        activeCount++;
      }
      if (_appliedExpiry != 'All') {
        filters['expiring_in'] = _appliedExpiry.toLowerCase().replaceAll(' ', '_');
        activeCount++;
      }

      var members = await ApiService.fetchMembers(filters: filters.isNotEmpty ? filters : null);
      if (_appliedStatus == 'Inactive') {
        members = members.where((m) => m.status == 'inactive').toList();
      }
      if (mounted) {
        setState(() {
          _allMembers = members;
          _filteredMembers = members;
          _isLoading = false;
          _activeFilterCount = activeCount;
          _searchController.clear();
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = "An unexpected error occurred: $e"; _isLoading = false; });
    }
  }

  void _filterMembersLocal(String query) {
    setState(() {
      _filteredMembers = _allMembers
          .where((m) => m.memberName.toLowerCase().contains(query.toLowerCase()) || 
                         m.phone.contains(query))
          .toList();
    });
  }

  void _showFilterSheet() {
    String tempStatus = _appliedStatus;
    String tempPlanId = _appliedPlanId;
    String tempExpiry = _appliedExpiry;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).padding.bottom + 32),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 32, height: 4, decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "FILTER MEMBERS",
                        style: GoogleFonts.outfit(color: AppColors.primaryText, fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                      ),
                      GestureDetector(
                        onTap: () {
                          setSheetState(() {
                            tempStatus = 'All';
                            tempPlanId = 'All';
                            tempExpiry = 'All';
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF5252).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFF5252).withOpacity(0.3)),
                          ),
                          child: Text(
                            "CLEAR ALL",
                            style: GoogleFonts.outfit(
                              color: const Color(0xFFFF5252),
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildFilterSection("STATUS", ["All", "Active", "Trial", "Expired", "Inactive"], tempStatus, (val) {
                    setSheetState(() => tempStatus = val);
                  }),
                  const SizedBox(height: 24),
                  _buildPlanFilterSection(tempPlanId, (val) {
                    setSheetState(() => tempPlanId = val);
                  }),
                  const SizedBox(height: 24),
                  _buildFilterSection("EXPIRING IN", ["All", "Today", "This Week", "This Month"], tempExpiry, (val) {
                    setSheetState(() => tempExpiry = val);
                  }),
                  const SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _appliedStatus = tempStatus;
                          _appliedPlanId = tempPlanId;
                          _appliedExpiry = tempExpiry;
                          _updateActiveFilterCount();
                        });
                        Navigator.pop(context);
                        _loadMembers();
                      },
                      child: Container(
                        width: double.infinity,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orangeAccent.withOpacity(0.15),
                              blurRadius: 15,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          "APPLY FILTERS",
                          style: GoogleFonts.outfit(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }

  void _updateActiveFilterCount() {
    int count = 0;
    if (_appliedStatus != 'All') count++;
    if (_appliedPlanId != 'All') count++;
    if (_appliedExpiry != 'All') count++;
    _activeFilterCount = count;
  }

  Widget _buildFilterSection(String title, List<String> options, String current, Function(String) onSelect) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.outfit(
            color: Colors.white.withOpacity(0.85), 
            fontSize: 11, 
            fontWeight: FontWeight.w800, 
            letterSpacing: 1.0
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((opt) {
            final isSelected = current == opt;
            return GestureDetector(
              onTap: () => onSelect(opt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.orangeAccent.withOpacity(0.1) : Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? Colors.orangeAccent.withOpacity(0.5) : Colors.white.withOpacity(0.08),
                    width: 1,
                  ),
                ),
                child: Text(
                  opt.toUpperCase(),
                  style: GoogleFonts.outfit(
                    color: isSelected ? Colors.orangeAccent : AppColors.secondaryText,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPlanFilterSection(String currentPlanId, Function(String) onSelect) {
    List<Map<String, String>> planOptions = [{'id': 'All', 'name': 'All'}];
    planOptions.addAll(_availablePlans.map((p) => {'id': p.id, 'name': p.name}));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "PLAN",
          style: GoogleFonts.outfit(
            color: Colors.white.withOpacity(0.85), 
            fontSize: 11, 
            fontWeight: FontWeight.w800, 
            letterSpacing: 1.0
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: planOptions.map((plan) {
              final isSelected = currentPlanId == plan['id'];
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => onSelect(plan['id']!),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.orangeAccent.withOpacity(0.1) : Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? Colors.orangeAccent.withOpacity(0.5) : Colors.white.withOpacity(0.08),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      plan['name']!.toUpperCase(),
                      style: GoogleFonts.outfit(
                        color: isSelected ? Colors.orangeAccent : AppColors.secondaryText,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  String _formatExpiryDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "No expiry set";
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final isPast = date.isBefore(DateTime(now.year, now.month, now.day));
      final months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
      final prefix = isPast ? "Expired on" : "Expires";
      return "$prefix ${date.day} ${months[date.month - 1]} ${date.year}";
    } catch (_) {
      return "Invalid date";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text(
          'MEMBERS',
          style: TextStyle(
            fontSize: 14, 
            fontWeight: FontWeight.w900, 
            letterSpacing: 1.5,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppColors.secondaryText, size: 20),
            onPressed: () {
              _loadMembers();
              _loadMembershipTypes();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(),
          _buildSearchBar(),
          _buildFilterRow(),
          Expanded(
            child: _isLoading 
              ? Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2))
              : _error != null
                ? _buildErrorState()
                : _filteredMembers.isEmpty
                  ? _buildEmptyState()
                  : _buildMemberList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (context) => AddMemberScreen()));
          _loadMembers(); 
        },
        backgroundColor: AppColors.accent,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add, color: Colors.black, size: 28),
      ),
    );
  }

  Widget _buildHeader() {
    int total = _allMembers.length;
    int activeCount = _allMembers.where((m) => m.status == 'active').length;
    int expiredCount = _allMembers.where((m) => m.status == 'expired').length;
    int inactiveCount = _allMembers.where((m) => m.status == 'inactive').length;
    
    const gold = Color(0xFFC9992A);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground.withOpacity(0.8),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 0.5),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.03),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          // Left Side: Total Members
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "TOTAL MEMBERS",
                  style: GoogleFonts.outfit(
                    color: gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  total.toString(),
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    letterSpacing: -1.5,
                  ),
                ),
              ],
            ),
          ),
          
          // Vertical Subtle Divider
          Container(
            height: 60,
            width: 0.5,
            color: Colors.white.withOpacity(0.1),
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),

          // Right Side: Sub Stats Stacked
          Expanded(
            flex: 6,
            child: Column(
              children: [
                _buildCompactStat("ACTIVE", activeCount.toString(), AppColors.emerald),
                const SizedBox(height: 6),
                _buildCompactStat("EXPIRED", expiredCount.toString(), AppColors.error),
                const SizedBox(height: 6),
                _buildCompactStat("INACTIVE", inactiveCount.toString(), const Color(0xFFA855F7)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.15), width: 0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              color: Colors.white.withOpacity(0.6),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.outfit(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _filterMembersLocal,
                style: const TextStyle(color: AppColors.primaryText, fontSize: 16),
                decoration: InputDecoration(
                  hintText: "Search member name...",
                  hintStyle: const TextStyle(color: AppColors.secondaryText, fontSize: 15),
                  prefixIcon: Icon(Icons.search_rounded, color: AppColors.secondaryText.withOpacity(0.7), size: 22),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _showFilterSheet,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: _activeFilterCount > 0 
                  ? Colors.orangeAccent.withOpacity(0.08) 
                  : Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: _activeFilterCount > 0 
                    ? Colors.orangeAccent.withOpacity(0.4) 
                    : Colors.white.withOpacity(0.06),
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.tune_rounded,
                    color: _activeFilterCount > 0 ? Colors.orangeAccent : AppColors.secondaryText,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'FILTERS',
                    style: GoogleFonts.outfit(
                      color: _activeFilterCount > 0 ? Colors.orangeAccent : AppColors.secondaryText,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  if (_activeFilterCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        color: Colors.orangeAccent,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _activeFilterCount.toString(),
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    if (_activeFilterCount == 0 && _appliedStatus == 'All') return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            if (_appliedStatus != 'All') _buildActiveFilterChip("Status: $_appliedStatus", () {
              setState(() => _appliedStatus = 'All');
              _loadMembers();
            }),
            if (_appliedPlanId != 'All') _buildActiveFilterChip("Plan: ${_availablePlans.firstWhere((p) => p.id == _appliedPlanId, orElse: () => MembershipType(id: '', name: 'Selected', amount: 0, durationMonths: 0)).name}", () {
              setState(() => _appliedPlanId = 'All');
              _loadMembers();
            }),
            if (_appliedExpiry != 'All') _buildActiveFilterChip("Expiry: $_appliedExpiry", () {
              setState(() => _appliedExpiry = 'All');
              _loadMembers();
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveFilterChip(String label, VoidCallback onDelete) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
      decoration: BoxDecoration(
        color: Colors.orangeAccent.withOpacity(0.06),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.orangeAccent.withOpacity(0.4),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          Text(label.toUpperCase(), 
            style: GoogleFonts.outfit(
              color: Colors.orangeAccent, 
              fontSize: 9, 
              fontWeight: FontWeight.w900, 
              letterSpacing: 0.8
            )
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onDelete,
            child: const Icon(Icons.close_rounded, color: Colors.orangeAccent, size: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberList() {
    return RefreshIndicator(
      onRefresh: _loadMembers,
      color: AppColors.accent,
      backgroundColor: AppColors.cardBackground,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        itemCount: _filteredMembers.length,
        itemBuilder: (context, index) {
          final member = _filteredMembers[index];
          return _buildMemberTile(member);
        },
      ),
    );
  }

  Widget _buildMemberTile(Member member) {
    Color statusColor = AppColors.secondaryText;
    switch (member.status.toLowerCase()) {
      case 'active':
      case 'enrolled':
        statusColor = AppColors.emerald;
        break;
      case 'trial':
        statusColor = AppColors.infoBlue;
        break;
      case 'expired':
        statusColor = AppColors.error;
        break;
      case 'inactive':
        statusColor = AppColors.secondaryText;
        break;
    }

    bool isPast = false;
    if (member.expiryDate != null) {
      final exp = DateTime.tryParse(member.expiryDate!);
      if (exp != null) {
        isPast = exp.isBefore(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day));
      }
    }

    Color dateColor = isPast ? AppColors.error : AppColors.secondaryText;

    return InkWell(
      onTap: () async {
        await Navigator.push(context, PageRouteBuilder(
          pageBuilder: (_, __, ___) => MemberDetailScreen(memberName: member.memberName, member: member),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ));
        _loadMembers();
      },
      borderRadius: BorderRadius.circular(12),
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
                style: TextStyle(
                  color: AppColors.primaryText,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          member.memberName,
                          style: TextStyle(
                            color: AppColors.primaryText,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          member.status.toUpperCase(),
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
                  const SizedBox(height: 4),
                  Text(
                    _planLabel(member).toUpperCase(),
                    style: TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, color: dateColor, size: 12),
                      const SizedBox(width: 6),
                      Text(
                        _formatExpiryDate(member.expiryDate),
                        style: TextStyle(
                          color: dateColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: AppColors.error.withOpacity(0.8), size: 48),
          const SizedBox(height: 16),
          const Text(
            "Connection Interrupted",
            style: TextStyle(color: AppColors.primaryText, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(_error ?? "Unknown error", style: const TextStyle(color: AppColors.secondaryText)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadMembers,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("RETRY", style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasFilter = _activeFilterCount > 0 || _searchController.text.isNotEmpty;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasFilter ? Icons.filter_list_off_rounded : Icons.done_all_rounded,
            color: AppColors.secondaryText.withOpacity(0.1),
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            hasFilter ? "No members match this filter" : "No members found",
            style: TextStyle(
                color: AppColors.secondaryText.withOpacity(0.3), fontSize: 13),
          ),
          if (hasFilter) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                setState(() {
                  _appliedStatus = 'All';
                  _appliedPlanId = 'All';
                  _appliedExpiry = 'All';
                  _activeFilterCount = 0;
                  _searchController.clear();
                });
                _loadMembers();
              },
              child: Text(
                "Clear filters",
                style: TextStyle(
                  color: AppColors.accent.withOpacity(0.6),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
