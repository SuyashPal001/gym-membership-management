class PaymentSummary {
  final String id;
  final String memberName;
  final String phone;
  final bool paymentCollected;
  final double lifetimeValue;
  final String? expiryDate;
  final String? joinDate;
  final String status;
  final String planName;
  final double planAmount;
  final bool hasMembershipPlan;
  final String lifecycleType;
  final String primaryAction;
  final String displayPlanName;
  final double? displayAmount;
  final String urgencyLabel;

  PaymentSummary({
    required this.id,
    required this.memberName,
    required this.phone,
    required this.paymentCollected,
    required this.lifetimeValue,
    this.expiryDate,
    this.joinDate,
    required this.status,
    required this.planName,
    required this.planAmount,
    required this.hasMembershipPlan,
    required this.lifecycleType,
    required this.primaryAction,
    required this.displayPlanName,
    required this.displayAmount,
    required this.urgencyLabel,
  });

  factory PaymentSummary.fromJson(Map<String, dynamic> json) {
    final membership = json['MembershipType'] as Map<String, dynamic>?;
    final status = json['status'] as String? ?? 'expired';
    final planName = membership?['name'] as String? ?? 'No Plan';
    final planAmount = (membership?['amount'] ?? 0).toDouble();
    final lifetimeValue = (json['lifetime_value'] ?? 0).toDouble();

    String? fmtDate(dynamic v) {
      if (v == null) return null;
      final s = v.toString();
      if (s.length >= 10 && RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(s)) {
        return s.substring(0, 10);
      }
      return s;
    }

    final expiryDate = fmtDate(json['expiry_date']);
    final joinDate = fmtDate(json['join_date']);

    int? dayDiff() {
      if (expiryDate == null) return null;
      final exp = DateTime.tryParse(expiryDate);
      if (exp == null) return null;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      return exp.difference(today).inDays;
    }

    String computedLifecycleType() {
      if (status == 'trial') return 'trial';
      if (membership != null) return 'plan_due';
      return 'unplanned';
    }

    // Derive display fields from core data when backend doesn't send them yet.
    String computedDisplayPlanName() {
      if (status == 'trial') {
        final diff = dayDiff();
        if (diff == null) return 'ON TRIAL';
        if (diff < 0) return 'TRIAL ENDED';
        return 'ON TRIAL';
      }
      if (planName.toLowerCase().contains('no plan')) return 'NO PLAN';
      final match = RegExp(r'(\d+)\s*-?\s*MONTH', caseSensitive: false).firstMatch(planName);
      if (match != null) return '${match.group(1)} MONTH';
      return planName.toUpperCase();
    }

    String computedUrgencyLabel() {
      final diff = dayDiff();
      if (status == 'trial') {
        if (diff == null || diff >= 0) return 'TRIAL ONGOING';
        final days = diff.abs();
        return 'TRIAL OVERDUE $days ${days == 1 ? 'DAY' : 'DAYS'}';
      }
      if (diff == null) return 'NO EXPIRY';
      if (lifetimeValue == 0) {
        final enrolled = joinDate != null ? DateTime.tryParse(joinDate) : null;
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final overdueDays = enrolled != null
            ? today.difference(DateTime(enrolled.year, enrolled.month, enrolled.day)).inDays
            : 0;
        if (overdueDays == 0) return 'DUE TODAY';
        return 'OVERDUE $overdueDays ${overdueDays == 1 ? 'DAY' : 'DAYS'}';
      }
      if (diff == 0) return 'DUE TODAY';
      if (diff == 1) return 'DUE TOMORROW';
      if (diff < 0) {
        final days = diff.abs();
        return 'OVERDUE $days ${days == 1 ? 'DAY' : 'DAYS'}';
      }
      if (diff < 31) return 'DUE IN $diff DAYS';
      return expiryDate ?? 'NO EXPIRY';
    }

    return PaymentSummary(
      id: json['id'],
      memberName: json['member_name'],
      phone: json['phone'] ?? '',
      paymentCollected: json['payment_collected'] ?? false,
      lifetimeValue: lifetimeValue,
      expiryDate: expiryDate,
      joinDate: joinDate,
      status: status,
      planName: planName,
      planAmount: planAmount,
      hasMembershipPlan: json['has_membership_plan'] as bool? ?? membership != null,
      lifecycleType: json['lifecycle_type'] as String? ?? computedLifecycleType(),
      primaryAction: json['primary_action'] as String? ?? (status == 'trial' ? 'convert' : 'mark_paid'),
      displayPlanName: (json['display_plan_name'] == null || json['display_plan_name'].toString().trim().isEmpty || json['display_plan_name'] == '_') 
          ? computedDisplayPlanName() 
          : json['display_plan_name'].toString(),
      displayAmount: json['display_amount'] != null
          ? (json['display_amount'] as num).toDouble()
          : (status != 'trial' ? planAmount : null),
      urgencyLabel: json['urgency_label'] as String? ?? computedUrgencyLabel(),
    );
  }
}

class MemberPayment {
  final String id;
  final double amount;
  final String status;
  final String paymentDate;
  final String? method;
  final String? planName;
  final int? durationMonths;

  MemberPayment({
    required this.id,
    required this.amount,
    required this.status,
    required this.paymentDate,
    this.method,
    this.planName,
    this.durationMonths,
  });

  factory MemberPayment.fromJson(Map<String, dynamic> json) {
    final membership = json['MembershipType'] as Map<String, dynamic>?;
    return MemberPayment(
      id: json['id']?.toString() ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      status: json['status'] ?? 'paid',
      paymentDate: json['payment_date'] ?? '',
      method: json['method'],
      planName: membership?['name'] ?? json['plan_name'],
      durationMonths: membership?['duration_months'],
    );
  }
}
