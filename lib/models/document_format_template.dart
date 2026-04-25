import 'dart:io';

import 'package:path/path.dart' as p;

import '../constants/document_format_ids.dart';
import 'scanned_field_data.dart';

/// Hardcoded definitions for the two app-shipped PDF formats (IDs: [DocumentFormatIds.fir], [DocumentFormatIds.gir]).
/// These are merged with persisted usage stats in [DocumentFormatService] on each init.
abstract final class PrebuiltDocumentFormats {
  PrebuiltDocumentFormats._();

  // --- FIR (First Information Report) ---
  static const String firName = 'FIR';
  static const String firHeaderLine = 'FIRST INFORMATION REPORT';
  static const String firSubtitle = 'KPK Police Department';
  static const int firAccentArgb = 0xFF3399FF; // #3399FF

  // --- Investigation Report (id remains prebuilt_gir for saved cases) ---
  static const String investigationReportName = 'Investigation Report';
  static const String investigationHeaderLine = 'INVESTIGATION REPORT';
  static const String investigationSubtitle = 'Office of the Investigation Officer — KPK';
  static const int investigationAccentArgb = 0xFF0A1929; // #0A1929
}

/// User-defined or pre-built PDF layout.
class DocumentFormatTemplate {
  final String id;
  final String name;
  final DocumentFormatKind kind;
  final DateTime createdAt;
  final bool isSystem;
  final int usageCount;
  final DateTime? lastUsedAt;

  /// Relative to app documents directory, e.g. `format_scans/<id>.jpg`
  final String? imageRelativePath;

  /// Custom title lines (pre-built + custom in-app)
  final String? titleLine1;
  final String? titleLine2;

  /// ARGB color for accents (dividers, badge)
  final int accentColorArgb;

  /// Show the Case # chip on the right of the header row
  final bool showCaseBadge;

  /// Fillable text regions on a scanned image (only [DocumentFormatKind.scan]).
  final List<ScannedFieldData> scannedFields;

  const DocumentFormatTemplate({
    required this.id,
    required this.name,
    required this.kind,
    required this.createdAt,
    this.isSystem = false,
    this.usageCount = 0,
    this.lastUsedAt,
    this.imageRelativePath,
    this.titleLine1,
    this.titleLine2,
    this.accentColorArgb = 0xFF3399FF,
    this.showCaseBadge = true,
    this.scannedFields = const [],
  });

  bool get isScan => kind == DocumentFormatKind.scan;
  bool get isCustom => kind == DocumentFormatKind.custom;

  File? imageFile(String appDocumentsPath) {
    if (imageRelativePath == null) return null;
    return File(p.join(appDocumentsPath, imageRelativePath!));
  }

  DocumentFormatTemplate copyWith({
    int? usageCount,
    DateTime? lastUsedAt,
    List<ScannedFieldData>? scannedFields,
  }) {
    return DocumentFormatTemplate(
      id: id,
      name: name,
      kind: kind,
      createdAt: createdAt,
      isSystem: isSystem,
      usageCount: usageCount ?? this.usageCount,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      imageRelativePath: imageRelativePath,
      titleLine1: titleLine1,
      titleLine2: titleLine2,
      accentColorArgb: accentColorArgb,
      showCaseBadge: showCaseBadge,
      scannedFields: scannedFields ?? this.scannedFields,
    );
  }

  /// App default: FIR. Cannot be deleted; content from [PrebuiltDocumentFormats].
  static DocumentFormatTemplate systemFir() {
    return DocumentFormatTemplate(
      id: DocumentFormatIds.fir,
      name: PrebuiltDocumentFormats.firName,
      kind: DocumentFormatKind.custom,
      createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      isSystem: true,
      titleLine1: PrebuiltDocumentFormats.firHeaderLine,
      titleLine2: PrebuiltDocumentFormats.firSubtitle,
      accentColorArgb: PrebuiltDocumentFormats.firAccentArgb,
      showCaseBadge: true,
      scannedFields: const [],
    );
  }

  /// App default: Investigation Report. Cannot be deleted; content from [PrebuiltDocumentFormats].
  static DocumentFormatTemplate systemInvestigationReport() {
    return DocumentFormatTemplate(
      id: DocumentFormatIds.gir,
      name: PrebuiltDocumentFormats.investigationReportName,
      kind: DocumentFormatKind.custom,
      createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      isSystem: true,
      titleLine1: PrebuiltDocumentFormats.investigationHeaderLine,
      titleLine2: PrebuiltDocumentFormats.investigationSubtitle,
      accentColorArgb: PrebuiltDocumentFormats.investigationAccentArgb,
      showCaseBadge: true,
      scannedFields: const [],
    );
  }

  /// Keeps [persisted] usage; applies canonical header lines from [canonical].
  static DocumentFormatTemplate mergeSystemWithPersisted(
    DocumentFormatTemplate canonical,
    DocumentFormatTemplate persisted,
  ) {
    return DocumentFormatTemplate(
      id: canonical.id,
      name: canonical.name,
      kind: canonical.kind,
      createdAt: canonical.createdAt,
      isSystem: true,
      usageCount: persisted.usageCount,
      lastUsedAt: persisted.lastUsedAt,
      imageRelativePath: null,
      titleLine1: canonical.titleLine1,
      titleLine2: canonical.titleLine2,
      accentColorArgb: canonical.accentColorArgb,
      showCaseBadge: canonical.showCaseBadge,
      scannedFields: const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'createdAt': createdAt.toIso8601String(),
        'isSystem': isSystem,
        'usageCount': usageCount,
        'lastUsedAt': lastUsedAt?.toIso8601String(),
        'imageRelativePath': imageRelativePath,
        'titleLine1': titleLine1,
        'titleLine2': titleLine2,
        'accentColorArgb': accentColorArgb,
        'showCaseBadge': showCaseBadge,
        'scannedFields': scannedFields.map((e) => e.toJson()).toList(),
      };

  static DocumentFormatTemplate fromJson(Map<String, dynamic> j) {
    final kindName = j['kind'] as String? ?? 'custom';
    final kind = DocumentFormatKind.values.firstWhere(
      (e) => e.name == kindName,
      orElse: () => DocumentFormatKind.custom,
    );
    DateTime? lastUsed;
    if (j['lastUsedAt'] != null) {
      lastUsed = DateTime.tryParse(j['lastUsedAt'] as String);
    }
    List<ScannedFieldData> fields = const [];
    final rawFields = j['scannedFields'] as List<dynamic>?;
    if (rawFields != null && rawFields.isNotEmpty) {
      fields = rawFields
          .map(
            (e) => ScannedFieldData.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    }
    return DocumentFormatTemplate(
      id: j['id'] as String,
      name: j['name'] as String,
      kind: kind,
      createdAt: DateTime.parse(j['createdAt'] as String),
      isSystem: j['isSystem'] as bool? ?? false,
      usageCount: (j['usageCount'] as num?)?.toInt() ?? 0,
      lastUsedAt: lastUsed,
      imageRelativePath: j['imageRelativePath'] as String?,
      titleLine1: j['titleLine1'] as String?,
      titleLine2: j['titleLine2'] as String?,
      accentColorArgb: (j['accentColorArgb'] as num?)?.toInt() ?? 0xFF3399FF,
      showCaseBadge: j['showCaseBadge'] as bool? ?? true,
      scannedFields: fields,
    );
  }
}

enum DocumentFormatKind { scan, custom }
