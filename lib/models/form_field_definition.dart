/// Layout width for a single [FormFieldDefinition] in a row.
enum FormColumnSpan { full, half, third }

/// Data shape for a built-in form field.
enum FormFieldType {
  /// Single line underline field.
  singleLine,

  /// Multi-line (same layout style with taller area).
  multiLine,

  /// Investigation-style table: notebook keys [tableNarrativeKey] / [tableSerialKey] / [tableDatetimeKey]; legacy per-row [formCellKey].
  table,
}

/// One column in a [FormFieldType.table] field.
class FormTableColumnDef {
  final String labelUrdu;
  final String labelEnglish;

  /// Proportions: wide first column uses 3, narrow use 1.
  final int flex;

  const FormTableColumnDef({
    required this.labelUrdu,
    required this.labelEnglish,
    this.flex = 1,
  });

  Map<String, dynamic> toJson() => {
        'u': labelUrdu,
        'e': labelEnglish,
        'f': flex,
      };

  static FormTableColumnDef fromJson(Map<String, dynamic> j) {
    return FormTableColumnDef(
      labelUrdu: j['u'] as String? ?? '',
      labelEnglish: j['e'] as String? ?? '',
      flex: (j['f'] as num?)?.toInt() ?? 1,
    );
  }
}

class FormFieldDefinition {
  final String id;
  final String labelUrdu;
  final String labelEnglish;
  final FormFieldType type;
  final bool isRequired;
  final int rowIndex;
  final FormColumnSpan columnSpan;
  final List<FormTableColumnDef>? tableColumns;
  final int tableRowCount;

  const FormFieldDefinition({
    required this.id,
    required this.labelUrdu,
    required this.labelEnglish,
    this.type = FormFieldType.singleLine,
    this.isRequired = false,
    this.rowIndex = 0,
    this.columnSpan = FormColumnSpan.full,
    this.tableColumns,
    this.tableRowCount = 0,
  });

  String labelForLanguage(bool urdu) => urdu ? labelUrdu : labelEnglish;

  Map<String, dynamic> toJson() => {
        'id': id,
        'u': labelUrdu,
        'e': labelEnglish,
        't': type.name,
        'req': isRequired,
        'ri': rowIndex,
        'cs': columnSpan.name,
        'tc': tableColumns?.map((e) => e.toJson()).toList(),
        'tr': tableRowCount,
      };

