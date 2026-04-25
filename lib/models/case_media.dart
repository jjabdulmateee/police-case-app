/// Metadata for a file stored under the app case media directory.
/// Persisted in `media/index.json` via [CaseMediaService], not directly in Hive.
enum CaseMediaType {
  image,
  video,
  audio,
  document,
}

class CaseMedia {
  final String id;
  final String caseId;
  final CaseMediaType type;
  final String fileName;
  final String filePath;
  final int fileSizeBytes;
  final String mimeType;
  final DateTime createdAt;
  final String? caption;
  final bool isDownloaded;

  const CaseMedia({
    required this.id,
    required this.caseId,
    required this.type,
    required this.fileName,
    required this.filePath,
    required this.fileSizeBytes,
    required this.mimeType,
    required this.createdAt,
    this.caption,
    this.isDownloaded = true,
  });

  static CaseMediaType _typeFromJson(String? v) {
    switch (v) {
      case 'image':
        return CaseMediaType.image;
      case 'video':
        return CaseMediaType.video;
      case 'audio':
        return CaseMediaType.audio;
      case 'document':
        return CaseMediaType.document;
      default:
        return CaseMediaType.document;
    }
  }

  String get _typeJson {
    switch (type) {
      case CaseMediaType.image:
        return 'image';
      case CaseMediaType.video:
        return 'video';
      case CaseMediaType.audio:
        return 'audio';
      case CaseMediaType.document:
        return 'document';
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'caseId': caseId,
    'type': _typeJson,
    'fileName': fileName,
    'filePath': filePath,
    'fileSizeBytes': fileSizeBytes,
    'mimeType': mimeType,
    'createdAt': createdAt.toIso8601String(),
    'caption': caption,
    'isDownloaded': isDownloaded,
  };

  factory CaseMedia.fromJson(Map<String, dynamic> json) {
    return CaseMedia(
      id: json['id'] as String? ?? '',
      caseId: json['caseId'] as String? ?? '',
      type: _typeFromJson(json['type'] as String?),
      fileName: json['fileName'] as String? ?? '',
      filePath: json['filePath'] as String? ?? '',
      fileSizeBytes: (json['fileSizeBytes'] as num?)?.toInt() ?? 0,
      mimeType: json['mimeType'] as String? ?? 'application/octet-stream',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      caption: json['caption'] as String?,
      isDownloaded: json['isDownloaded'] as bool? ?? true,
    );
  }
}
