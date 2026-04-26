import 'dart:convert';

import 'package:hive/hive.dart';

class CaseRecord extends HiveObject {
  String heading;
  String details;
  String headingFont;
  String detailsFont;
  DateTime savedAt;
  String caseLanguage;
  int editCount;
  DateTime? lastEditedAt;
  /// Optional; empty means use [CaseReference.resolve] for display and legacy data.
  String caseReferenceNo;
  /// PDF format id for exports; empty = no format (plain default PDF header). Alias: [formatId].
  String caseFormatId;

  /// Human-readable format name at save time; empty when [caseFormatId] is empty. Used in UI/PDF if template missing.
  String caseFormatName;

  /// Filled text for [DocumentFormatTemplate.scannedFields] keys when using a scan format. Hive field 11.
  Map<String, String> scannedFieldValues;

  /// Local media attachment IDs; Hive field 12. See [CaseMedia] / [CaseMediaService].
  List<String> mediaIds;

  /// Built-in form field id → value; Hive field 13.
  Map<String, String> formFieldValues;

  /// Set when the case was created with a built-in paper form; matches [caseFormatId] for those cases. Hive field 14.
  String formId;

  CaseRecord({
    required this.heading,
    required this.details,
    required this.headingFont,
    required this.detailsFont,
    required this.savedAt,
    this.caseLanguage = 'en',
    this.editCount = 0,
    this.lastEditedAt,
    this.caseReferenceNo = '',
    this.caseFormatId = '',
    this.caseFormatName = '',
    Map<String, String>? scannedFieldValues,
    List<String>? mediaIds,
    Map<String, String>? formFieldValues,
    this.formId = '',
  })  : scannedFieldValues = Map<String, String>.from(scannedFieldValues ?? const {}),
        mediaIds = List<String>.from(mediaIds ?? const []),
        formFieldValues = Map<String, String>.from(formFieldValues ?? const {});

  /// Same as [caseFormatId] (spec alias).
  String get formatId => caseFormatId;

  bool get isUrdu => caseLanguage == 'ur';

  static List<String> _decodeMediaIdsFromHive(Object? v) {
    if (v == null) return [];
    if (v is String) {
      if (v.isEmpty) return [];
      try {
        final o = jsonDecode(v);
        if (o is List) {
          return o.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }
    if (v is List) {
      return v.map((e) => e.toString()).toList();
    }
    return [];
  }

  static Map<String, String> _decodeScannedMapFromHive(Object? v) {
    if (v == null) return {};
    if (v is String) {
      if (v.isEmpty) return {};
      try {
        final o = jsonDecode(v);
        if (o is Map) {
          return o.map((k, val) => MapEntry(k.toString(), val == null ? '' : val.toString()));
        }
      } catch (_) {}
    }
    return {};
  }

  String get preview {
    if (details.length <= 100) return details;
    return '${details.substring(0, 100)}...';
  }
}

class CaseRecordAdapter extends TypeAdapter<CaseRecord> {
  @override
  final int typeId = 0;

  @override
  CaseRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CaseRecord(
      heading: fields[0] as String,
      details: fields[1] as String,
      headingFont: fields[2] as String,
      detailsFont: fields[3] as String,
      savedAt: fields[4] as DateTime,
      caseLanguage: (fields[5] as String?) ?? 'en',
      editCount: (fields[6] as int?) ?? 0,
      lastEditedAt: fields[7] as DateTime?,
      caseReferenceNo: (fields[8] as String?) ?? '',
      caseFormatId: (fields[9] as String?) ?? '',
      caseFormatName: numOfFields > 10 ? (fields[10] as String?) ?? '' : '',
      scannedFieldValues: CaseRecord._decodeScannedMapFromHive(numOfFields > 11 ? fields[11] : null),
      mediaIds: numOfFields > 12 ? CaseRecord._decodeMediaIdsFromHive(fields[12]) : const <String>[],
      formFieldValues: CaseRecord._decodeScannedMapFromHive(numOfFields > 13 ? fields[13] : null),
      formId: numOfFields > 14 ? (fields[14] as String?) ?? '' : '',
    );
  }

  @override
  void write(BinaryWriter writer, CaseRecord obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.heading)
      ..writeByte(1)
      ..write(obj.details)
      ..writeByte(2)
      ..write(obj.headingFont)
      ..writeByte(3)
      ..write(obj.detailsFont)
      ..writeByte(4)
      ..write(obj.savedAt)
      ..writeByte(5)
      ..write(obj.caseLanguage)
      ..writeByte(6)
      ..write(obj.editCount)
      ..writeByte(7)
      ..write(obj.lastEditedAt)
      ..writeByte(8)
      ..write(obj.caseReferenceNo)
      ..writeByte(9)
      ..write(obj.caseFormatId)
      ..writeByte(10)
      ..write(obj.caseFormatName)
      ..writeByte(11)
      ..write(jsonEncode(obj.scannedFieldValues))
      ..writeByte(12)
      ..write(jsonEncode(obj.mediaIds))
      ..writeByte(13)
      ..write(jsonEncode(obj.formFieldValues))
      ..writeByte(14)
      ..write(obj.formId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CaseRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