  static FormFieldDefinition fromJson(Map<String, dynamic> j) {
    final typeName = j['t'] as String? ?? 'singleLine';
    final type = FormFieldType.values.firstWhere(
      (e) => e.name == typeName,
      orElse: () => FormFieldType.singleLine,
    );
    final csName = j['cs'] as String? ?? 'full';
    final cs = FormColumnSpan.values.firstWhere(
      (e) => e.name == csName,
      orElse: () => FormColumnSpan.full,
    );
    List<FormTableColumnDef>? cols;
    final rawC = j['tc'] as List<dynamic>?;
    if (rawC != null) {
      cols = rawC
          .map(
            (e) => FormTableColumnDef.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    }
    return FormFieldDefinition(
      id: j['id'] as String,
      labelUrdu: j['u'] as String? ?? '',
      labelEnglish: j['e'] as String? ?? '',
      type: type,
      isRequired: j['req'] as bool? ?? false,
      rowIndex: (j['ri'] as num?)?.toInt() ?? 0,
      columnSpan: cs,
      tableColumns: cols,
      tableRowCount: (j['tr'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Cell storage key for table [tableId] at [row] / [col] (0-based); legacy [FormFieldType.table] rows.
String formCellKey(String tableId, int row, int col) => '${tableId}_r${row}_c$col';

/// Notebook layout: one ruled story column + two side note columns (replaces per-row [formCellKey] storage).
String tableNarrativeKey(String tableId) => '${tableId}_narrative';
String tableSerialKey(String tableId) => '${tableId}_serial';
String tableDatetimeKey(String tableId) => '${tableId}_datetime';

int _maxLegacyTableRowIndex(String tableId, Map<String, String> map) {
  var maxR = -1;
  final prefix = '${tableId}_r';
  for (final k in map.keys) {
    if (!k.startsWith(prefix)) continue;
    final rest = k.substring(prefix.length);
    final idx = rest.indexOf('_c');
    if (idx <= 0) continue;
    final r = int.tryParse(rest.substring(0, idx)) ?? -1;
    if (r > maxR) maxR = r;
  }
  return maxR;
}

String _joinLegacyTableColumn(String tableId, int col, Map<String, String> map) {
  final maxR = _maxLegacyTableRowIndex(tableId, map);
  if (maxR < 0) return '';
  final parts = <String>[];
  for (var r = 0; r <= maxR; r++) {
    final t = (map[formCellKey(tableId, r, col)] ?? '').trim();
    if (t.isNotEmpty) parts.add(t);
  }
  return parts.join('\n\n');
}

/// Circumstances text: new key or merged old row keys for column 0.
String resolveTableNarrative(String tableId, Map<String, String> map) {
  final d = (map[tableNarrativeKey(tableId)] ?? '').trim();
  if (d.isNotEmpty) return d;
  return _joinLegacyTableColumn(tableId, 0, map);
}

/// Serial / datetime columns: new key or legacy merge.
String resolveTableSerial(String tableId, Map<String, String> map) {
  final d = (map[tableSerialKey(tableId)] ?? '').trim();
  if (d.isNotEmpty) return d;
  return _joinLegacyTableColumn(tableId, 1, map);
}

String resolveTableDatetime(String tableId, Map<String, String> map) {
  final d = (map[tableDatetimeKey(tableId)] ?? '').trim();
  if (d.isNotEmpty) return d;
  return _joinLegacyTableColumn(tableId, 2, map);
}

/// Police Form 25-53(1) — Supplementary Report field layout.
List<FormFieldDefinition> supplementaryReportZamniFields() {
  return const [
    FormFieldDefinition(
      id: 'thana',
      labelUrdu: 'تھانہ',
      labelEnglish: 'Police Station',
      type: FormFieldType.singleLine,
      rowIndex: 1,
      columnSpan: FormColumnSpan.half,
    ),
    FormFieldDefinition(
      id: 'zila',
      labelUrdu: 'ضلع',
      labelEnglish: 'District',
      type: FormFieldType.singleLine,
      rowIndex: 1,
      columnSpan: FormColumnSpan.half,
    ),
    FormFieldDefinition(
      id: 'ibtidai_report',
      labelUrdu: 'ابتدائی اطلاع رپورٹ',
      labelEnglish: 'Initial Information Report',
      type: FormFieldType.singleLine,
      rowIndex: 2,
      columnSpan: FormColumnSpan.half,
    ),
    FormFieldDefinition(
      id: 'zamni_number',
      labelUrdu: 'سے ضمنی نمبر',
      labelEnglish: 'Supplementary Number',
      type: FormFieldType.singleLine,
      rowIndex: 2,
      columnSpan: FormColumnSpan.half,
    ),
    FormFieldDefinition(
      id: 'tarikh_maqam',
      labelUrdu: 'تاریخ ومقام وقعہ',
      labelEnglish: 'Date and Place of Incident',
      type: FormFieldType.singleLine,
      rowIndex: 3,
      columnSpan: FormColumnSpan.half,
    ),
    FormFieldDefinition(
      id: 'thana_mausool',
      labelUrdu: 'تھانہ میں موصول ہونیگا وقت اور تاریخ',
      labelEnglish: 'Date and Time Received at Station',
      type: FormFieldType.singleLine,
      rowIndex: 3,
      columnSpan: FormColumnSpan.half,
    ),
    FormFieldDefinition(
      id: 'jurm',
      labelUrdu: 'جرم',
      labelEnglish: 'Crime',
      type: FormFieldType.singleLine,
      rowIndex: 4,
      columnSpan: FormColumnSpan.half,
    ),
    FormFieldDefinition(
      id: 'rawangi_waqt',
      labelUrdu: 'تھانہ سے روانگی کا وقت',
      labelEnglish: 'Departure Time from Station',
      type: FormFieldType.singleLine,
      rowIndex: 4,
      columnSpan: FormColumnSpan.half,
    ),
    FormFieldDefinition(
      id: 'halaat_table',
      labelUrdu: 'حالات تفتیش',
      labelEnglish: 'Investigation Circumstances',
      type: FormFieldType.table,
      rowIndex: 5,
      columnSpan: FormColumnSpan.full,
      tableRowCount: 10,
      tableColumns: [
        FormTableColumnDef(
          labelUrdu: 'حالات تفتیش',
          labelEnglish: 'Investigation Circumstances',
          flex: 3,
        ),
        FormTableColumnDef(
          labelUrdu: 'سیریل نمبر',
          labelEnglish: 'Serial no.',
          flex: 1,
        ),
        FormTableColumnDef(
          labelUrdu: 'تاریخ / وقت',
          labelEnglish: 'Date & time',
          flex: 1,
        ),
      ],
    ),
  ];
}
