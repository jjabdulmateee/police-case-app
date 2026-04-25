import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_file/open_file.dart' show OpenFile, ResultType;
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../core/constants.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/theme_context.dart';
import '../models/case_media.dart';
import '../services/case_media_service.dart';
import '../services/language_service.dart';
import 'section_label.dart';

/// Horizontal case attachments. Respects [kMediaEnabled] (entire build is hidden when false).
class CaseMediaSection extends StatefulWidget {
  final String caseId;
  final bool isEditable;

  const CaseMediaSection({
    super.key,
    required this.caseId,
    required this.isEditable,
  });

  @override
  State<CaseMediaSection> createState() => _CaseMediaSectionState();
}

class _CaseMediaSectionState extends State<CaseMediaSection> {
  final _svc = CaseMediaService();
  final _picker = ImagePicker();
  final _lang = LanguageService();

  @override
  void initState() {
    super.initState();
    if (kMediaEnabled && !kIsWeb) {
      unawaited(_svc.init());
    }
    _lang.addListener(_onLang);
    _lang.init();
    _svc.addListener(_onSvc);
  }

  @override
  void dispose() {
    _lang.removeListener(_onLang);
    _svc.removeListener(_onSvc);
    super.dispose();
  }

  void _onLang() => setState(() {});
  void _onSvc() => setState(() {});

  @override
  Widget build(BuildContext context) {
    if (!kMediaEnabled) return const SizedBox.shrink();
    if (kIsWeb) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: Listenable.merge([_svc, _lang]),
      builder: (context, _) {
        final items = _svc.getMediaForCase(widget.caseId);
        if (items.isEmpty && !widget.isEditable) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            SectionLabel(
              text: _lang.attachmentsSectionLabel,
              icon: Icons.attachment_rounded,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 102,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length + (widget.isEditable ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  if (widget.isEditable && i == items.length) {
                    return _AddTile(onTap: () => _showAddSourceSheet(context));
                  }
                  final m = items[i];
                  return _MediaThumb(
                    media: m,
                    isEditable: widget.isEditable,
                    onTap: () => _openView(context, m),
                    onLongPress: () => _showItemActions(context, m),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _showAddSourceSheet(BuildContext ctx) {
    showModalBottomSheet<void>(
      context: ctx,
      backgroundColor: context.policeCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.policeTextHint.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: AppColors.accent),
                title: Text(
                  'Take Photo',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: context.policeTextPrimary),
                ),
                onTap: () {
                  Navigator.pop(bctx);
                  if (!kMediaEnabled) return;
                  _pickAndAdd(ImageSource.camera, ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppColors.accent),
                title: Text(
                  'Choose from Gallery',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: context.policeTextPrimary),
                ),
                onTap: () {
                  Navigator.pop(bctx);
                  if (!kMediaEnabled) return;
                  _pickAndAdd(ImageSource.gallery, ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.mic_rounded, color: AppColors.accent),
                title: Text(
                  'Record Audio',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: context.policeTextPrimary),
                ),
                onTap: () {
                  Navigator.pop(bctx);
                  if (!kMediaEnabled) return;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!ctx.mounted) return;
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text(_lang.mediaComingSoon),
                        backgroundColor: AppColors.primary,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined, color: AppColors.accent),
                title: Text(
                  'Attach Document',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: context.policeTextPrimary),
                ),
                onTap: () {
                  Navigator.pop(bctx);
                  if (!kMediaEnabled) return;
                  _pickDocument(ctx);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickAndAdd(ImageSource source, BuildContext ctx) async {
    if (!kMediaEnabled) return;
    try {
      final x = await _picker.pickImage(source: source, imageQuality: 88);
      if (x == null) return;
      final path = x.path;
      if (path.isEmpty) return;
      await CaseMediaService().addMedia(
        widget.caseId,
        File(path),
        type: CaseMediaType.image,
      );
      if (ctx.mounted) setState(() {});
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text('Could not add photo: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _pickDocument(BuildContext ctx) async {
    if (!kMediaEnabled) return;
    try {
      final r = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'doc', 'docx', 'txt', 'rtf', 'odt', 'xls', 'xlsx'],
        allowMultiple: false,
        withData: kIsWeb,
      );
      if (r == null || r.files.isEmpty) return;
      final f = r.files.first;
      final path = f.path;
      if (path == null) return;
      final type = _inferType(path);
      await CaseMediaService().addMedia(
        widget.caseId,
        File(path),
        type: type,
      );
      if (ctx.mounted) setState(() {});
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text('Could not attach file: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  CaseMediaType _inferType(String filePath) {
    final e = p.extension(filePath).toLowerCase();
    if (e == '.mp4' || e == '.mov' || e == '.m4v' || e == '.webm') {
      return CaseMediaType.video;
    }
    if (e == '.mp3' || e == '.m4a' || e == '.wav' || e == '.aac' || e == '.ogg' || e == '.flac') {
      return CaseMediaType.audio;
    }
    if (e == '.png' || e == '.jpg' || e == '.jpeg' || e == '.heic' || e == '.gif' || e == '.webp') {
      return CaseMediaType.image;
    }
    return CaseMediaType.document;
  }

  Future<void> _openView(BuildContext context, CaseMedia m) async {
    if (m.type == CaseMediaType.image) {
      if (!File(m.filePath).existsSync()) {
        if (context.mounted) _missingSnack(context);
        return;
      }
      if (!context.mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (ctx) => _FullScreenImageView(path: m.filePath, title: m.fileName),
        ),
      );
    } else {
      await _openFileExternal(m, context);
    }
  }

  void _missingSnack(BuildContext ctx) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: const Text('File is missing on device'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openFileExternal(CaseMedia m, BuildContext context) async {
    final f = File(m.filePath);
    if (!f.existsSync()) {
      if (context.mounted) _missingSnack(context);
      return;
    }
    final r = await OpenFile.open(f.path, type: m.mimeType);
    if (r.type != ResultType.done && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open: ${r.message}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _showItemActions(BuildContext context, CaseMedia m) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.policeCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.open_in_new_rounded, color: AppColors.accent),
                title: Text('View', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: context.policeTextPrimary)),
                onTap: () {
                  Navigator.pop(bctx);
                  if (m.type == CaseMediaType.image) {
                    if (context.mounted) _openView(context, m);
                  } else {
                    _openFileExternal(m, context);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_rounded, color: AppColors.accent),
                title: Text('Download / Share', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: context.policeTextPrimary)),
                onTap: () async {
                  Navigator.pop(bctx);
                  final f = File(m.filePath);
                  if (!f.existsSync()) {
                    if (context.mounted) _missingSnack(context);
                    return;
                  }
                  await Share.shareXFiles(
                    [XFile(f.path, mimeType: m.mimeType, name: m.fileName)],
                    text: m.fileName,
                  );
                },
              ),
              if (widget.isEditable)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                  title: Text('Delete', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.error)),
                  onTap: () {
                    Navigator.pop(bctx);
                    _confirmDelete(context, m);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, CaseMedia m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.policeCard,
        title: Text('Delete attachment?', style: GoogleFonts.inter(color: context.policeTextPrimary, fontWeight: FontWeight.w700)),
        content: Text(
          '“${m.fileName}” will be removed from this case.',
          style: GoogleFonts.inter(color: context.policeTextSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await CaseMediaService().deleteMedia(m.id, widget.caseId);
    }
  }
}

class _AddTile extends StatelessWidget {
  final VoidCallback onTap;
  const _AddTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.35), width: 1.5),
          ),
          child: const Icon(Icons.add_rounded, size: 36, color: AppColors.accent),
        ),
      ),
    );
  }
}

