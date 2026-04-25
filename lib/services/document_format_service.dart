import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/document_format_ids.dart';
import '../models/case_record.dart';
import '../models/document_format_template.dart';
import '../models/scanned_field_data.dart';

/// Stores PDF header templates, usage stats, and optional global default. Pre-built FIR/GIR are always present.
class DocumentFormatService extends ChangeNotifier {
  DocumentFormatService._();
  static final DocumentFormatService instance = DocumentFormatService._();
  factory DocumentFormatService() => instance;

  static const _keyList = 'doc_format_templates_v1';
  static const _keyActive = 'doc_format_active_id_v1';
  static const _scanSubdir = 'format_scans';

  final List<DocumentFormatTemplate> _list = [];
  String? _activeId;
  String? _docPath;
  bool _ready = false;

  bool get isReady => _ready;
  String? get activeId => _activeId;
  List<DocumentFormatTemplate> get templates => List.unmodifiable(_allSorted());

  DocumentFormatTemplate? get activeTemplate {
    if (_activeId == null) return null;
    return getById(_activeId);
  }

  String get documentsPath {
    if (_docPath == null) throw StateError('DocumentFormatService not initialized');
    return _docPath!;
  }

  /// PDF format for a saved case: non-empty [CaseRecord.caseFormatId] → template; empty → plain default PDF (no format).
  DocumentFormatTemplate? templateForCaseExport(CaseRecord record) {
    final id = record.caseFormatId;
    if (id.isEmpty) return null;
    return getById(id);
  }

  DocumentFormatTemplate? getById(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final e in _list) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// Top 3 by last use (excludes those never used).
  List<DocumentFormatTemplate> get recentlyUsedForPicker {
    final withTime = _list.where((e) => e.lastUsedAt != null).toList();
    withTime.sort((a, b) => b.lastUsedAt!.compareTo(a.lastUsedAt!));
    return withTime.take(3).toList();
  }

