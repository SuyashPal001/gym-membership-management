class AttendanceSession {
  final String id;
  final String gymId;
  final String memberId;
  final DateTime checkInTime;
  final DateTime? checkOutTime;
  final String date;
  final int? durationMinutes;
  final String? memberName;
  final String? avatar;

  AttendanceSession({
    required this.id,
    required this.gymId,
    required this.memberId,
    required this.checkInTime,
    this.checkOutTime,
    required this.date,
    this.durationMinutes,
    this.memberName,
    this.avatar,
  });

  factory AttendanceSession.fromJson(Map<String, dynamic> json) {
    return AttendanceSession(
      id: json['id'],
      gymId: json['gym_id'],
      memberId: json['member_id'],
      checkInTime: DateTime.parse(json['check_in_time']).toLocal(),
      checkOutTime: json['check_out_time'] != null ? DateTime.parse(json['check_out_time']).toLocal() : null,
      date: json['date'],
      durationMinutes: json['duration_minutes'],
      memberName: json['Member']?['member_name'],
      avatar: json['Member']?['avatar'],
    );
  }
}