class _MediaThumb extends StatelessWidget {
  final CaseMedia media;
  final bool isEditable;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _MediaThumb({
    required this.media,
    required this.isEditable,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: isEditable ? onLongPress : onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 88,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 88,
                  color: context.isPoliceDark ? const Color(0xFF1E293B) : const Color(0xFFE8EDF2),
                  child: _buildPreview(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    switch (media.type) {
      case CaseMediaType.image:
        final f = File(media.filePath);
        if (f.existsSync()) {
          return Image.file(
            f,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _iconPlaceholder(Icons.broken_image_outlined, context),
          );
        }
        return _iconPlaceholder(Icons.broken_image_outlined, context);
      case CaseMediaType.video:
        return Stack(
          alignment: Alignment.center,
          children: [
            const Icon(Icons.videocam_rounded, size: 36, color: AppColors.accent),
            Positioned(
              bottom: 6,
              child: Text(
                '0:00',
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: context.policeTextHint),
              ),
            ),
          ],
        );
      case CaseMediaType.audio:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.graphic_eq_rounded, size: 32, color: AppColors.accent),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                media.fileName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 9, color: context.policeTextSecondary, height: 1.1),
              ),
            ),
          ],
        );
      case CaseMediaType.document:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.description_outlined, size: 32, color: AppColors.accent),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                media.fileName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 9, color: context.policeTextSecondary, height: 1.1),
              ),
            ),
          ],
        );
    }
  }

  Widget _iconPlaceholder(IconData i, BuildContext context) {
    return Icon(i, size: 36, color: context.policeTextHint);
  }
}

class _FullScreenImageView extends StatelessWidget {
  final String path;
  final String title;

  const _FullScreenImageView({required this.path, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(title, style: GoogleFonts.inter(color: Colors.white, fontSize: 16)),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4,
          child: Image.file(File(path), fit: BoxFit.contain),
        ),
      ),
    );
  }
}
