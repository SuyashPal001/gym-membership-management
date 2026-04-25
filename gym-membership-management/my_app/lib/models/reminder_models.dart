class ReminderHistory {
  final String id;
  final String memberName;
  final String method;
  final String scheduledDate;
  final bool paidAfterReminder;

  ReminderHistory({
    required this.id,
    required this.memberName,
    required this.method,
    required this.scheduledDate,
    required this.paidAfterReminder,
  });

  factory ReminderHistory.fromJson(Map<String, dynamic> json) {
    // Note: memberName comes from the joined Member object in the response
    final member = json['Member'] as Map<String, dynamic>?;
    
    return ReminderHistory(
      id: json['uuid'] ?? json['id']?.toString() ?? '',
      memberName: member?['member_name'] ?? 'Unknown Member',
      method: json['method'] ?? 'SMS',
      scheduledDate: json['scheduled_date'] ?? '',
      paidAfterReminder: json['paid_after_reminder'] ?? false,
    );
  }
}
