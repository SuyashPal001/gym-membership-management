class MonthlyGrowth {
  final String month;
  final String monthShort;
  final int newMembers;

  MonthlyGrowth({
    required this.month,
    required this.monthShort,
    required this.newMembers,
  });

  factory MonthlyGrowth.fromJson(Map<String, dynamic> json) {
    return MonthlyGrowth(
      month: json['month']?.toString() ?? '',
      monthShort: json['month_short']?.toString() ?? '',
      newMembers: (json['new_members'] as num?)?.toInt() ?? 0,
    );
  }
}

class GrowthTotals {
  final int total;
  final int active;
  final int trial;
  final int expired;
  final int inactive;
  final double totalLtv;

  GrowthTotals({
    required this.total,
    required this.active,
    required this.trial,
    required this.expired,
    required this.inactive,
    required this.totalLtv,
  });

  factory GrowthTotals.fromJson(Map<String, dynamic> json) {
    return GrowthTotals(
      total: (json['total'] as num?)?.toInt() ?? 0,
      active: (json['active'] as num?)?.toInt() ?? 0,
      trial: (json['trial'] as num?)?.toInt() ?? 0,
      expired: (json['expired'] as num?)?.toInt() ?? 0,
      inactive: (json['inactive'] as num?)?.toInt() ?? 0,
      totalLtv: (json['total_ltv'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class GrowthData {
  final List<MonthlyGrowth> monthly;
  final GrowthTotals totals;

  GrowthData({required this.monthly, required this.totals});

  factory GrowthData.fromJson(Map<String, dynamic> json) {
    return GrowthData(
      monthly: (json['monthly'] as List)
          .map((e) => MonthlyGrowth.fromJson(e))
          .toList(),
      totals: GrowthTotals.fromJson(json['totals']),
    );
  }
}
