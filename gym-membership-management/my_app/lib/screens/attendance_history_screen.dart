import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/attendance_session.dart';
import '../services/api_exception.dart';
import '../services/api_service.dart';
import '../constants/app_colors.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  final String memberId;
  final String memberName;

  const AttendanceHistoryScreen({
    Key? key,
    required this.memberId,
    required this.memberName,
  }) : super(key: key);

  @override
  State<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  List<AttendanceSession> _sessions = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      _sessions = await ApiService.fetchMemberAttendanceHistory(widget.memberId);
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Failed to load attendance history';
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
        title: Text(
          "${widget.memberName.toUpperCase()}'S ATTENDANCE",
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: const TextStyle(color: AppColors.secondaryText)),
                      TextButton(
                        onPressed: _loadHistory,
                        child: const Text('Retry', style: TextStyle(color: AppColors.accent)),
                      ),
                    ],
                  ),
                )
              : _sessions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.event_busy, size: 48, color: AppColors.secondaryText),
                          const SizedBox(height: 12),
                          const Text(
                            "No attendance records yet",
                            style: TextStyle(color: AppColors.secondaryText, fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: _sessions.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        return _buildSessionCard(_sessions[index]);
                      },
                    ),
    );
  }

  Widget _buildSessionCard(AttendanceSession session) {
    final dateMonth = DateFormat('MMM').format(session.checkInTime);
    final dateDay = DateFormat('d').format(session.checkInTime);
    final checkInStr = DateFormat('h:mm a').format(session.checkInTime);
    final checkOutStr = session.checkOutTime != null ? DateFormat('h:mm a').format(session.checkOutTime!) : 'Active';

    String durationStr = '--';
    if (session.durationMinutes != null) {
      final hours = session.durationMinutes! ~/ 60;
      final mins = session.durationMinutes! % 60;
      durationStr = hours > 0 ? '${hours}h ${mins}m' : '${mins}m';
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Date Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primaryBlue.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                Text(
                  dateMonth.toUpperCase(),
                  style: const TextStyle(color: AppColors.primaryBlue, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                ),
                Text(
                  dateDay,
                  style: const TextStyle(color: AppColors.primaryBlue, fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),

          // Times
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      checkInStr,
                      style: const TextStyle(color: AppColors.primaryText, fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10.0),
                      child: Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.secondaryText),
                    ),
                    Text(
                      checkOutStr,
                      style: TextStyle(
                        color: session.checkOutTime == null ? AppColors.primaryBlue : AppColors.primaryText,
                        fontSize: 15,
                        fontWeight: session.checkOutTime == null ? FontWeight.w900 : FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                if (session.checkOutTime == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text("SESSION IN PROGRESS", style: TextStyle(color: AppColors.primaryBlue, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                  ),
              ],
            ),
          ),

          // Duration Pill
          if (session.checkOutTime != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer_outlined, size: 12, color: AppColors.secondaryText),
                  SizedBox(width: 4),
                  Text(
                    durationStr == '--' ? '...' : durationStr,
                    style: const TextStyle(color: AppColors.secondaryText, fontSize: 11, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
