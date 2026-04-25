import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/case_media.dart';
import '../models/case_record.dart';

const _indexVersion = 1;

/// Local case attachments: files under app support `media/` and index at `media/index.json`.
class CaseMediaService extends ChangeNotifier {
  CaseMediaService._();
  static final CaseMediaService instance = CaseMediaService._();
  factory CaseMediaService() => instance;

  static const _uuid = Uuid();

  String? _mediaRoot;
  String? _indexPath;
  List<CaseMedia> _items = [];
  bool _inited = false;

  /// True after [init] completed (or no-op on web).
  bool get isInitialized => _inited;

  Future<void> init() async {
    if (kIsWeb) {
      _inited = true;
      return;
    }
    if (_inited) return;
    final root = await getApplicationSupportDirectory();
    _mediaRoot = p.join(root.path, 'media');
    _indexPath = p.join(_mediaRoot!, 'index.json');
    await Directory(_mediaRoot!).create(recursive: true);
    await _loadIndex();
    _inited = true;
  }

  Future<void> _ensure() async {
    if (!_inited) await init();
  }

  Future<void> _loadIndex() async {
    final path = _indexPath;
    if (path == null) return;
    final f = File(path);
    if (!await f.exists()) {
      _items = [];
      return;
    }
    try {
      final raw = await f.readAsString();
      if (raw.trim().isEmpty) {
        _items = [];
        return;
      }
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final list = map['items'];
      if (list is! List) {
        _items = [];
        return;
      }
      _items = list
          .map((e) {
            try {
              return CaseMedia.fromJson(Map<String, dynamic>.from(e as Map));
            } catch (_) {
              return null;
            }
          })
          .whereType<CaseMedia>()
          .toList();
    } catch (_) {
      _items = [];
    }
  }

  Future<void> _writeIndex() async {
    final path = _indexPath;
    if (path == null) return;
    final map = {
      'version': _indexVersion,
      'items': _items.map((e) => e.toJson()).toList(),
    };
    final f = File(path);
    await f.writeAsString(const JsonEncoder.withIndent('  ').convert(map));
  }

  CaseRecord? _caseForId(String caseId) {
    final k = int.tryParse(caseId);
    if (k == null) return null;
    return Hive.box<CaseRecord>('cases').get(k);
  }

  String _safeSegment(String name) {
    return name.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_').trim();
  }

  /// Copies [file] into `media/[caseId]/[id]_[fileName]`, records metadata, updates Hive.
  Future<CaseMedia?> addMedia(
    String caseId,
    File file, {
    required CaseMediaType type,
    String? caption,
  }) async {
    if (kIsWeb) return null;
    await _ensure();
    final c = _caseForId(caseId);
    if (c == null) return null;
    if (!await file.exists()) return null;

    final id = _uuid.v4();
    final base = _mediaRoot!;
    final caseDir = Directory(p.join(base, caseId));
    await caseDir.create(recursive: true);
    final orig = _safeSegment(p.basename(file.path).isEmpty ? 'file' : p.basename(file.path));
    final destName = '${id}_$orig';
    final destPath = p.join(caseDir.path, destName);
    final copied = await file.copy(destPath);
    final len = await copied.length();
    String mime = lookupMimeType(destPath) ?? 'application/octet-stream';

    final media = CaseMedia(
      id: id,
      caseId: caseId,
      type: type,
      fileName: orig,
      filePath: destPath,
      fileSizeBytes: len,
      mimeType: mime,
      createdAt: DateTime.now(),
      caption: caption,
      isDownloaded: true,
    );
    _items = [..._items, media];
    await _writeIndex();
    c.mediaIds = [...c.mediaIds, id];
    await c.save();
    notifyListeners();
    return media;
  }

  /// All attachment records for a case, sorted by [CaseMedia.createdAt].
  List<CaseMedia> getMediaForCase(String caseId) {
    final list = _items.where((e) => e.caseId == caseId).toList();
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  CaseMedia? getById(String mediaId) {
    for (final m in _items) {
      if (m.id == mediaId) return m;
    }
    return null;
  }

  File getMediaFile(CaseMedia media) => File(media.filePath);

  Future<bool> deleteMedia(String mediaId, String caseId) async {
    if (kIsWeb) return false;
    await _ensure();
    final c = _caseForId(caseId);
    if (c == null) return false;
    final m = getById(mediaId);
    if (m == null) return false;
    if (m.caseId != caseId) return false;
    try {
      final f = File(m.filePath);
      if (await f.exists()) {
        await f.delete();
      }
    } catch (_) {}
    _items = _items.where((e) => e.id != mediaId).toList();
    await _writeIndex();
    c.mediaIds = c.mediaIds.where((id) => id != mediaId).toList();
    await c.save();
    notifyListeners();
    return true;
  }

  int getTotalMediaSize() {
    return _items.fold<int>(0, (s, m) => s + m.fileSizeBytes);
  }

  /// For PDF: optional small image bytes (under 500 KB); null on web, wrong type, or I/O error.
  Future<Uint8List?> readBytesForPdfThumbnail(CaseMedia m) async {
    if (kIsWeb) return null;
    if (m.type != CaseMediaType.image || m.fileSizeBytes >= 500 * 1024) {
      return null;
    }
    try {
      final f = File(m.filePath);
      if (!await f.exists()) return null;
      return await f.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  /// Existing files for sharing or export (skips missing paths).
  List<File> exportMediaForCase(String caseId) {
    final out = <File>[];
    for (final m in getMediaForCase(caseId)) {
      final f = File(m.filePath);
      if (f.existsSync()) {
        out.add(f);
      }
    }
    return out;
  }

  /// Removes all files under `media/` and clears [CaseRecord.mediaIds] for every case. Case text unchanged.
  Future<void> clearAllMedia() async {
    if (kIsWeb) return;
    await _ensure();
    final box = Hive.box<CaseRecord>('cases');
    for (final k in box.keys) {
      final r = box.get(k);
      if (r == null) continue;
      if (r.mediaIds.isNotEmpty) {
        r.mediaIds = [];
        await r.save();
      }
    }
    final root = _mediaRoot;
    if (root != null) {
      final dir = Directory(root);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      await Directory(root).create(recursive: true);
    }
    _indexPath = p.join(_mediaRoot!, 'index.json');
    _items = [];
    await _writeIndex();
    notifyListeners();
  }
}
