class AttendanceSummary {
  final int totalVisits;
  final DateTime? lastArrival;
  final double ltv;

  AttendanceSummary({required this.totalVisits, this.lastArrival, required this.ltv});

  factory AttendanceSummary.fromJson(Map<String, dynamic> json) {
    return AttendanceSummary(
      totalVisits: json['total_visits'] ?? 0,
      lastArrival: json['last_arrival'] != null ? DateTime.parse(json['last_arrival']) : null,
      ltv: (json['ltv'] ?? 0).toDouble(),
    );
  }
}
