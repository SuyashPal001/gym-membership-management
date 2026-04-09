import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/reminder_models.dart';
import '../services/api_exception.dart';
import '../services/api_service.dart';

class ReminderHistoryScreen extends StatefulWidget {
  final String gymId;
  final String memberId;

  const ReminderHistoryScreen({
    Key? key,
    required this.gymId,
    required this.memberId,
  }) : super(key: key);

  @override
  _ReminderHistoryScreenState createState() => _ReminderHistoryScreenState();
}

class _ReminderHistoryScreenState extends State<ReminderHistoryScreen> {
  List<ReminderHistory> _history = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final history = await ApiService.fetchReminderHistory(widget.gymId, widget.memberId);
      if (mounted) {
        setState(() {
          _history = history;
          _isLoading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text("Reminder History", style: TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: AppColors.primaryText),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _error != null
              ? _buildErrorView()
              : _history.isEmpty
                  ? _buildEmptyView()
                  : _buildListView(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.secondaryText),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _fetchHistory,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: Text("Retry", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Text(
        "No reminder history for this member",
        style: TextStyle(color: AppColors.secondaryText),
      ),
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      padding: EdgeInsets.all(20),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final r = _history[index];
        final isAiCall = r.method == 'AI_CALL';
        final date = _formatDate(r.scheduledDate);

        return Container(
          margin: EdgeInsets.only(bottom: 16),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        isAiCall ? Icons.phone_android : Icons.chat_bubble_outline,
                        color: isAiCall ? AppColors.accent : Colors.blueAccent,
                        size: 20,
                      ),
                      SizedBox(width: 12),
                      Text(
                        isAiCall ? "AI Call" : "WhatsApp",
                        style: TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Text(date, style: TextStyle(color: AppColors.secondaryText, fontSize: 13)),
                ],
              ),
              SizedBox(height: 12),
              Divider(color: Colors.white10),
              SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    r.paidAfterReminder ? Icons.check_circle : Icons.cancel,
                    color: r.paidAfterReminder ? AppColors.accent : Colors.redAccent.withOpacity(0.5),
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Text(
                    r.paidAfterReminder ? "Paid after reminder" : "No payment recorded",
                    style: TextStyle(
                      color: r.paidAfterReminder ? AppColors.accent : AppColors.secondaryText,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
      return "${months[dt.month - 1]} ${dt.day}, ${dt.year}";
    } catch (_) {
      return dateStr;
    }
  }
}
