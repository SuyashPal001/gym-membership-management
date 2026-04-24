class MembershipType {
  final String id;
  final String name;
  final double amount;
  final int durationMonths;

  MembershipType({
    required this.id,
    required this.name,
    required this.amount,
    required this.durationMonths,
  });

  factory MembershipType.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final name = json['name']?.toString() ?? '';
    final amountRaw = json['amount'];
    final amount = amountRaw is num
        ? amountRaw.toDouble()
        : double.tryParse(amountRaw?.toString() ?? '') ?? 0.0;
    final durRaw = json['duration_months'];
    final durationMonths = durRaw is int
        ? durRaw
        : (durRaw is num ? durRaw.round() : int.tryParse(durRaw?.toString() ?? '') ?? 1);

    return MembershipType(
      id: id,
      name: name,
      amount: amount,
      durationMonths: durationMonths,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'duration_months': durationMonths,
    };
  }
}

class Member {
  final String? id;
  final String? gymId;
  final String memberName;
  final String phone;
  final String? email;
  final String? membershipTypeId;
  final String? joinDate;
  final String? expiryDate;
  final String status;
  final bool isTrial;
  final bool paymentCollected;
  final int totalVisits;
  final double lifetimeValue;
  final MembershipType? membershipType;

  Member({
    this.id,
    this.gymId,
    required this.memberName,
    required this.phone,
    this.email,
    this.membershipTypeId,
    this.joinDate,
    this.expiryDate,
    this.status = 'active',
    this.isTrial = false,
    this.paymentCollected = false,
    this.totalVisits = 0,
    this.lifetimeValue = 0,
    this.membershipType,
  });

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      id: json['id'],
      gymId: json['gym_id'] ?? '',
      memberName: json['member_name'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'],
      membershipTypeId: json['membership_type_id'],
      joinDate: json['join_date'],
      expiryDate: json['expiry_date'],
      status: json['status'] ?? 'active',
      isTrial: json['is_trial'] ?? false,
      paymentCollected: json['payment_collected'] ?? false,
      totalVisits: json['total_visits'] ?? 0,
      lifetimeValue: (json['lifetime_value'] ?? 0).toDouble(),
      membershipType: json['MembershipType'] != null 
          ? MembershipType.fromJson(json['MembershipType']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'gym_id': gymId,
      'member_name': memberName,
      'phone': phone,
      'email': email,
      'membership_type_id': membershipTypeId,
      'is_trial': isTrial,
      'payment_collected': paymentCollected,
    };
  }
}
