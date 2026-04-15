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

  CaseRecord({
    required this.heading,
    required this.details,
    required this.headingFont,
    required this.detailsFont,
    required this.savedAt,
    this.caseLanguage = 'en',
    this.editCount = 0,
    this.lastEditedAt,
  });

  bool get isUrdu => caseLanguage == 'ur';

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
    );
  }

  @override
  void write(BinaryWriter writer, CaseRecord obj) {
    writer
      ..writeByte(8)
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
      ..write(obj.lastEditedAt);
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
