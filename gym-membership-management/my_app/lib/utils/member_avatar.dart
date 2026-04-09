import 'dart:convert';
import 'package:flutter/painting.dart';
import '../config/api_config.dart';

/// Builds an [ImageProvider] for member photos: `http(s)`, server path `/uploads/...`, or raw base64.
ImageProvider? memberAvatarImageProvider(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  
  final s = raw.trim();
  if (s.startsWith('http')) return NetworkImage(s);
  
  // Handle relative server paths (e.g., /uploads/avatars/...)
  if (s.startsWith('/')) {
    final baseUrl = ApiConfig.apiOrigin;
    return NetworkImage('$baseUrl$s');
  }

  // Handle base64 (removes data URI prefix if present)
  try {
    String base64Str = s;
    if (s.contains(';base64,')) {
      base64Str = s.split(';base64,').last;
    }
    return MemoryImage(base64Decode(base64Str));
  } catch (_) {
    return null;
  }
}