  /// All formats: most-used first ([usageCount] desc), then name.
  List<DocumentFormatTemplate> _allSorted() {
    final withMeta = _list.toList();
    withMeta.sort((a, b) {
      final c = b.usageCount.compareTo(a.usageCount);
      if (c != 0) return c;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return withMeta;
  }

  Future<void> init() async {
    if (_ready) return;
    final dir = await getApplicationDocumentsDirectory();
    _docPath = dir.path;
    final prefs = await SharedPreferences.getInstance();
    _activeId = prefs.getString(_keyActive);
    final raw = prefs.getString(_keyList);
    if (raw != null) {
      final decoded = jsonDecode(raw) as List<dynamic>;
      _list
        ..clear()
        ..addAll(
          decoded.map(
            (e) => DocumentFormatTemplate.fromJson(Map<String, dynamic>.from(e as Map)),
          ),
        );
    }
    _ensurePrebuilt();
    _pruneMissingScans();
    _ready = true;
    await _savePrefs();
    notifyListeners();
  }

  void _ensurePrebuilt() {
    final iFir = _list.indexWhere((e) => e.id == DocumentFormatIds.fir);
    final cFir = DocumentFormatTemplate.systemFir();
    if (iFir < 0) {
      _list.add(cFir);
    } else {
      _list[iFir] = DocumentFormatTemplate.mergeSystemWithPersisted(cFir, _list[iFir]);
    }

    final iInv = _list.indexWhere((e) => e.id == DocumentFormatIds.gir);
    final cInv = DocumentFormatTemplate.systemInvestigationReport();
    if (iInv < 0) {
      _list.add(cInv);
    } else {
      _list[iInv] = DocumentFormatTemplate.mergeSystemWithPersisted(cInv, _list[iInv]);
    }
  }

  void _pruneMissingScans() {
    for (var i = _list.length - 1; i >= 0; i--) {
      final t = _list[i];
      if (t.isScan) {
        final f = t.imageFile(_docPath!);
        if (f == null || !f.existsSync()) {
          if (!t.isSystem && _activeId == t.id) _activeId = null;
          if (!t.isSystem) {
            _list.removeAt(i);
          }
        }
      }
    }
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyList, jsonEncode(_list.map((e) => e.toJson()).toList()));
    if (_activeId != null) {
      await prefs.setString(_keyActive, _activeId!);
    } else {
      await prefs.remove(_keyActive);
    }
  }

  /// Picker / selection only: updates [lastUsedAt] for “Recently used” (does not bump [usageCount]).
  Future<void> recordFormatPicked(String id) async {
    await init();
    if (id.isEmpty) return;
    final i = _list.indexWhere((e) => e.id == id);
    if (i < 0) return;
    final e = _list[i];
    _list[i] = e.copyWith(lastUsedAt: DateTime.now());
    await _savePrefs();
    notifyListeners();
  }

  /// When a case is saved with a format: increment usage and last-used.
  Future<void> recordFormatUsedInSavedCase(String id) async {
    await init();
    if (id.isEmpty) return;
    final i = _list.indexWhere((e) => e.id == id);
    if (i < 0) return;
    final e = _list[i];
    _list[i] = e.copyWith(
      usageCount: e.usageCount + 1,
      lastUsedAt: DateTime.now(),
    );
    await _savePrefs();
    notifyListeners();
  }

  Future<DocumentFormatTemplate?> addFromScan({
    required String name,
    required XFile xfile,
  }) async {
    await init();
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final scanDir = Directory(p.join(_docPath!, _scanSubdir));
    if (!await scanDir.exists()) await scanDir.create(recursive: true);
    final rel = p.join(_scanSubdir, '$id.jpg');
    final dest = File(p.join(_docPath!, rel));
    await File(xfile.path).copy(dest.path);
    final t = DocumentFormatTemplate(
      id: id,
      name: name.trim().isEmpty ? 'Scanned format' : name.trim(),
      kind: DocumentFormatKind.scan,
      createdAt: DateTime.now(),
      imageRelativePath: rel.replaceAll('\\', '/'),
    );
    _list.add(t);
    await _savePrefs();
    notifyListeners();
    return t;
  }

  Future<DocumentFormatTemplate> addCustom({
    required String name,
    required String titleLine1,
    String? titleLine2,
    int accentColorArgb = 0xFF3399FF,
    bool showCaseBadge = true,
  }) async {
    await init();
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final t = DocumentFormatTemplate(
      id: id,
      name: name.trim().isEmpty ? 'Custom format' : name.trim(),
      kind: DocumentFormatKind.custom,
      createdAt: DateTime.now(),
      titleLine1: titleLine1.trim(),
      titleLine2: titleLine2?.trim().isEmpty == true ? null : titleLine2?.trim(),
      accentColorArgb: accentColorArgb,
      showCaseBadge: showCaseBadge,
    );
    _list.add(t);
    await _savePrefs();
    notifyListeners();
    return t;
  }

  /// Replaces the fillable field definitions for a user scan format (not system).
  Future<void> setScannedFieldDefinitions(String id, List<ScannedFieldData> fields) async {
    await init();
    if (id == DocumentFormatIds.fir || id == DocumentFormatIds.gir) return;
    final i = _list.indexWhere((e) => e.id == id);
    if (i < 0) return;
    final e = _list[i];
    if (e.isSystem || !e.isScan) return;
    _list[i] = e.copyWith(scannedFields: List<ScannedFieldData>.from(fields));
    await _savePrefs();
    notifyListeners();
  }

  Future<void> setActive(String? id) async {
    await init();
    if (id != null && getById(id) == null) return;
    _activeId = id;
    await _savePrefs();
    notifyListeners();
  }

  Future<void> deleteById(String id) async {
    await init();
    if (id == DocumentFormatIds.fir || id == DocumentFormatIds.gir) return;
    DocumentFormatTemplate? t;
    for (final e in _list) {
      if (e.id == id) {
        t = e;
        break;
      }
    }
    if (t == null || t.isSystem) return;
    if (t.isScan) {
      final f = t.imageFile(_docPath!);
      if (f != null && await f.exists()) {
        try {
          await f.delete();
        } catch (_) {}
      }
    }
    _list.removeWhere((e) => e.id == id);
    if (_activeId == id) _activeId = null;
    await _savePrefs();
    notifyListeners();
  }
}
