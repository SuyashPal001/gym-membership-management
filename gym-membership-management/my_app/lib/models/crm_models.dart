class MemberStats {
  final String joinDate;
  final int totalVisits;
  final double lifetimeValue;
  final String status;
  final String? lastArrival;
  final String planBadge;

  MemberStats({
    required this.joinDate,
    required this.totalVisits,
    required this.lifetimeValue,
    required this.status,
    this.lastArrival,
    required this.planBadge,
  });

  factory MemberStats.fromJson(Map<String, dynamic> json) {
    String fmt(dynamic v) {
      if (v == null) return 'N/A';
      final s = v.toString();
      if (s.length >= 10 && RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(s)) {
        return s.substring(0, 10);
      }
      return s;
    }

    String? fmtOpt(dynamic v) {
      if (v == null) return null;
      return v.toString();
    }

    return MemberStats(
      joinDate: fmt(json['join_date']),
      totalVisits: json['total_visits'] ?? 0,
      lifetimeValue: (json['lifetime_value'] ?? 0).toDouble(),
      status: json['status'] ?? 'expired',
      lastArrival: fmtOpt(json['last_arrival']),
      planBadge: json['plan_badge'] ?? 'No Plan - ₹0.00',
    );
  }
}
