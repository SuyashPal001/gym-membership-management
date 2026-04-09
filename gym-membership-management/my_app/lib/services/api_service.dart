import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/crm_models.dart';
import '../models/member.dart';
import '../models/payment_models.dart';
import '../models/reminder_models.dart';
import '../models/attendance_summary.dart';
import '../models/attendance_session.dart';
import 'api_exception.dart';

class ApiService {
  static String get baseUrl => ApiConfig.baseUrl;

  static String get defaultGymId => ApiConfig.defaultGymId;

  static const Duration _timeout = Duration(seconds: 5);

  // ─── Reminder Operations ───────────────────────────────────────────────────

  static Future<void> postReminder(String gymId, String memberId, String method) async {
    final uri = Uri.parse('$baseUrl/reminders/$gymId/$memberId');
    try {
      final response = await _post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'method': method}),
      );
      if (response.statusCode == 201) return;
      throw ApiException(
        _errorMessage(response.body, 'Failed to schedule reminder'),
        response.statusCode,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      _throwUnreachable(uri, e);
    }
  }

  static Future<List<ReminderHistory>> fetchReminderHistory(String gymId, String memberId) async {
    final uri = Uri.parse('$baseUrl/reminders/$gymId/history').replace(queryParameters: {'member_id': memberId});
    try {
      final response = await _get(uri);
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List list = data['data'];
        if (list is! List) throw ApiException('Invalid history response');
        return list.map((e) => ReminderHistory.fromJson(e as Map<String, dynamic>)).toList();
      }
      throw ApiException(
        _errorMessage(response.body, 'Failed to load reminder history'),
        response.statusCode,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      _throwUnreachable(uri, e);
    }
  }

  // ─── Payment Operations ──────────────────────────────────────────────────────

  static Future<List<PaymentSummary>> fetchPaymentSummaries({
    String? gymId,
    String? expiryFilter,
  }) async {
    final targetGymId = gymId ?? defaultGymId;
    final query = expiryFilter != null ? {'expiry_filter': expiryFilter} : null;
    final uri = Uri.parse('$baseUrl/payments/$targetGymId').replace(queryParameters: query);
    
    try {
      final response = await _get(uri);
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List list = data['data'];
        return list.map((e) => PaymentSummary.fromJson(e as Map<String, dynamic>)).toList();
      }
      throw ApiException(
        _errorMessage(response.body, 'Failed to load payments'),
        response.statusCode,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      _throwUnreachable(uri, e);
    }
  }

  static Future<void> markPaymentAsPaid({
    String? gymId,
    required String memberId,
  }) async {
    final targetGymId = gymId ?? defaultGymId;
    final uri = Uri.parse('$baseUrl/payments/$targetGymId/$memberId');
    
    try {
      final response = await http.patch(uri).timeout(_timeout);
      if (response.statusCode == 200) return;
      throw ApiException(
        _errorMessage(response.body, 'Failed to update payment'),
        response.statusCode,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      _throwUnreachable(uri, e);
    }
  }

  static Future<void> sendPaymentReminder({
    String? gymId,
    required String memberId,
    required String amount,
  }) async {
    // Uses existing manual reminder endpoint
    return createManualReminder(
      gymId ?? defaultGymId,
      memberId,
      'WHATSAPP',
      DateTime.now(),
      'Kindly settle your outstanding payment of ₹$amount to continue your access.',
    );
  }

  // Existing methods follow...

  static Future<http.Response> _get(Uri uri) async {
    try {
      return await http.get(uri).timeout(_timeout);
    } on TimeoutException {
      throw ApiException(
        'Timed out after ${_timeout.inSeconds}s (no reply).\n\n${_connectivityHint()}',
      );
    }
  }

  static Future<http.Response> _post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    try {
      return await http.post(uri, headers: headers, body: body).timeout(_timeout);
    } on TimeoutException {
      throw ApiException(
        'Timed out after ${_timeout.inSeconds}s.\n\n${_connectivityHint()}',
      );
    }
  }

  static Future<http.Response> _delete(Uri uri) async {
    try {
      return await http.delete(uri).timeout(_timeout);
    } on TimeoutException {
      throw ApiException(
        'Timed out after ${_timeout.inSeconds}s.\n\n${_connectivityHint()}',
      );
    }
  }

  static Future<http.StreamedResponse> _sendMultipart(http.MultipartRequest request) async {
    try {
      return await request.send().timeout(_timeout);
    } on TimeoutException {
      throw ApiException(
        'Timed out after ${_timeout.inSeconds}s.\n\n${_connectivityHint()}',
      );
    }
  }

  static String _connectivityHint() {
    if (kIsWeb) {
      return 'Web: check CORS and API URL (${ApiConfig.baseUrl}).';
    }
    return 'Current URL: ${ApiConfig.baseUrl}\n\n'
        '${ApiConfig.networkTroubleshootHint}';
  }

  static Never _throwUnreachable(Uri uri, Object e) {
    throw ApiException(
      '${ApiConfig.describeRequestFailure(e, uri)}\n\n${_connectivityHint()}',
    );
  }

  static String _errorMessage(String body, [String fallback = 'Request failed']) {
    try {
      final map = json.decode(body);
      if (map is Map) {
        final msg = map['message'];
        if (msg is String && msg.isNotEmpty) return msg;
      }
    } catch (_) {}
    return fallback;
  }

  // ─── Membership Types ─────────────────────────────────────────────────────────

  static Future<List<MembershipType>> fetchMembershipTypes() async {
    final uri = Uri.parse('$baseUrl/members/membership-types');
    try {
      final response = await _get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final list = data['data'];
        if (list is! List) {
          throw ApiException('Invalid membership types response');
        }
        return list
            .map((e) => MembershipType.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw ApiException(
        _errorMessage(response.body, 'Failed to load membership types'),
        response.statusCode,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      _throwUnreachable(uri, e);
    }
  }

  // ─── Members ──────────────────────────────────────────────────────────────────

  static Future<List<Member>> fetchMembers(String gymId, {Map<String, String>? filters}) async {
    final uri = Uri.parse('$baseUrl/members/$gymId').replace(queryParameters: filters);
    try {
      final response = await _get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final list = data['data'];
        if (list is! List) {
          throw ApiException('Invalid members response');
        }
        return list
            .map((e) => Member.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw ApiException(
        _errorMessage(response.body, 'Failed to load members'),
        response.statusCode,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      _throwUnreachable(uri, e);
    }
  }

  static Future<Member> enrollMember(Member member) async {
    final uri = Uri.parse('$baseUrl/members');
    try {
      final response = await _post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(member.toJson()),
      );
      if (response.statusCode == 201) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return Member.fromJson(data['data'] as Map<String, dynamic>);
      }
      throw ApiException(
        _errorMessage(response.body, 'Failed to enroll member'),
        response.statusCode,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      _throwUnreachable(uri, e);
    }
  }

  static Future<bool> deleteMember(String gymId, String memberId) async {
    final uri = Uri.parse('$baseUrl/members/$gymId/$memberId');
    try {
      final response = await _delete(uri);
      return response.statusCode == 200;
    } catch (e) {
      _throwUnreachable(uri, e);
    }
  }

  static Future<Member> renewMembership(
    String gymId,
    String memberId,
    String membershipTypeId,
  ) async {
    final uri = Uri.parse('$baseUrl/members/$gymId/$memberId/renew');
    try {
      final response = await _post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'membership_type_id': membershipTypeId}),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return Member.fromJson(data['data'] as Map<String, dynamic>);
      }
      throw ApiException(
        _errorMessage(response.body, 'Failed to renew membership'),
        response.statusCode,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      _throwUnreachable(uri, e);
    }
  }

  // ─── Member Profile Integration ──────────────────────────────────────────────

  static Future<MemberStats> fetchMemberStats(String gymId, String memberId) async {
    final uri = Uri.parse('$baseUrl/members/$gymId/$memberId/stats');
    try {
      final response = await _get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return MemberStats.fromJson(data['data'] as Map<String, dynamic>);
      }
      throw ApiException(
        _errorMessage(response.body, 'Failed to load stats'),
        response.statusCode,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      _throwUnreachable(uri, e);
    }
  }

  static Future<String> uploadAvatar(String gymId, String memberId, String filepath) async {
    final uri = Uri.parse('$baseUrl/members/$gymId/$memberId/avatar');
    try {
      final request = http.MultipartRequest('POST', uri)
        ..files.add(await http.MultipartFile.fromPath('avatar', filepath));
      final res = await _sendMultipart(request);
      final respStr = await res.stream.bytesToString().timeout(_timeout);
      if (res.statusCode == 200) {
        final data = json.decode(respStr) as Map<String, dynamic>;
        final inner = data['data'] as Map<String, dynamic>?;
        final url = inner?['avatarUrl'] as String?;
        if (url != null && url.isNotEmpty) return url;
        throw ApiException('Invalid avatar response');
      }
      throw ApiException(_errorMessage(respStr, 'Avatar upload failed'), res.statusCode);
    } on ApiException {
      rethrow;
    } catch (e) {
      if (e is TimeoutException) {
        throw ApiException(
          'Timed out reading response.\n\n${_connectivityHint()}',
        );
      }
      _throwUnreachable(uri, e);
    }
  }

  static Future<void> createManualReminder(
    String gymId,
    String memberId,
    String method,
    DateTime scheduledDate,
    String message,
  ) async {
    final uri = Uri.parse('$baseUrl/members/$gymId/$memberId/reminders/manual');
    try {
      final response = await _post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'method': method,
          'scheduled_date': scheduledDate.toUtc().toIso8601String(),
          'payload': method == 'WHATSAPP'
              ? {'message': message}
              : {'guestName': 'Member', 'type': message}
        }),
      );
      if (response.statusCode == 201) return;
      throw ApiException(
        _errorMessage(response.body, 'Failed to schedule reminder'),
        response.statusCode,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      _throwUnreachable(uri, e);
    }
  }

  // ─── Attendance Operations ──────────────────────────────────────────────────

  static Future<List<AttendanceSession>> fetchLiveAttendance(String gymId) async {
    final uri = Uri.parse('$baseUrl/attendance/$gymId/today');
    try {
      final response = await _get(uri);
      print("RAW LIVE ATTENDANCE RESPONSE: ${response.statusCode} - ${response.body}");
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final currentlyIn = data['data']?['currently_in'];
        if (currentlyIn is! List) throw ApiException('Invalid live attendance response');
        return currentlyIn.map((e) => AttendanceSession.fromJson(e as Map<String, dynamic>)).toList();
      }
      throw ApiException(
        _errorMessage(response.body, 'Failed to load live attendance'),
        response.statusCode,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      _throwUnreachable(uri, e);
    }
  }

  static Future<AttendanceSummary> fetchAttendanceSummary(String gymId, String memberId) async {
    final uri = Uri.parse('$baseUrl/members/$gymId/$memberId/attendance-summary');
    try {
      final response = await _get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return AttendanceSummary.fromJson(data['data'] as Map<String, dynamic>);
      }
      throw ApiException(
        _errorMessage(response.body, 'Failed to load attendance summary'),
        response.statusCode,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      _throwUnreachable(uri, e);
    }
  }

  static Future<List<AttendanceSession>> fetchAttendanceHistory(String gymId, String memberId) async {
    final uri = Uri.parse('$baseUrl/members/$gymId/$memberId/attendance-history');
    try {
      final response = await _get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final list = data['data'];
        if (list is! List) throw ApiException('Invalid attendance history response');
        return list.map((e) => AttendanceSession.fromJson(e as Map<String, dynamic>)).toList();
      }
      throw ApiException(
        _errorMessage(response.body, 'Failed to load attendance history'),
        response.statusCode,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      _throwUnreachable(uri, e);
    }
  }
  static Future<List<dynamic>> scanLedger(String base64Image) async {
    final uri = Uri.parse('$baseUrl/ai/scan-book');
    try {
      final response = await _post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'image': base64Image}),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return data['data'] as List<dynamic>;
      }
      throw ApiException(
        _errorMessage(response.body, 'AI Scan Failed'),
        response.statusCode,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      _throwUnreachable(uri, e);
    }
  }
}
