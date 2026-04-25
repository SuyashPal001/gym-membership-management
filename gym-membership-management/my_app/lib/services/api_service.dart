import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/growth_models.dart';
import '../models/member.dart';
import '../models/staff_models.dart';
import '../models/payment_models.dart';
import '../models/reminder_models.dart';
import '../models/attendance_summary.dart';
import '../models/attendance_session.dart';
import '../services/auth_service.dart';
import 'api_exception.dart';

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}

class ApiService {
  static String get baseUrl => ApiConfig.baseUrl;
  static const Duration _timeout = Duration(seconds: 45);

  /// Helper to get authenticated headers.
  static Future<Map<String, String>> _getAuthHeaders() async {
    final token = await AuthService.getStoredToken();
    if (token == null) throw AuthException('Not authenticated');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ─── Intercepted Network Core (With Silent Refresh) ────────────────────────

  static Future<http.Response> _requestWithRetry(
    Future<http.Response> Function(Map<String, String> headers) requestFn,
  ) async {
    try {
      final headers = await _getAuthHeaders();
      var response = await requestFn(headers).timeout(_timeout);

      if (response.statusCode == 401) {
        final newToken = await AuthService.refreshToken();
        if (newToken != null) {
          final newHeaders = await _getAuthHeaders();
          response = await requestFn(newHeaders).timeout(_timeout);
        } else {
          await AuthService.signOut();
        }
      }
      return response;
    } catch (e) {
      if (e is AuthException) rethrow;
      _handleNetworkError(Uri.parse(baseUrl), e);
    }
    throw Exception('Request failed');
  }

  static Future<http.Response> _get(Uri uri) => _requestWithRetry((h) => http.get(uri, headers: h));
  static Future<http.Response> _post(Uri uri, {Object? body, Duration? timeout}) => _requestWithRetry((h) => http.post(uri, headers: h, body: body).timeout(timeout ?? _timeout));
  static Future<http.Response> _put(Uri uri, {Object? body}) => _requestWithRetry((h) => http.put(uri, headers: h, body: body).timeout(_timeout));
  static Future<http.Response> _delete(Uri uri) => _requestWithRetry((h) => http.delete(uri, headers: h).timeout(_timeout));

  // ─── Auth & Identity ───────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> fetchMe() async {
    final uri = Uri.parse('$baseUrl/auth/me');
    return _parseData(await _get(uri), 'Identity sync failed');
  }

  static Future<Map<String, dynamic>> setupGym(Map<String, dynamic> body) async {
    final uri = Uri.parse('$baseUrl/auth/setup');
    return _parseData(await _post(uri, body: json.encode(body)), 'Setup failed');
  }

