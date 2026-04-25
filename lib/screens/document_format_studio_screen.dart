import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/theme_context.dart';
import '../models/document_format_template.dart';
import '../services/document_format_service.dart';
import '../services/language_service.dart';
import '../widgets/delete_format_confirm_dialog.dart';
import 'scanned_format_editor_screen.dart';

/// Two simple paths: **scan a paper** (camera / gallery) to use it as the PDF header band,
/// or **build a format** (titles + color) in the app.
class DocumentFormatStudioScreen extends StatefulWidget {
  const DocumentFormatStudioScreen({super.key});

  @override
  State<DocumentFormatStudioScreen> createState() => _DocumentFormatStudioScreenState();
}

class _DocumentFormatStudioScreenState extends State<DocumentFormatStudioScreen> {
  final _lang = LanguageService();
  final _service = DocumentFormatService();
  final _picker = ImagePicker();
  final _nameScan = TextEditingController();
  final _nameBuild = TextEditingController();
  final _line1 = TextEditingController();
  final _line2 = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _lang.addListener(() => setState(() {}));
    _lang.init();
    _service.addListener(_onFmt);
    _service.init().then((_) {
      if (mounted) setState(() {});
    });
  }

  void _onFmt() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _service.removeListener(_onFmt);
    _nameScan.dispose();
    _nameBuild.dispose();
    _line1.dispose();
    _line2.dispose();
    super.dispose();
  }

  Future<void> _pickAndSaveScan(ImageSource source) async {
    final n = _nameScan.text.trim();
    if (n.isEmpty) {
      _snack(_lang.isUrdu ? 'پہلے فارمیٹ کا نام لکھیں' : 'Enter a name for this format first.');
      return;
    }
    setState(() => _loading = true);
    try {
      final x = await _picker.pickImage(
        source: source,
        maxWidth: 2200,
        imageQuality: 88,
      );
      if (x == null) {
        setState(() => _loading = false);
        return;
      }
      final t = await _service.addFromScan(name: n, xfile: x);
      _nameScan.clear();
      if (!mounted) return;
      if (t != null) {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (ctx) => ScannedFormatEditorScreen(
              formatId: t.id,
              mode: ScannedFormatEditorMode.design,
            ),
          ),
        );
      }
      if (!mounted) return;
      _snack(
        _lang.isUrdu
            ? 'اسکین شدہ فارمیٹ محفوظ ہے۔ اگر ضروری ہو فیلڈز ترتیب دیں۔'
            : 'Scanned format saved. Add fields on the form if needed.',
      );
    } catch (e) {
      if (mounted) _snack('${ _lang.isUrdu ? "خرابی" : "Error"}: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _selectedAccent = 0xFF3399FF;
  static const _swatches = <int>[
    0xFF3399FF, 0xFF2ECC71, 0xFFE74C3C, 0xFF9B59B6, 0xFFF39C12, 0xFF0A1929,
  ];

  Future<void> _saveBuild() async {
    final name = _nameBuild.text.trim();
    final t1 = _line1.text.trim();
    if (t1.isEmpty) {
      _snack(_lang.isUrdu ? 'پہلی لائن درج کریں' : 'Enter the main header line.');
      return;
    }
    if (name.isEmpty) {
      _snack(_lang.isUrdu ? 'نام لکھیں' : 'Enter a name for this format.');
      return;
    }
    setState(() => _loading = true);
    try {
      await _service.addCustom(
        name: name,
        titleLine1: t1,
        titleLine2: _line2.text.trim().isEmpty ? null : _line2.text.trim(),
        accentColorArgb: _selectedAccent,
        showCaseBadge: true,
      );
      _nameBuild.clear();
      _line1.clear();
      _line2.clear();
      if (mounted) {
        _snack(_lang.isUrdu ? 'کسٹم فارمیٹ محفوظ ہے' : 'Custom format saved and selected.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String m) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: AppColors.accent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        surfaceTintColor: Colors.transparent,
        title: Text(
          _lang.isUrdu ? 'دستاویز کے فارمیٹ' : 'Document formats',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            color: context.policeTextPrimary,
          ),
        ),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back_rounded, color: context.policeTextPrimary),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                _introCard(),
                const SizedBox(height: 20),
                Text(
                  _lang.isUrdu ? '1) کاغذ اسکین کریں' : '1) Scan a paper',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: context.policeTextPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _lang.isUrdu
                      ? 'اپنے اسٹیشن کے فارم یا لیٹر ہیڈ کی فوٹو لیں۔ یہ تصویر PDF کے اوپر سرخی کے طور پر لگے گی۔'
                      : 'Take a clear photo of your form or letterhead. It appears at the top of exported PDFs.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    height: 1.45,
                    color: context.policeTextSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameScan,
                  style: GoogleFonts.inter(color: context.policeTextPrimary),
                  decoration: InputDecoration(
                    labelText: _lang.isUrdu ? 'اسکین فارمیٹ کا نام' : 'Name this scanned format',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _pickAndSaveScan(ImageSource.camera),
                        icon: const Icon(Icons.photo_camera_outlined, size: 20),
                        label: Text(_lang.isUrdu ? 'کیمرہ' : 'Camera'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickAndSaveScan(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined, size: 20),
                        label: Text(_lang.isUrdu ? 'گیلری' : 'Gallery'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: context.policeBorder),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Text(
                  _lang.isUrdu ? '2) اندرونی فارمیٹ بنائیں' : '2) Build a format in the app',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: context.policeTextPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _lang.isUrdu
                      ? 'عنوان، ذیلی عنوان اور رنگ خود سیٹ کریں—بغیر کاغذ کے۔'
                      : 'Set header lines and accent color without scanning any paper.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    height: 1.45,
                    color: context.policeTextSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameBuild,
                  style: GoogleFonts.inter(color: context.policeTextPrimary),
                  decoration: InputDecoration(
                    labelText: _lang.isUrdu ? 'فارمیٹ کا نام' : 'Format name',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _line1,
                  style: GoogleFonts.inter(color: context.policeTextPrimary),
                  decoration: InputDecoration(
                    labelText: _lang.isUrdu ? 'اصلی سرخی' : 'Main header line',
                    hintText: _lang.isUrdu
                        ? 'مثال: ضلعی پولیس - روزانہ رپورٹ'
                        : 'e.g. DISTRICT POLICE — DAILY REPORT',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _line2,
                  style: GoogleFonts.inter(color: context.policeTextPrimary),
                  decoration: InputDecoration(
                    labelText: _lang.isUrdu ? 'ذیلی سطر (اختیاری)' : 'Subtitle (optional)',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _lang.isUrdu ? 'رنگ' : 'Accent color',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.policeTextSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: _swatches
                      .map(
                        (c) => InkWell(
                          onTap: () => setState(() => _selectedAccent = c),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Color(c | 0xFF000000),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _selectedAccent == c ? AppColors.accent : context.policeBorder,
                                width: _selectedAccent == c ? 3 : 1,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _saveBuild,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    _lang.isUrdu ? 'کسٹم فارمیٹ محفوظ کریں' : 'Save custom format',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  _lang.isUrdu ? 'محفوظ شدہ' : 'Saved formats',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: context.policeTextPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                if (_service.templates.isEmpty)
                  Text(
                    _lang.isUrdu
                        ? 'ابھی کوئی فارمیٹ نہیں۔ اوپر سے ایک بنائیں۔'
                        : 'No formats yet. Create one with scan or build.',
                    style: GoogleFonts.inter(color: context.policeTextHint, fontSize: 13),
                  )
                else
                  ..._service.templates.map((t) => _templateTile(t)),
                const SizedBox(height: 16),
                if (_service.activeId != null)
                  OutlinedButton(
                    onPressed: () {
                      _service.setActive(null);
                      _snack(_lang.isUrdu ? 'ڈیفالٹ PDF' : 'Using default app PDF layout again.');
                    },
                    child: Text(
                      _lang.isUrdu ? 'ڈیفالٹ app ڈیزائن' : 'Use default app layout',
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _introCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.policeCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.policeBorder.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isPoliceDark ? 0.25 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome_mosaic_outlined,
                color: AppColors.accent,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _lang.isUrdu ? 'یہ کیسے کام کرتا ہے؟' : 'How it works',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: context.policeTextPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _lang.isUrdu
                ? '• اسکین: آپ کا کاغذ PDF کے سربراہ میں دکھایا جائے گا۔\n'
                    '• اندرونی: عنوان اور رنگ یہیں ترتیب دیں—برآمد پر لاگو ہو گا۔\n'
                    '• ایک فعال فارمیٹ منتخب کریں یا ڈیفالٹ پر واپس جائیں۔'
                : '• Scan: your photo is the PDF header (letterhead / form top).\n'
                    '• Build: set titles and color here—no paper needed.\n'
                    '• Select one “active” format, or return to the default layout.',
            style: GoogleFonts.inter(
              fontSize: 12.5,
              height: 1.5,
              color: context.policeTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _templateTile(DocumentFormatTemplate t) {
    final isActive = _service.activeId == t.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: context.policeCard,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isActive
                  ? AppColors.accent.withValues(alpha: 0.5)
                  : context.policeBorder,
              width: isActive ? 1.5 : 1,
            ),
          ),
          clipBehavior: Clip.hardEdge,
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(14, 12, 14 + (t.isSystem ? 0 : 36), 12),
                child: Row(
                  children: [
                    Icon(
                      t.isScan ? Icons.document_scanner_outlined : Icons.tune,
                      size: 22,
                      color: context.policeTextSecondary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.name,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: context.policeTextPrimary,
                            ),
                          ),
                          Text(
                            t.isSystem
                                ? _lang.formatBadgePrebuilt
                                : t.isScan
                                    ? (_lang.isUrdu ? 'اسکین' : 'Scanned')
                                    : (_lang.isUrdu ? 'کسٹم' : 'Custom build'),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: context.policeTextHint,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (t.isSystem)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 6),
                        child: Icon(
                          Icons.lock_outline_rounded,
                          size: 18,
                          color: context.policeTextHint,
                        ),
                      ),
                    if (isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _lang.isUrdu ? 'فعال' : 'Active',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accent,
                          ),
                        ),
                      )
                    else
                      TextButton(
                        onPressed: () => _service.setActive(t.id),
                        child: Text(_lang.isUrdu ? 'چنیں' : 'Use'),
                      ),
                  ],
                ),
              ),
              if (!t.isSystem)
                PositionedDirectional(
                  top: 4,
                  end: 4,
                  child: Material(
                    color: Colors.transparent,
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _onDeleteFormatFromStudio(t),
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.error,
                        size: 22,
                      ),
                      tooltip: _lang.deleteText,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onDeleteFormatFromStudio(DocumentFormatTemplate t) async {
    await confirmAndDeleteFormat(
      context,
      lang: _lang,
      t: t,
    );
  }
}
