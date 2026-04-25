import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists the home "new case" form so work survives app kills (field + offline-friendly).
/// Aligned with common practice for mobile data-capture tools (save-as-you-type with debounce on UI).
class HomeDraftService {
  HomeDraftService._();
  static const _key = 'police_home_draft_v1';
  static const _unset = '__format_unset__';

  static String _encodeFormat(String? id) {
    if (id == null) return _unset;
    return id;
  }

  static String? _decodeFormat(String stored) {
    if (stored == _unset) return null;
    return stored;
  }

  static Future<void> save({
    required String reference,
    required String heading,
    required String details,
    required String headingFontName,
    required String paragraphFontName,
    required String? sessionFormatId,
    String? sessionScannedFieldValuesJson,
  }) async {
    final emptyText =
        reference.isEmpty && heading.isEmpty && details.isEmpty;
    if (emptyText && sessionFormatId == null) {
      await clear();
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final map = <String, dynamic>{
      'v': 1,
      'reference': reference,
      'heading': heading,
      'details': details,
      'hFont': headingFontName,
      'pFont': paragraphFontName,
      'format': _encodeFormat(sessionFormatId),
      if (sessionScannedFieldValuesJson != null && sessionScannedFieldValuesJson.isNotEmpty)
        'scannedV': sessionScannedFieldValuesJson,
    };
    await prefs.setString(_key, jsonEncode(map));
  }

  static Future<HomeDraftSnapshot?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final formatRaw = m['format'] as String? ?? _unset;
      return HomeDraftSnapshot(
        reference: m['reference'] as String? ?? '',
        heading: m['heading'] as String? ?? '',
        details: m['details'] as String? ?? '',
        headingFontName: m['hFont'] as String? ?? 'Inter',
        paragraphFontName: m['pFont'] as String? ?? 'Inter',
        sessionFormatId: _decodeFormat(formatRaw),
        sessionScannedFieldValuesJson: m['scannedV'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

class HomeDraftSnapshot {
  final String reference;
  final String heading;
  final String details;
  final String headingFontName;
  final String paragraphFontName;
  /// `null` = user had not completed the format step; `''` = no format; else id.
  final String? sessionFormatId;
  final String? sessionScannedFieldValuesJson;

  const HomeDraftSnapshot({
    required this.reference,
    required this.heading,
    required this.details,
    required this.headingFontName,
    required this.paragraphFontName,
    required this.sessionFormatId,
    this.sessionScannedFieldValuesJson,
  });

  bool get hasWork =>
      reference.isNotEmpty ||
      heading.isNotEmpty ||
      details.isNotEmpty ||
      sessionFormatId != null ||
      (sessionScannedFieldValuesJson != null && sessionScannedFieldValuesJson!.isNotEmpty);
}
