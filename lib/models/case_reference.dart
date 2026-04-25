import 'package:hive/hive.dart';
import 'case_record.dart';

/// Helpers for optional [CaseRecord.caseReferenceNo] and auto-generated KPK refs.
class CaseReference {
  CaseReference._();

  static String formatAuto(int sequence, int year) {
    return 'KPK/$year/${sequence.toString().padLeft(3, '0')}';
  }

  /// Resolves display/PDF reference: stored custom ref, or legacy auto from chronological position.
  static String resolve(CaseRecord record, Box<CaseRecord> box) {
    final custom = record.caseReferenceNo.trim();
    if (custom.isNotEmpty) return custom;

    final sorted = box.values.toList()
      ..sort((a, b) => a.savedAt.compareTo(b.savedAt));
    final key = record.key;
    var pos = 1;
    for (var i = 0; i < sorted.length; i++) {
      if (sorted[i].key == key) {
        pos = i + 1;
        break;
      }
    }
    return formatAuto(pos, record.savedAt.year);
  }
}
