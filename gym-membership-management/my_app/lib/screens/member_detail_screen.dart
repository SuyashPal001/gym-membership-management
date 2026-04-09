import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/member.dart';
import '../models/crm_models.dart';
import '../models/reminder_models.dart';
import '../models/attendance_summary.dart';
import '../services/api_exception.dart';
import '../services/api_service.dart';
import '../utils/member_avatar.dart';
import '../constants/app_colors.dart';
import 'reminder_history_screen.dart';
import 'attendance_history_screen.dart';

class MemberDetailScreen extends StatefulWidget {
  final String memberName;
  final Member? member;

  const MemberDetailScreen({Key? key, required this.memberName, this.member}) : super(key: key);

  @override
  _MemberDetailScreenState createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends State<MemberDetailScreen> {
  final String _gymId = ApiService.defaultGymId;
  String get _memberId => widget.member?.id ?? '';

  MemberStats? _stats;
  AttendanceSummary? _attendanceSummary;
  String? _statsError;
  ImageProvider? _avatarImage;
  bool _isLoading = true;
  List<ReminderHistory> _reminderHistory = [];

  // Colors based on user specs
  static const Color bgColor = AppColors.background;
  static const Color accentColor = AppColors.accent;
  static const Color cardColor = AppColors.cardBackground;

  @override
  void initState() {
    super.initState();
    _avatarImage = memberAvatarImageProvider(widget.member?.image);
    _loadData();
  }

  Future<void> _loadData() async {
    if (_memberId.isEmpty) {
      if (mounted) setState(() { _isLoading = false; _statsError = 'Missing member id'; });
      return;
    }
    setState(() { _isLoading = true; _statsError = null; });

    // Fetch in parallel for better performance
    await Future.wait([
      ApiService.fetchMemberStats(_gymId, _memberId).then((res) => _stats = res).catchError((e) => _statsError = e.toString()),
      ApiService.fetchReminderHistory(_gymId, _memberId).then((res) => _reminderHistory = res).catchError((_) => _reminderHistory = []),
      ApiService.fetchAttendanceSummary(_gymId, _memberId).then((res) => _attendanceSummary = res).catchError((_) => _attendanceSummary = null),
    ]);

    print('Stats loaded: $_stats');
    print('Reminder history count: ${_reminderHistory.length}');

    if (mounted) setState(() { _isLoading = false; });
  }

  String _getTimeAgo(String dateStr) {
    if (dateStr.isEmpty) return "";
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inDays >= 7) return "${(diff.inDays / 7).floor()}w ago";
      if (diff.inDays >= 1) return "${diff.inDays}d ago";
      if (diff.inHours >= 1) return "${diff.inHours}h ago";
      if (diff.inMinutes >= 1) return "${diff.inMinutes}m ago";
      return "Just now";
    } catch (_) {
      return "";
    }
  }

  Future<void> _triggerQuickReminder(String method) async {
    try {
      await ApiService.postReminder(_gymId, _memberId, method);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$method Reminder scheduled'), backgroundColor: accentColor),
      );
      // Refresh history to show the new one (as scheduled: false in DB it might not show in history yet, but service query depends on scheduled: true)
      _loadData();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _uploadAvatar() async {
    if (_memberId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot upload: missing member id'), backgroundColor: Colors.red),
      );
      return;
    }
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (file == null) return;
    try {
      final url = await ApiService.uploadAvatar(_gymId, _memberId, file.path);
      if (!mounted) return;
      setState(() => _avatarImage = memberAvatarImageProvider(url));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Photo updated'), backgroundColor: accentColor),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _scheduleReminder(String method) async {
    print('TAPPED TRIGGERED: $method');
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(primary: accentColor, surface: cardColor),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      if (!mounted) return;
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        builder: (context, child) {
          return Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: ColorScheme.dark(primary: accentColor, surface: cardColor),
            ),
            child: child!,
          );
        },
      );

      if (pickedTime != null) {
        final scheduledDate = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        // Show a quick dialog for the message or prompt
        final TextEditingController _msgController = TextEditingController();
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: cardColor,
            title: Text('Schedule $method', style: TextStyle(color: Colors.white)),
            content: TextField(
              controller: _msgController,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: method == 'WHATSAPP' ? 'Message...' : 'AI Prompt...',
                hintStyle: TextStyle(color: Colors.white54)
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: Colors.white54))),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  try {
                    await ApiService.createManualReminder(
                      _gymId,
                      _memberId,
                      method,
                      scheduledDate,
                      _msgController.text.isNotEmpty ? _msgController.text : "Follow up reminder",
                    );
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$method scheduled for ${scheduledDate.toString()}'),
                        backgroundColor: accentColor,
                      ),
                    );
                  } on ApiException catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.message), backgroundColor: Colors.red),
                    );
                  }
                },
                child: Text('Schedule', style: TextStyle(color: accentColor)),
              )
            ],
          )
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: Center(child: CircularProgressIndicator(color: accentColor)),
      );
    }

    // Safely unwrap stats
    final joinDate = _stats?.joinDate ?? "N/A";
    final totalVisits = _stats?.totalVisits ?? 0;
    final ltv = _stats?.lifetimeValue ?? 0.0;
    final lastArrival = _stats?.lastArrival ?? "N/A";
    final planBadge = _stats?.planBadge ?? "No Plan - \$0.00";
    final status = _stats?.status.toUpperCase() ?? "UNKNOWN";
    final isExpired = status == "EXPIRED";

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white54),
            onPressed: _loadData,
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: accentColor,
        backgroundColor: cardColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              SizedBox(height: 20),
              
              // --- Avatar & Upload ---
              Center(
                child: GestureDetector(
                  onTap: _uploadAvatar,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: cardColor,
                        backgroundImage: _avatarImage,
                        child: _avatarImage == null
                            ? Text(
                                widget.memberName.isNotEmpty ? widget.memberName[0] : 'U',
                                style: TextStyle(
                                  color: accentColor,
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: accentColor,
                          child: Icon(Icons.camera_alt, color: Colors.white, size: 16),
                        ),
                      )
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),

              if (_statsError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Text(
                    _statsError!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.redAccent, fontSize: 13),
                  ),
                ),
              if (_statsError != null) SizedBox(height: 12),

              // --- Name & Status Chip ---
              Text(
                widget.memberName,
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: isExpired ? Colors.red.withOpacity(0.1) : accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isExpired ? Colors.red : accentColor),
                ),
                child: Text(
                  status, 
                  style: TextStyle(color: isExpired ? Colors.red : accentColor, fontWeight: FontWeight.bold)
                ),
              ),
              SizedBox(height: 12),
              Text(
                planBadge,
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              
              SizedBox(height: 40),
              
              // --- Stats Grid ---
              // --- Redesigned Stat Cards ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: _buildStatCards(),
              ),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AttendanceHistoryScreen(
                          gymId: _gymId,
                          memberId: _memberId,
                          memberName: widget.member?.memberName ?? '',
                        ),
                      ),
                    ),
                    child: Text('View Attendance →',
                        style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w500)),
                  ),
                ),
              ),

              SizedBox(height: 12),

              // --- Last Reminder Card ---
              _buildLastReminderCard(),

              SizedBox(height: 24),

              // --- Communication Buttons ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _triggerQuickReminder('WHATSAPP'),
                        icon: Icon(Icons.chat, size: 16),
                        label: Text("WhatsApp", style: TextStyle(fontSize: 14)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cardColor,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: Colors.white24),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    SizedBox(width: 15),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _triggerQuickReminder('AI_CALL'),
                        icon: Icon(Icons.phone, size: 16),
                        label: Text("AI Call", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 40),

              // --- Renew Membership Button ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final planId = widget.member?.membershipTypeId;
                      if (planId == null || planId.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('No membership plan on file to renew with'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }
                      try {
                        await ApiService.renewMembership(_gymId, _memberId, planId);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Membership renewed'), backgroundColor: accentColor),
                        );
                        _loadData();
                      } on ApiException catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
                        );
                      }
                    },
                    icon: Icon(Icons.autorenew),
                    label: Text("Renew Membership", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cardColor,
                      foregroundColor: accentColor,
                      side: BorderSide(color: accentColor),
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLastReminderCard() {
    print('Building reminder card. hasReminder: ${_reminderHistory.isNotEmpty}, isLoading: $_isLoading');

    final last = _reminderHistory.isNotEmpty ? _reminderHistory.first : null;
    final Color borderColor = last == null
        ? Colors.white24
        : (last.paidAfterReminder ? AppColors.accent : Colors.redAccent);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12, width: 1),
      ),
      clipBehavior: Clip.antiAlias, // Ensures the left-strip rounds correctly
      child: Stack(
        children: [
          // 4px Accent Strip on the LEFT
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 4,
              color: borderColor,
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1 — Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 8.0), // Give space from the strip
                      child: Text('🔔 Last Reminder',
                          style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                    if (last != null)
                      Text(_getTimeAgo(last.scheduledDate),
                          style: const TextStyle(color: Colors.white38, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 10),

                // Row 2 — Details or empty state
                Padding(
                  padding: const EdgeInsets.only(left: 8.0), // Padding from the strip
                  child: last == null
                      ? const Center(
                          child: Text('No reminders sent yet',
                              style: TextStyle(color: Colors.white38, fontSize: 13, fontStyle: FontStyle.italic)),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(last.method.toLowerCase() == 'whatsapp' ? '📱 WhatsApp' : '📞 AI Call',
                                style: const TextStyle(color: Colors.white70, fontSize: 13)),
                            Text(last.paidAfterReminder ? '💰 Paid after ✅' : 'Unpaid ❌',
                                style: TextStyle(
                                  color: last.paidAfterReminder ? AppColors.accent : Colors.redAccent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                )),
                          ],
                        ),
                ),

                const SizedBox(height: 10),

                // View History link
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReminderHistoryScreen(
                          gymId: _gymId,
                          memberId: _memberId,
                        ),
                      ),
                    ),
                    child: const Text('View History →',
                        style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w500)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCards() {
    final summary = _attendanceSummary;
    
    String formatDate(dynamic val) {
      if (val == null) return 'N/A';
      final dt = val is DateTime ? val : DateTime.tryParse(val.toString());
      if (dt == null) return 'N/A';
      return DateFormat('MMM d, yyyy').format(dt);
    }

    String formatLastArrival(DateTime? dt) {
      if (dt == null) return 'N/A';
      final now = DateTime.now();
      final difference = now.difference(dt).inDays;
      if (difference == 0) return 'Today, ${DateFormat('h:mm a').format(dt)}';
      if (difference == 1) return 'Yesterday';
      return '${difference}d ago';
    }

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.1,
      children: [
        _statCard('📅', 'Join Date', formatDate(widget.member?.joinDate)),
        _statCard('🏃', 'Total Visits', '${summary?.totalVisits ?? 0}'),
        _statCard('💰', 'Lifetime Value', '₹${summary?.ltv.toStringAsFixed(2) ?? '0.00'}'),
        _statCard('🕐', 'Last Arrival', formatLastArrival(summary?.lastArrival)),
      ],
    );
  }

  Widget _statCard(String emoji, String label, String value) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
              textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
