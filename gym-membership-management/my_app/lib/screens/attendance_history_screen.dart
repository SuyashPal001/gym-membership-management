import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/attendance_session.dart';
import '../services/api_exception.dart';
import '../services/api_service.dart';
import '../constants/app_colors.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  final String gymId;
  final String memberId;
  final String memberName;

  const AttendanceHistoryScreen({
    Key? key,
    required this.gymId,
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
      _sessions = await ApiService.fetchAttendanceHistory(widget.gymId, widget.memberId);
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "${widget.memberName}'s Attendance",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryText),
            ),
            if (!_isLoading && _error == null)
              Text(
                "${_sessions.length} sessions total",
                style: const TextStyle(fontSize: 13, color: AppColors.secondaryText, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primaryText),
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
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // Date Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  dateMonth.toUpperCase(),
                  style: const TextStyle(color: AppColors.background, fontSize: 10, fontWeight: FontWeight.bold),
                ),
                Text(
                  dateDay,
                  style: const TextStyle(color: AppColors.background, fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // Times
          Expanded(
            child: Row(
              children: [
                Text(
                  checkInStr,
                  style: const TextStyle(color: AppColors.primaryText, fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: Icon(Icons.arrow_forward, size: 14, color: AppColors.secondaryText),
                ),
                Text(
                  checkOutStr,
                  style: TextStyle(
                    color: session.checkOutTime == null ? AppColors.accent : AppColors.primaryText,
                    fontSize: 14,
                    fontWeight: session.checkOutTime == null ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Duration Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              durationStr,
              style: const TextStyle(color: AppColors.secondaryText, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
