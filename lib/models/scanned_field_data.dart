/// A single fillable field on a scanned paper image. [x] and [y] are 0.0–1.0, relative to
/// full image width/height, representing the top-left of the text box (not the tap center).
class ScannedFieldData {
  final String id;
  final String? label;
  final double x;
  final double y;

  const ScannedFieldData({
    required this.id,
    this.label,
    required this.x,
    required this.y,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'x': x,
        'y': y,
      };

  static ScannedFieldData fromJson(Map<String, dynamic> j) {
    return ScannedFieldData(
      id: j['id'] as String,
      label: j['label'] as String?,
      x: (j['x'] as num).toDouble().clamp(0.0, 1.0),
      y: (j['y'] as num).toDouble().clamp(0.0, 1.0),
    );
  }

  ScannedFieldData copyWith({double? x, double? y, String? label}) {
    return ScannedFieldData(
      id: id,
      label: label ?? this.label,
      x: x ?? this.x,
      y: y ?? this.y,
    );
  }
}
