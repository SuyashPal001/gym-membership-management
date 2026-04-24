class StaffMember {
  final String? id;
  final String name;
  final String? phone;
  final String role;
  final double monthlySalary;
  final String status;
  final String? joinDate;
  final String? todayAttendance;
  final String? checkInTime;

  StaffMember({
    this.id,
    required this.name,
    this.phone,
    required this.role,
    required this.monthlySalary,
    required this.status,
    this.joinDate,
    this.todayAttendance,
    this.checkInTime,
  });

  factory StaffMember.fromJson(Map<String, dynamic> json) {
    return StaffMember(
      id: json['id']?.toString(),
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString(),
      role: json['role']?.toString() ?? 'Other',
      monthlySalary: double.tryParse(json['monthly_salary']?.toString() ?? '') ?? 0,
      status: json['status']?.toString() ?? 'active',
      joinDate: json['join_date']?.toString(),
      todayAttendance: json['today_attendance']?.toString(),
      checkInTime: json['check_in_time']?.toString(),
    );
  }

  StaffMember copyWith({String? todayAttendance, String? checkInTime}) {
    return StaffMember(
      id: id, name: name, phone: phone, role: role,
      monthlySalary: monthlySalary, status: status, joinDate: joinDate,
      todayAttendance: todayAttendance ?? this.todayAttendance,
      checkInTime: checkInTime ?? this.checkInTime,
    );
  }
}

class DayAttendance {
  final String date;
  final String? status;

  DayAttendance({required this.date, this.status});

  factory DayAttendance.fromJson(Map<String, dynamic> json) {
    return DayAttendance(
      date: json['date']?.toString() ?? '',
      status: json['status']?.toString(),
    );
  }
}

class StaffSalaryInfo {
  final double amount;
  final bool paid;
  final String? paidAt;
  final String month;

  StaffSalaryInfo({required this.amount, required this.paid, this.paidAt, required this.month});

  factory StaffSalaryInfo.fromJson(Map<String, dynamic> json) {
    return StaffSalaryInfo(
      amount: double.tryParse(json['amount']?.toString() ?? '') ?? 0,
      paid: json['paid'] == true,
      paidAt: json['paid_at']?.toString(),
      month: json['month']?.toString() ?? '',
    );
  }
}

class StaffStats {
  final StaffMember staff;
  final int daysPresent;
  final int totalWorkingDays;
  final StaffSalaryInfo salary;
  final List<DayAttendance> last7Days;

  StaffStats({
    required this.staff,
    required this.daysPresent,
    required this.totalWorkingDays,
    required this.salary,
    required this.last7Days,
  });

  factory StaffStats.fromJson(Map<String, dynamic> json) {
    return StaffStats(
      staff: StaffMember.fromJson(json['staff']),
      daysPresent: (json['days_present'] as num?)?.toInt() ?? 0,
      totalWorkingDays: (json['total_working_days'] as num?)?.toInt() ?? 0,
      salary: StaffSalaryInfo.fromJson(json['salary']),
      last7Days: (json['last_7_days'] as List)
          .map((e) => DayAttendance.fromJson(e))
          .toList(),
    );
  }
}
