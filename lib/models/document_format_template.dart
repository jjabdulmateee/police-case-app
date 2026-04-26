import 'dart:io';

import 'package:path/path.dart' as p;

import '../constants/document_format_ids.dart';
import 'form_field_definition.dart';
import 'scanned_field_data.dart';

/// Hardcoded definitions for app-shipped PDF / built-in forms ([DocumentFormatIds]).
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

  // --- Supplementary Report (رپورٹ ضمنی) — Police Form 25-53(1) ---
  static const String supplementaryReportEnglish = 'Supplementary Report';
  static const String supplementaryReportUrdu = 'رپورٹ ضمنی';
  static const String supplementaryFormSubtitle = 'پولیس فارم ۲۵-۵۳(۱)';
  static const String supplementaryDocumentSubheader = 'پولیس فارم ۲۵-۵۳(۱) — حصہ اول (بیرونی)';
  static const String supplementaryDocumentSubheaderEnglish = 'Police Form 25-53(1) — Part 1 (External)';
  static const int supplementaryAccentArgb = 0xFF1A5276;
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

  /// Urdu name for list / UI (optional; e.g. Supplementary Report).
  final String? nameUrdu;

  /// Short subtitle, e.g. form number in Urdu.
  final String? formSubtitle;

  /// Second line under the main Urdu title on the paper form (optional).
  final String? formDocumentSubheaderUrdu;

  /// Second line under the English title (optional; e.g. Police Form part line).
  final String? formDocumentSubheaderEnglish;

  /// When non-empty, selecting this format opens [BuiltinFormScreen] instead of free-text home.
  final List<FormFieldDefinition> builtinFormFields;

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
    this.nameUrdu,
    this.formSubtitle,
    this.formDocumentSubheaderUrdu,
    this.formDocumentSubheaderEnglish,
    this.builtinFormFields = const [],
  });

  bool get isScan => kind == DocumentFormatKind.scan;
  bool get isCustom => kind == DocumentFormatKind.custom;

  /// True for system “paper” forms (e.g. Supplementary Report) with [builtinFormFields].
  bool get hasBuiltinFormFields => builtinFormFields.isNotEmpty;

  File? imageFile(String appDocumentsPath) {
    if (imageRelativePath == null) return null;
    return File(p.join(appDocumentsPath, imageRelativePath!));
  }

  DocumentFormatTemplate copyWith({
    int? usageCount,
    DateTime? lastUsedAt,
    List<ScannedFieldData>? scannedFields,
    List<FormFieldDefinition>? builtinFormFields,
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
      nameUrdu: nameUrdu,
      formSubtitle: formSubtitle,
      formDocumentSubheaderUrdu: formDocumentSubheaderUrdu,
      formDocumentSubheaderEnglish: formDocumentSubheaderEnglish,
      builtinFormFields: builtinFormFields ?? this.builtinFormFields,
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
      builtinFormFields: const [],
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
      builtinFormFields: const [],
    );
  }

  /// Supplementary Report (رپورٹ ضمنی) — Police Form 25-53(1). Cannot be deleted.
  static DocumentFormatTemplate systemSupplementaryReport() {
    return DocumentFormatTemplate(
      id: DocumentFormatIds.supplementaryZamni,
      name: PrebuiltDocumentFormats.supplementaryReportEnglish,
      kind: DocumentFormatKind.custom,
      createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      isSystem: true,
      titleLine1: PrebuiltDocumentFormats.supplementaryReportEnglish,
      titleLine2: PrebuiltDocumentFormats.supplementaryFormSubtitle,
      accentColorArgb: PrebuiltDocumentFormats.supplementaryAccentArgb,
      showCaseBadge: true,
      scannedFields: const [],
      nameUrdu: PrebuiltDocumentFormats.supplementaryReportUrdu,
      formSubtitle: PrebuiltDocumentFormats.supplementaryFormSubtitle,
      formDocumentSubheaderUrdu: PrebuiltDocumentFormats.supplementaryDocumentSubheader,
      formDocumentSubheaderEnglish: PrebuiltDocumentFormats.supplementaryDocumentSubheaderEnglish,
      builtinFormFields: supplementaryReportZamniFields(),
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
      nameUrdu: canonical.nameUrdu,
      formSubtitle: canonical.formSubtitle,
      formDocumentSubheaderUrdu: canonical.formDocumentSubheaderUrdu,
      formDocumentSubheaderEnglish: canonical.formDocumentSubheaderEnglish,
      builtinFormFields: List<FormFieldDefinition>.from(canonical.builtinFormFields),
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
        'nameUrdu': nameUrdu,
        'formSubtitle': formSubtitle,
        'formDocumentSubheaderUrdu': formDocumentSubheaderUrdu,
        'formDocumentSubheaderEnglish': formDocumentSubheaderEnglish,
        'builtinFormFields': builtinFormFields.map((e) => e.toJson()).toList(),
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
    List<FormFieldDefinition> builtin = const [];
    final rawB = j['builtinFormFields'] as List<dynamic>?;
    if (rawB != null && rawB.isNotEmpty) {
      builtin = rawB
          .map(
            (e) => FormFieldDefinition.fromJson(Map<String, dynamic>.from(e as Map)),
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
      nameUrdu: j['nameUrdu'] as String?,
      formSubtitle: j['formSubtitle'] as String?,
      formDocumentSubheaderUrdu: j['formDocumentSubheaderUrdu'] as String?,
      formDocumentSubheaderEnglish: j['formDocumentSubheaderEnglish'] as String?,
      builtinFormFields: builtin,
    );
  }
}

enum DocumentFormatKind { scan, custom }
