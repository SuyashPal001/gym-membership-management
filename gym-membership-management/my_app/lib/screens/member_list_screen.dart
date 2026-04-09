import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/member.dart';
import '../services/api_service.dart';
import '../services/api_exception.dart';
import '../utils/member_avatar.dart';
import 'member_detail_screen.dart';
import 'add_member_screen.dart';

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

  // Screen-level (Applied) Filters State
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
      if (mounted) {
        setState(() {
          _availablePlans = types;
        });
      }
    } catch (_) {
      // Silently fail, Plan filter will just show "All"
    }
  }

  Future<void> _loadMembers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final Map<String, String> filters = {};
      int activeCount = 0;

      if (_appliedStatus != 'All') {
        filters['status'] = _appliedStatus.toLowerCase();
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

      final members = await ApiService.fetchMembers(
        ApiService.defaultGymId, 
        filters: filters.isNotEmpty ? filters : null
      );

      if (mounted) {
        setState(() {
          _allMembers = members;
          _filteredMembers = members;
          _isLoading = false;
          _activeFilterCount = activeCount;
          _searchController.clear(); // Clear search on filter change
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "An unexpected error occurred: $e";
          _isLoading = false;
        });
      }
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
    // Temp variables for the bottom sheet (prevents unapplied changes)
    String tempStatus = _appliedStatus;
    String tempPlanId = _appliedPlanId;
    String tempExpiry = _appliedExpiry;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).padding.bottom + 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Filter Members",
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: () {
                          setSheetState(() {
                            tempStatus = 'All';
                            tempPlanId = 'All';
                            tempExpiry = 'All';
                          });
                        },
                        child: Text("Clear All", style: TextStyle(color: Colors.redAccent)),
                      )
                    ],
                  ),
                  SizedBox(height: 24),
                  _buildFilterSection("Status", ["All", "Active", "Trial", "Expired"], tempStatus, (val) {
                    setSheetState(() => tempStatus = val);
                  }),
                  SizedBox(height: 16),
                  _buildPlanFilterSection(tempPlanId, (val) {
                    setSheetState(() => tempPlanId = val);
                  }),
                  SizedBox(height: 16),
                  _buildFilterSection("Expiring In", ["All", "Today", "This Week", "This Month"], tempExpiry, (val) {
                    setSheetState(() => tempExpiry = val);
                  }),
                  SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        // Confirm and apply filters to screen state
                        setState(() {
                          _appliedStatus = tempStatus;
                          _appliedPlanId = tempPlanId;
                          _appliedExpiry = tempExpiry;
                        });
                        Navigator.pop(context);
                        _loadMembers();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text("Apply Filters", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            );
          }
        );
      },
    );
  }

  Widget _buildFilterSection(String title, List<String> options, String current, Function(String) onSelect) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: AppColors.secondaryText, fontSize: 14)),
        SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: options.map((opt) {
            final isSelected = current == opt;
            return ChoiceChip(
              label: Text(opt),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) onSelect(opt);
              },
              backgroundColor: AppColors.cardBackground,
              selectedColor: AppColors.accent.withOpacity(0.2),
              labelStyle: TextStyle(color: isSelected ? AppColors.accent : Colors.white, fontSize: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: isSelected ? AppColors.accent : Colors.transparent),
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
        Text("Plan", style: TextStyle(color: AppColors.secondaryText, fontSize: 14)),
        SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: planOptions.map((opt) {
              final isSelected = currentPlanId == opt['id'];
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(opt['name']!),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) onSelect(opt['id']!);
                  },
                  backgroundColor: AppColors.cardBackground,
                  selectedColor: AppColors.accent.withOpacity(0.2),
                  labelStyle: TextStyle(color: isSelected ? AppColors.accent : Colors.white, fontSize: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: isSelected ? AppColors.accent : Colors.transparent),
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
      final months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
      return "Expires ${date.day} ${months[date.month - 1]} ${date.year}";
    } catch (_) {
      return "Invalid date";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "Gym Members",
          style: TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.bold),
        ),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: Icon(Icons.filter_list, color: AppColors.accent),
                onPressed: _showFilterSheet,
              ),
              if (_activeFilterCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                    constraints: BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '$_activeFilterCount',
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
            ],
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: AppColors.accent),
            onPressed: () {
              _loadMembers();
              _loadMembershipTypes();
            },
          )
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _isLoading 
              ? Center(child: CircularProgressIndicator(color: AppColors.accent))
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
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _searchController,
        onChanged: _filterMembersLocal,
        style: TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: "Search by name or phone...",
          hintStyle: TextStyle(color: AppColors.secondaryText),
          prefixIcon: Icon(Icons.search, color: AppColors.secondaryText),
          filled: true,
          fillColor: AppColors.cardBackground,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: EdgeInsets.symmetric(vertical: 0),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.redAccent, size: 60),
            SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: AppColors.secondaryText)),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadMembers,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
              child: Text("Retry"),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isFiltered = _appliedStatus != 'All' || _appliedPlanId != 'All' || _appliedExpiry != 'All';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, color: AppColors.secondaryText, size: 80),
          SizedBox(height: 16),
          Text("No members found", style: TextStyle(color: AppColors.secondaryText, fontSize: 18)),
          SizedBox(height: 8),
          Text(
            isFiltered ? "No members match these filters" : "Enroll your first member to get started",
            style: TextStyle(color: AppColors.secondaryText.withOpacity(0.5)),
          ),
          if (isFiltered)
            TextButton(
              onPressed: () {
                setState(() {
                  _appliedStatus = 'All';
                  _appliedPlanId = 'All';
                  _appliedExpiry = 'All';
                });
                _loadMembers();
              },
              child: Text("Clear All Filters", style: TextStyle(color: AppColors.accent)),
            )
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
        padding: EdgeInsets.only(bottom: 80),
        itemCount: _filteredMembers.length,
        itemBuilder: (context, index) {
          final member = _filteredMembers[index];
          return _buildMemberTile(member);
        },
      ),
    );
  }

  Widget _buildMemberTile(Member member) {
    final statusColor = member.status == 'active' 
        ? AppColors.accent 
        : (member.status == 'trial' ? Colors.blueAccent : Colors.redAccent);

    final avatarProvider = memberAvatarImageProvider(member.image);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        onTap: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (context) => MemberDetailScreen(memberName: member.memberName, member: member)));
          _loadMembers();
        },
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Hero(
          tag: 'avatar-${member.id}',
          child: CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.background,
            backgroundImage: avatarProvider,
            child: avatarProvider == null ? Text(member.memberName[0].toUpperCase(), style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)) : null,
          ),
        ),
        title: Row(
          children: [
            Expanded(child: Text(member.memberName, style: TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis)),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: statusColor.withOpacity(0.5))),
              child: Text(member.status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Text(member.membershipType?.name ?? (member.isTrial ? "Free Trial" : "No Plan"), style: TextStyle(color: AppColors.primaryText.withOpacity(0.9), fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.event_available, size: 14, color: AppColors.secondaryText),
                SizedBox(width: 4),
                Expanded(child: Text(_formatExpiryDate(member.expiryDate), style: TextStyle(color: AppColors.secondaryText, fontSize: 12), overflow: TextOverflow.ellipsis)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
