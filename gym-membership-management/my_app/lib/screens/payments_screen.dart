import 'package:flutter/material.dart';
import '../models/payment_models.dart';
import '../services/api_exception.dart';
import '../services/api_service.dart';

class PaymentsScreen extends StatefulWidget {
  @override
  _PaymentsScreenState createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  static const Color bgColor = Color(0xFF0A0A0A);
  static const Color accentColor = Color(0xFF00C853);
  static const Color cardColor = Color(0xFF1A1A1A);

  List<PaymentSummary> _allData = [];
  List<PaymentSummary> _filteredList = [];
  bool _isLoading = true;
  String _activeFilter = 'All';
  int _activeTabIndex = 0; // 0 = Unpaid, 1 = Paid

  double _totalCollected = 0.0;
  int _expiringThisWeekCount = 0;
  int _overdueCount = 0;
  double _overdueAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isLoading = true);
    try {
      // First fetch ALL to compute global stats
      final data = await ApiService.fetchPaymentSummaries();
      _allData = data;
      _computeGlobalStats();
      
      // If active filter isn't 'All', re-fetch with filter param
      if (_activeFilter != 'All') {
        final param = _activeFilter.toLowerCase().replaceAll(' ', '_');
        _filteredList = await ApiService.fetchPaymentSummaries(expiryFilter: param);
      } else {
        _filteredList = _allData;
      }
    } on ApiException catch (e) {
      _showSnackbar(e.message, Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _computeGlobalStats() {
    _totalCollected = 0.0;
    _expiringThisWeekCount = 0;
    _overdueCount = 0;
    _overdueAmount = 0.0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekLimit = today.add(Duration(days: 7));

    for (var p in _allData) {
      if (p.paymentCollected) {
        _totalCollected += p.planAmount;
      } else {
        if (p.expiryDate != null) {
          final exp = DateTime.tryParse(p.expiryDate!);
          if (exp != null) {
            if (exp.isBefore(today)) {
              _overdueCount++;
              _overdueAmount += p.planAmount;
            } else if (exp.isBefore(weekLimit)) {
              _expiringThisWeekCount++;
            }
          }
        }
      }
    }
  }

  Future<void> _changeExpiryFilter(String filter) async {
    setState(() {
      _activeFilter = filter;
      _isLoading = true;
    });
    try {
      final param = (filter == 'All') ? null : filter.toLowerCase().replaceAll(' ', '_');
      final data = await ApiService.fetchPaymentSummaries(expiryFilter: param);
      if (mounted) {
        setState(() {
          _filteredList = data;
          _isLoading = false;
        });
      }
    } on ApiException catch (e) {
      _showSnackbar(e.message, Colors.red);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackbar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  Future<void> _handleRemind(PaymentSummary item) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Send Reminder", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text("Select method to remind ${item.memberName} about ₹${item.planAmount.toStringAsFixed(0)}", 
              style: TextStyle(color: Colors.white54, fontSize: 13)
            ),
            SizedBox(height: 24),
            _buildReminderOption(
              icon: Icons.chat_bubble_outline,
              title: "WhatsApp",
              subtitle: "Send a text message reminder",
              onTap: () => _triggerReminder(item.id, 'WHATSAPP'),
            ),
            SizedBox(height: 12),
            _buildReminderOption(
              icon: Icons.phone_in_talk_outlined,
              title: "AI Voice Call",
              subtitle: "Automated AI call follow-up",
              onTap: () => _triggerReminder(item.id, 'AI_CALL'),
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderOption({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Icon(icon, color: accentColor, size: 24),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text(subtitle, style: TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.white12, size: 14),
          ],
        ),
      ),
    );
  }

  Future<void> _triggerReminder(String memberId, String method) async {
    Navigator.pop(context);
    try {
      await ApiService.postReminder(ApiService.defaultGymId, memberId, method);
      _showSnackbar("Reminder scheduled successfully", accentColor);
    } on ApiException catch (e) {
      _showSnackbar(e.message, Colors.red);
    }
  }

  Future<void> _handleMarkPaid(PaymentSummary item) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Confirm Payment", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Text("Mark ₹${item.planAmount.toStringAsFixed(0)} as received from ${item.memberName}?", 
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 14)
            ),
            SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  try {
                    await ApiService.markPaymentAsPaid(memberId: item.id);
                    _showSnackbar("Payment recorded successfully", accentColor);
                    // Remove from view locally for speed and refresh global stats
                    setState(() {
                      _filteredList.removeWhere((element) => element.id == item.id);
                    });
                    _fetchInitialData(); 
                  } on ApiException catch (e) {
                    _showSnackbar(e.message, Colors.red);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text("Confirm Receipt", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayList = _filteredList.where((p) => p.paymentCollected == (_activeTabIndex == 1)).toList();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text("Payments", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white54),
            onPressed: _fetchInitialData,
          )
        ],
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // 1. Summary Strip
          _buildSummaryStrip(),
          
          // 2. Filter Chips
          _buildFilterChips(),

          // 3. Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              children: [
                _buildTab("Unpaid", 0),
                SizedBox(width: 25),
                _buildTab("Paid History", 1),
              ],
            ),
          ),
          SizedBox(height: 12),

          // 4. Member Cards
          Expanded(
            child: _isLoading 
              ? Center(child: CircularProgressIndicator(color: accentColor))
              : displayList.isEmpty 
                  ? Center(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.payment, color: Colors.white10, size: 64),
                        SizedBox(height: 16),
                        Text("No records found", style: TextStyle(color: Colors.white24)),
                      ],
                    ))
                  : ListView.builder(
                      itemCount: displayList.length,
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      itemBuilder: (context, idx) => _buildMemberCard(displayList[idx]),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStrip() {
    return Container(
      height: 110,
      padding: EdgeInsets.symmetric(vertical: 10),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 20),
        children: [
          _buildStatCard("Collected", "₹${_totalCollected.toStringAsFixed(0)}", accentColor),
          _buildStatCard("Expiring", "${_expiringThisWeekCount} this wk", Colors.amber),
          _buildStatCard("Overdue", "${_overdueCount} (₹${_overdueAmount.toStringAsFixed(0)})", Colors.redAccent),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      width: 145,
      margin: EdgeInsets.only(right: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor, 
        borderRadius: BorderRadius.circular(16), 
        border: Border.all(color: color.withOpacity(0.1))
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.white54, fontSize: 11)),
          Spacer(),
          Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final options = ['All', 'Today', 'This Week', 'Overdue'];
    return Container(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        itemCount: options.length,
        itemBuilder: (context, idx) {
          final opt = options[idx];
          final isActive = _activeFilter == opt;
          return Padding(
            padding: const EdgeInsets.only(right: 10.0),
            child: ChoiceChip(
              label: Text(opt),
              selected: isActive,
              onSelected: (val) => val ? _changeExpiryFilter(opt) : null,
              backgroundColor: cardColor,
              selectedColor: accentColor.withOpacity(0.2),
              labelStyle: TextStyle(
                color: isActive ? accentColor : Colors.white54, 
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20), 
                side: BorderSide(color: isActive ? accentColor : Colors.white12)
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final isActive = _activeTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _activeTabIndex = index),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label, 
            style: TextStyle(
              color: isActive ? Colors.white : Colors.white54, 
              fontSize: 16,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal
            )
          ),
          SizedBox(height: 6),
          if (isActive) Container(width: 24, height: 3, decoration: BoxDecoration(color: accentColor, borderRadius: BorderRadius.circular(2))),
        ],
      ),
    );
  }

  Widget _buildMemberCard(PaymentSummary item) {
    // Urgency coloring logic
    Color dateColor = Colors.white54;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    if (item.expiryDate != null) {
      final exp = DateTime.tryParse(item.expiryDate!);
      if (exp != null) {
        if (exp.isBefore(today)) dateColor = Colors.redAccent;
        else if (exp.isBefore(today.add(Duration(days: 7)))) dateColor = Colors.amber;
        else dateColor = accentColor;
      }
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.memberName, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    SizedBox(height: 4),
                    Text(item.planName, style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("₹${item.planAmount.toStringAsFixed(0)}", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  SizedBox(height: 4),
                  Text(item.expiryDate ?? "No Expiry", style: TextStyle(color: dateColor, fontSize: 12)),
                ],
              ),
            ],
          ),
          if (_activeTabIndex == 0) ...[
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _handleRemind(item),
                    icon: Icon(Icons.notifications_active_outlined, size: 16),
                    label: Text("Remind"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: BorderSide(color: Colors.white10), 
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleMarkPaid(item),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor, 
                      elevation: 0, 
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text("Mark Paid", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ] else ...[
            SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                   Icon(Icons.check_circle, color: accentColor, size: 14),
                   SizedBox(width: 6),
                   Text("Collected on ${item.expiryDate ?? 'recent'}", style: TextStyle(color: Colors.white30, fontSize: 12)),
                ],
              ),
            )
          ],
        ],
      ),
    );
  }
}
