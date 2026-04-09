class PaymentSummary {
  final String id;
  final String memberName;
  final String phone;
  final bool paymentCollected;
  final double lifetimeValue;
  final String? expiryDate;
  final String status;
  final String planName;
  final double planAmount;

  PaymentSummary({
    required this.id,
    required this.memberName,
    required this.phone,
    required this.paymentCollected,
    required this.lifetimeValue,
    this.expiryDate,
    required this.status,
    required this.planName,
    required this.planAmount,
  });

  factory PaymentSummary.fromJson(Map<String, dynamic> json) {
    final membership = json['MembershipType'] as Map<String, dynamic>?;

    String? fmtDate(dynamic v) {
      if (v == null) return null;
      final s = v.toString();
      if (s.length >= 10 && RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(s)) {
        return s.substring(0, 10);
      }
      return s;
    }

    return PaymentSummary(
      id: json['id'],
      memberName: json['member_name'],
      phone: json['phone'] ?? '',
      paymentCollected: json['payment_collected'] ?? false,
      lifetimeValue: (json['lifetime_value'] ?? 0).toDouble(),
      expiryDate: fmtDate(json['expiry_date']),
      status: json['status'] ?? 'expired',
      planName: membership?['name'] ?? 'No Plan',
      planAmount: (membership?['amount'] ?? 0).toDouble(),
    );
  }
}