  // ─── Gym Profile ────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> fetchGymProfile() async {
    final uri = Uri.parse('$baseUrl/gym');
    return _parseData(await _get(uri), 'Load failed');
  }

  static Future<void> updateGymProfile(Map<String, dynamic> updates) async {
    final uri = Uri.parse('$baseUrl/gym');
    final response = await _put(uri, body: json.encode(updates));
    if (response.statusCode != 200) throw ApiException('Update failed', response.statusCode);
  }

  static Future<void> deleteGymProfile() async {
    final uri = Uri.parse('$baseUrl/gym');
    final res = await _delete(uri);
    if (res.statusCode != 200) throw ApiException('Delete failed', res.statusCode);
  }

  // ─── Membership Types ───────────────────────────────────────────────────────

  static Future<List<MembershipType>> fetchMembershipTypes() async {
    final uri = Uri.parse('$baseUrl/members/membership-types');
    final data = _parseData(await _get(uri), 'Fetch failed');
    return (data as List).map((e) => MembershipType.fromJson(e)).toList();
  }

  // ─── Members ────────────────────────────────────────────────────────────────

  static Future<List<Member>> fetchMembers({Map<String, String>? filters}) async {
    final uri = Uri.parse('$baseUrl/members').replace(queryParameters: filters);
    final data = _parseData(await _get(uri), 'Fetch failed');
    return (data as List).map((e) => Member.fromJson(e)).toList();
  }

  static Future<GrowthData> fetchMemberGrowth() async {
    final uri = Uri.parse('$baseUrl/members/growth');
    return GrowthData.fromJson(_parseData(await _get(uri), 'Fetch failed'));
  }

  static Future<List<dynamic>> fetchAttentionMembers() async {
    final uri = Uri.parse('$baseUrl/members/attention');
    return _parseData(await _get(uri), 'Fetch failed');
  }

  static Future<Member> enrollMember(Member member) async {
    final uri = Uri.parse('$baseUrl/members');
    final data = _parseData(await _post(uri, body: json.encode(member.toJson())), 'Enrollment failed');
    return Member.fromJson(data);
  }

  static Future<void> deleteMember(String memberId) async {
    final uri = Uri.parse('$baseUrl/members/$memberId');
    final res = await _delete(uri);
    if (res.statusCode != 200) throw ApiException('Delete failed', res.statusCode);
  }

  static Future<Member> renewMembership(String memberId, String membershipTypeId) async {
    final uri = Uri.parse('$baseUrl/members/$memberId/renew');
    final data = _parseData(await _post(uri, body: json.encode({'membership_type_id': membershipTypeId})), 'Renew failed');
    return Member.fromJson(data);
  }

  static Future<void> updateMember(String memberId, Map<String, dynamic> updates) async {
    final uri = Uri.parse('$baseUrl/members/$memberId');
    final res = await _put(uri, body: json.encode(updates));
    if (res.statusCode != 200) throw ApiException('Update failed', res.statusCode);
  }

  // ─── Attendance ─────────────────────────────────────────────────────────────

  static Future<List<AttendanceSession>> fetchLiveAttendance() async {
    final uri = Uri.parse('$baseUrl/attendance/today');
    final data = _parseData(await _get(uri), 'Fetch failed');
    return (data['currently_in'] as List).map((e) => AttendanceSession.fromJson(e)).toList();
  }

  static Future<Map<String, dynamic>> fetchTodayAttendanceFull() async {
    final uri = Uri.parse('$baseUrl/attendance/today');
    return _parseData(await _get(uri), 'Fetch failed');
  }

  static Future<AttendanceSummary> fetchMemberAttendanceSummary(String memberId) async {
    final uri = Uri.parse('$baseUrl/members/$memberId/attendance-summary');
    return AttendanceSummary.fromJson(_parseData(await _get(uri), 'Fetch failed'));
  }

  static Future<List<AttendanceSession>> fetchMemberAttendanceHistory(String memberId) async {
    final uri = Uri.parse('$baseUrl/members/$memberId/attendance-history');
    final data = _parseData(await _get(uri), 'Fetch failed');
    return (data as List).map((e) => AttendanceSession.fromJson(e)).toList();
  }

  static Future<Map<String, dynamic>> manualCheckIn(String memberId) async {
    final uri = Uri.parse('$baseUrl/attendance/checkin');
    final res = await _post(uri, body: json.encode({'member_id': memberId}));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    throw ApiException(body['message'] ?? 'Check-in failed', res.statusCode);
  }

  // ─── Payments ───────────────────────────────────────────────────────────────


  static Future<List<PaymentSummary>> fetchPaymentSummaries({String? expiryFilter, bool paid = false}) async {
    final query = <String, String>{};
    if (expiryFilter != null) query['expiry_filter'] = expiryFilter;
    if (paid) query['paid'] = 'true';
    final uri = Uri.parse('$baseUrl/payments').replace(queryParameters: query.isEmpty ? null : query);
    final data = _parseData(await _get(uri), 'Fetch failed');
    return (data as List).map((e) => PaymentSummary.fromJson(e)).toList();
  }

  static Future<Map<String, dynamic>> fetchPaymentStats() async {
    final uri = Uri.parse('$baseUrl/payments/stats');
    return _parseData(await _get(uri), 'Fetch failed');
  }

  static Future<void> markPaymentAsPaid({required String memberId}) async {
    final uri = Uri.parse('$baseUrl/payments/$memberId');
    final response = await _post(uri);
    if (response.statusCode != 200) throw ApiException('Failed to mark payment as paid', response.statusCode);
  }

  static Future<List<MemberPayment>> fetchMemberPayments(String memberId) async {
    final uri = Uri.parse('$baseUrl/members/$memberId/payments');
    final data = _parseData(await _get(uri), 'Fetch failed');
    return (data as List).map((e) => MemberPayment.fromJson(e)).toList();
  }

  // ─── Reminders ──────────────────────────────────────────────────────────────

  static Future<void> postReminder(String memberId, String method) async {
    final uri = Uri.parse('$baseUrl/reminders/$memberId');
    final res = await _post(uri, body: json.encode({'method': method}));
    if (res.statusCode != 201 && res.statusCode != 200) throw ApiException('Reminder failed', res.statusCode);
  }

  static Future<List<ReminderHistory>> fetchReminderHistory(String memberId) async {
    final uri = Uri.parse('$baseUrl/reminders/history').replace(queryParameters: {'member_id': memberId});
    final data = _parseData(await _get(uri), 'Fetch failed');
    return (data as List).map((e) => ReminderHistory.fromJson(e)).toList();
  }


  // ─── AI & Voice ─────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> scanLedger(String imageBase64) async {
    final uri = Uri.parse('$baseUrl/ai/scan-book');
    final res = await _post(
      uri,
      body: json.encode({'imageBase64': imageBase64}),
      timeout: const Duration(seconds: 90),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    throw ApiException(body['message'] ?? 'Scan failed', res.statusCode);
  }

  static Future<Map<String, dynamic>> confirmLedgerScan(String scanId, List<dynamic> entries) async {
    final uri = Uri.parse('$baseUrl/ai/scan/$scanId/confirm');
    final res = await _post(uri, body: json.encode({'entries': entries}));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    throw ApiException(body['message'] ?? 'Confirmation failed', res.statusCode);
  }

  static Future<Map<String, dynamic>> startVoiceSession() async {
    final uri = Uri.parse('$baseUrl/voice/start');
    final res = await _post(uri);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    throw ApiException(body['message'] ?? 'Voice start failed', res.statusCode);
  }

  static Future<Map<String, dynamic>> sendVoiceMessage(
    String sessionId, String text, List<dynamic> history, {bool isHindi = false}) async {
    final uri = Uri.parse('$baseUrl/voice/message');
    final res = await _post(uri, body: json.encode({
      'session_id': sessionId,
      'text': text,
      'history': history,
      'language': isHindi ? 'hi' : 'en',
    }));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    throw ApiException(body['message'] ?? 'Message failed', res.statusCode);
  }

  static Future<Map<String, dynamic>> endVoiceSession(String sessionId) async {
    final uri = Uri.parse('$baseUrl/voice/end');
    final res = await _post(uri, body: json.encode({'session_id': sessionId}));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    throw ApiException(body['message'] ?? 'End failed', res.statusCode);
  }

  static Future<String> transcribeAudio(String audioBase64) async {
    final uri = Uri.parse('$baseUrl/voice/transcribe');
    final data = _parseData(await _post(uri, body: json.encode({'audioBase64': audioBase64, 'languageCode': 'hi-IN'})), 'Transcription failed');
    return data['text'] as String;
  }

  static Future<String> textToSpeech(String text, {bool isHindi = false}) async {
    final uri = Uri.parse('$baseUrl/voice/speak');
    final data = _parseData(await _post(uri, body: json.encode({
      'text': text,
      'languageCode': isHindi ? 'hi-IN' : 'en-IN',
    })), 'TTS failed');
    return data['audioBase64'] as String;
  }

  // ─── Staff ──────────────────────────────────────────────────────────────────

  static Future<List<StaffMember>> fetchStaff() async {
    final uri = Uri.parse('$baseUrl/staff');
    final data = _parseData(await _get(uri), 'Fetch failed');
    return (data as List).map((e) => StaffMember.fromJson(e)).toList();
  }

  static Future<StaffMember> addStaff(Map<String, dynamic> body) async {
    final uri = Uri.parse('$baseUrl/staff');
    final data = _parseData(await _post(uri, body: json.encode(body)), 'Add failed');
    return StaffMember.fromJson(data);
  }

  static Future<void> updateStaff(String id, Map<String, dynamic> body) async {
    final uri = Uri.parse('$baseUrl/staff/$id');
    final res = await _put(uri, body: json.encode(body));
    if (res.statusCode != 200) throw ApiException('Update failed', res.statusCode);
  }

  static Future<void> deleteStaff(String id) async {
    final uri = Uri.parse('$baseUrl/staff/$id');
    final res = await _delete(uri);
    if (res.statusCode != 200) throw ApiException('Delete failed', res.statusCode);
  }

  static Future<Map<String, dynamic>> toggleStaffAttendance(String id) async {
    final uri = Uri.parse('$baseUrl/staff/$id/attendance');
    return _parseData(await _post(uri), 'Toggle failed');
  }

  static Future<StaffStats> fetchStaffStats(String id) async {
    final uri = Uri.parse('$baseUrl/staff/$id/stats');
    return StaffStats.fromJson(_parseData(await _get(uri), 'Fetch failed'));
  }

  static Future<void> markStaffSalaryPaid(String id) async {
    final uri = Uri.parse('$baseUrl/staff/$id/salary/pay');
    final res = await _post(uri);
    if (res.statusCode != 200) throw ApiException('Payment failed', res.statusCode);
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  static dynamic _parseData(http.Response res, String fallback) {
    final body = jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) return body['data'];
    // Validator middleware returns {errors: [{field, message}]} instead of {message}
    String message = body['message'] ?? fallback;
    final errors = body['errors'];
    if (errors is List && errors.isNotEmpty) {
      message = (errors as List).map((e) => e['message']).join(', ');
    }
    throw ApiException(message, res.statusCode);
  }

  static void _handleNetworkError(Uri uri, dynamic e) {
    if (e is SocketException || e is TimeoutException) throw ApiException('Network connection error.', 0);
  }
}
