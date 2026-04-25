import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../core/theme/app_colors.dart';
import '../services/document_format_service.dart';
import '../services/language_service.dart';
import 'scanned_format_editor_screen.dart';

/// Full-screen quick add: Scan paper (camera → name → save) or Build manually. Pops the new [DocumentFormatTemplate.id].
class QuickAddFormatScreen extends StatefulWidget {
  const QuickAddFormatScreen({super.key});

  @override
  State<QuickAddFormatScreen> createState() => _QuickAddFormatScreenState();
}

class _QuickAddFormatScreenState extends State<QuickAddFormatScreen> {
  final _lang = LanguageService();
  final _service = DocumentFormatService();
  final _picker = ImagePicker();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _lang.init();
  }

  Future<void> _scanPaper() async {
    setState(() => _loading = true);
    try {
      final x = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 2200,
        imageQuality: 88,
      );
      if (x == null || !mounted) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      if (!mounted) return;
      final name = await _askFormatName();
      if (name == null || !mounted) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final t = await _service.addFromScan(
        name: name.trim().isEmpty ? (_lang.isUrdu ? 'اسکین' : 'Scanned') : name.trim(),
        xfile: x,
      );
      if (!mounted) return;
      if (t == null) {
        setState(() => _loading = false);
        return;
      }
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (ctx) => ScannedFormatEditorScreen(
            formatId: t.id,
            mode: ScannedFormatEditorMode.design,
          ),
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop<String>(t.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String?> _askFormatName() {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.primaryLight,
          title: Text(
            _lang.formatNameDialogTitle,
            style: GoogleFonts.inter(
              color: AppColors.textOnDark,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            style: GoogleFonts.inter(color: AppColors.textOnDark),
            decoration: InputDecoration(
              hintText: _lang.formatNameDialogHint,
              hintStyle: GoogleFonts.inter(color: AppColors.darkTextSecondary),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.accent),
              ),
            ),
            onSubmitted: (v) => Navigator.of(ctx).pop(v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(_lang.cancelText, style: const TextStyle(color: AppColors.textOnDark)),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(ctrl.text),
              child: Text(_lang.saveText),
            ),
          ],
        );
      },
    );
  }

  Future<void> _buildManually() async {
    final id = await Navigator.of(context).push<String?>(
      PageRouteBuilder<String?>(
        pageBuilder: (_, __, ___) => _QuickAddBuildPage(lang: _lang, service: _service),
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (_, animation, __, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(0.12, 0), end: Offset.zero).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
      ),
    );
    if (mounted && id != null && id.isNotEmpty) {
      Navigator.of(context).pop<String>(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: AppColors.primary,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primaryLight,
          foregroundColor: AppColors.textOnDark,
          surfaceTintColor: Colors.transparent,
        ),
        iconTheme: const IconThemeData(color: AppColors.textOnDark),
      ),
      child: Scaffold(
        backgroundColor: AppColors.primary,
        appBar: AppBar(
          title: Text(
            _lang.quickAddAddFormat,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              color: AppColors.textOnDark,
            ),
          ),
          leading: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              )
            : ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                children: [
                  Text(
                    _lang.quickAddChoosePath,
                    style: GoogleFonts.inter(
                      color: AppColors.textOnDark.withValues(alpha: 0.85),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _NavyOptionCard(
                    icon: Icons.photo_camera_rounded,
                    title: _lang.scanPaperOption,
                    subtitle: _lang.scanPaperSubtitle,
                    onTap: _scanPaper,
                  ),
                  const SizedBox(height: 14),
                  _NavyOptionCard(
                    icon: Icons.edit_rounded,
                    title: _lang.buildManuallyOption,
                    subtitle: _lang.buildManuallySubtitle,
                    onTap: _buildManually,
                  ),
                ],
              ),
      ),
    );
  }
}

class _NavyOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _NavyOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primaryLight,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.accent, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textOnDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.darkTextSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.darkTextSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAddBuildPage extends StatefulWidget {
  final LanguageService lang;
  final DocumentFormatService service;

  const _QuickAddBuildPage({required this.lang, required this.service});

  @override
  State<_QuickAddBuildPage> createState() => _QuickAddBuildPageState();
}

class _QuickAddBuildPageState extends State<_QuickAddBuildPage> {
  final _name = TextEditingController();
  final _line1 = TextEditingController();
  int _accent = 0xFF3399FF;
  static const _swatches = <int>[
    0xFF3399FF, 0xFF2ECC71, 0xFFE74C3C, 0xFF9B59B6, 0xFFF39C12, 0xFF0A1929,
  ];
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _line1.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final t1 = _line1.text.trim();
    if (t1.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.lang.isUrdu ? 'سرخی لکھیں' : 'Enter main header line'),
          backgroundColor: AppColors.accent,
        ),
      );
      return;
    }
    var n = _name.text.trim();
    if (n.isEmpty) n = widget.lang.isUrdu ? 'کسٹم' : 'Custom';
    setState(() => _saving = true);
    try {
      final t = await widget.service.addCustom(
        name: n,
        titleLine1: t1,
        accentColorArgb: _accent,
      );
      if (mounted) Navigator.of(context).pop<String>(t.id);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: AppColors.primary,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primaryLight,
          foregroundColor: AppColors.textOnDark,
        ),
      ),
      child: Scaffold(
        backgroundColor: AppColors.primary,
        appBar: AppBar(
          leading: IconButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: Text(
            widget.lang.buildManuallyOption,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              color: AppColors.textOnDark,
            ),
          ),
        ),
        body: _saving
            ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  TextField(
                    controller: _name,
                    style: GoogleFonts.inter(color: AppColors.textOnDark),
                    decoration: InputDecoration(
                      labelText: widget.lang.isUrdu ? 'فارمیٹ کا نام' : 'Format name',
                      labelStyle: const TextStyle(color: AppColors.darkTextSecondary),
                      enabledBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: AppColors.darkBorder),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: AppColors.accent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _line1,
                    style: GoogleFonts.inter(color: AppColors.textOnDark),
                    decoration: InputDecoration(
                      labelText: widget.lang.isUrdu ? 'مین سرخی' : 'Main header line *',
                      labelStyle: const TextStyle(color: AppColors.darkTextSecondary),
                      enabledBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: AppColors.darkBorder),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: AppColors.accent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.lang.isUrdu ? 'رنگ' : 'Accent',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.darkTextSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _swatches
                        .map(
                          (c) => InkWell(
                            onTap: () => setState(() => _accent = c),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Color(c | 0xFF000000),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _accent == c ? AppColors.accent : AppColors.darkBorder,
                                  width: _accent == c ? 2.5 : 1,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: Text(widget.lang.saveText),
                  ),
                ],
              ),
      ),
    );
  }
}
