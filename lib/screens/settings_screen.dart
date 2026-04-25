import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../core/constants.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/theme_context.dart';
import '../models/case_record.dart';
import '../services/case_media_service.dart';
import '../services/language_service.dart';
import '../services/theme_service.dart';
import '../widgets/language_toggle.dart';
import 'document_format_studio_screen.dart';
import 'printer_settings_screen.dart';
import '../services/printer_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final LanguageService _lang = LanguageService();
  final ThemeService _theme = ThemeService();
  final PrinterService _printer = PrinterService();
  final CaseMediaService _caseMedia = CaseMediaService();

  @override
  void initState() {
    super.initState();
    _lang.addListener(_onLangChanged);
    _lang.init();
    _theme.addListener(_onThemeChanged);
    _theme.init();
    _printer.addListener(_onPrinterChanged);
    _caseMedia.addListener(_onCaseMediaChanged);
  }

  @override
  void dispose() {
    _lang.removeListener(_onLangChanged);
    _theme.removeListener(_onThemeChanged);
    _printer.removeListener(_onPrinterChanged);
    _caseMedia.removeListener(_onCaseMediaChanged);
    super.dispose();
  }

  void _onLangChanged() => setState(() {});
  void _onThemeChanged() => setState(() {});
  void _onPrinterChanged() => setState(() {});
  void _onCaseMediaChanged() => setState(() {});

  String _formatStorageBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Future<void> _confirmClearAll() async {
    final box = Hive.box<CaseRecord>('cases');
    if (box.isEmpty) return;

    final confirmed = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, secondAnim, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: curved,
          child: FadeTransition(
            opacity: anim,
            child: _ClearAllDialog(lang: _lang),
          ),
        );
      },
    );

    if (confirmed == true) {
      await box.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_lang.allCasesClearedText),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: AppColors.success,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildLanguageSection(),
                  const SizedBox(height: 24),
                  _buildDocumentFormatsRow(),
                  const SizedBox(height: 24),
                  _buildPrinterSection(),
                  if (kMediaEnabled) ...[
                    const SizedBox(height: 24),
                    _buildStorageSection(),
                  ],
                  const SizedBox(height: 24),
                  _buildDataSection(),
                  const SizedBox(height: 24),
                  _buildAboutSection(),
                  const SizedBox(height: 40),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _lang.settingsLabel,
            style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w800, color: context.policeTextPrimary, letterSpacing: -0.8),
            textDirection: _lang.textDirection,
          ),
          const SizedBox(height: 4),
          Text(
            _lang.isUrdu ? 'ایپ کی ترجیحات اور ترتیب' : 'App preferences and configuration',
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w400, color: context.policeTextSecondary),
            textDirection: _lang.textDirection,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.accent),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: context.policeTextHint, letterSpacing: 0.5),
            textDirection: _lang.textDirection,
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(_lang.languageLabel.toUpperCase(), Icons.translate_rounded),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.policeCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.policeBorder.withValues(alpha: 0.85), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: context.isPoliceDark ? Colors.black.withValues(alpha: 0.35) : AppColors.shadowLight,
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _lang.isUrdu ? 'ایپ کی زبان' : 'App Language',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: context.policeTextPrimary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _lang.isUrdu ? 'اردو فعال ہے' : 'English active',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w400, color: context.policeTextSecondary),
                        ),
                      ],
                    ),
                  ),
                  LanguageToggle(lang: _lang),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Divider(height: 1, color: context.policeDivider),
              ),
              Row(
                children: [
                  Icon(
                    _theme.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    color: AppColors.accent,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _lang.appearanceLabel,
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: context.policeTextPrimary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _theme.isDark ? _lang.darkModeLabel : _lang.lightModeLabel,
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w400, color: context.policeTextSecondary),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _theme.isDark,
                    onChanged: (v) => _theme.setDark(v),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentFormatsRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(_lang.documentFormatsSectionLabel.toUpperCase(), Icons.description_outlined),
        Material(
          color: context.policeCard,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(builder: (_) => const DocumentFormatStudioScreen()),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.policeBorder.withValues(alpha: 0.85), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: context.isPoliceDark ? Colors.black.withValues(alpha: 0.35) : AppColors.shadowLight,
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.document_scanner_outlined, color: AppColors.accent, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _lang.documentFormatsTileTitle,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: context.policeTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _lang.documentFormatsTileSubtitle,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            height: 1.35,
                            color: context.policeTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: context.policeTextHint),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrinterSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(_lang.printerSectionTitle.toUpperCase(), Icons.print_rounded),
        ListenableBuilder(
          listenable: _printer,
          builder: (context, _) {
            final connected = _printer.isDirectPrintReady && _printer.connectedDeviceName != null;
            final name = connected ? _printer.connectedDeviceName! : _lang.printerStatusNone;
            return Material(
              color: context.policeCard,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(builder: (_) => const PrinterSettingsScreen()),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.policeBorder.withValues(alpha: 0.85), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: context.isPoliceDark
                            ? Colors.black.withValues(alpha: 0.35)
                            : AppColors.shadowLight,
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.print_outlined, color: AppColors.accent, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _lang.printerSettingsTitle,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: context.policeTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _lang.printerTileSubtitle,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                height: 1.35,
                                color: context.policeTextSecondary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: connected ? AppColors.success : context.policeTextHint,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: context.policeTextSecondary,
                                    ),
                                    textDirection: _lang.textDirection,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: context.policeTextHint),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _confirmClearAllMedia() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.policeCard,
        title: Text(
          _lang.clearAllMediaDialogTitle,
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: context.policeTextPrimary),
          textDirection: _lang.textDirection,
        ),
        content: Text(
          _lang.clearAllMediaDialogBody,
          style: GoogleFonts.inter(color: context.policeTextSecondary),
          textDirection: _lang.textDirection,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_lang.isUrdu ? 'منسوخ' : 'Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_lang.clearAllMediaLabel),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _caseMedia.clearAllMedia();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_lang.isUrdu ? 'میڈیا حذف ہو گیا' : 'All attachment files removed'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Widget _buildStorageSection() {
    if (!kMediaEnabled) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(_lang.storageSectionLabel.toUpperCase(), Icons.sd_storage_rounded),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: context.policeCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.policeBorder.withValues(alpha: 0.85), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: context.isPoliceDark
                    ? Colors.black.withValues(alpha: 0.35)
                    : AppColors.shadowLight,
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.perm_media_outlined, color: AppColors.accent, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _lang.storageMediaCaseFilesLabel,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: context.policeTextPrimary,
                            ),
                            textDirection: _lang.textDirection,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatStorageBytes(_caseMedia.getTotalMediaSize()),
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accent,
                            ),
                            textDirection: _lang.textDirection,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: context.policeDivider),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _caseMedia.getTotalMediaSize() > 0 ? _confirmClearAllMedia : null,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_sweep_outlined,
                          size: 20,
                          color: _caseMedia.getTotalMediaSize() > 0
                              ? AppColors.error
                              : context.policeTextHint,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _lang.clearAllMediaLabel,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: _caseMedia.getTotalMediaSize() > 0
                                ? AppColors.error
                                : context.policeTextHint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDataSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(_lang.dataLabel.toUpperCase(), Icons.storage_rounded),
        ValueListenableBuilder<Box<CaseRecord>>(
          valueListenable: Hive.box<CaseRecord>('cases').listenable(),
          builder: (context, box, _) {
            final count = box.length;
            return Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: context.policeCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.policeBorder.withValues(alpha: 0.85), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: context.isPoliceDark ? Colors.black.withValues(alpha: 0.35) : AppColors.shadowLight,
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.folder_rounded, color: AppColors.accent, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _lang.isUrdu ? 'محفوظ مقدمات' : 'Saved Cases',
                                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: context.policeTextPrimary),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _lang.totalCasesText(count),
                                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w400, color: context.policeTextSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: context.policeDivider),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: count > 0 ? _confirmClearAll : null,
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded, size: 20, color: count > 0 ? AppColors.error : context.policeTextHint),
                            const SizedBox(width: 12),
                            Text(
                              _lang.clearAllCasesLabel,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: count > 0 ? AppColors.error : context.policeTextHint,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAboutSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(_lang.aboutLabel.toUpperCase(), Icons.info_outline_rounded),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: context.policeCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.policeBorder.withValues(alpha: 0.85), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: context.isPoliceDark ? Colors.black.withValues(alpha: 0.35) : AppColors.shadowLight,
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.shield_rounded, color: AppColors.accent, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                'Police Case Docs',
                style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: context.policeTextPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                'Version 1.0.0',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w400, color: context.policeTextHint),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: context.isPoliceDark ? 0.1 : 0.06),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _lang.isUrdu ? 'خیبر پختونخواہ پولیس افسران کے لیے' : 'Made for KPK Police Officers',
                  style: _lang.isUrdu
                      ? _lang.urduStyle(fontSize: 12, fontWeight: FontWeight.w500, color: context.policeTextSecondary)
                      : GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: context.policeTextSecondary),
                  textDirection: _lang.textDirection,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ClearAllDialog extends StatelessWidget {
  final LanguageService lang;
  const _ClearAllDialog({required this.lang});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 340,
        margin: const EdgeInsets.symmetric(horizontal: 28),
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
        decoration: BoxDecoration(
          color: context.policeCard,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: context.policeBorder.withValues(alpha: 0.5)),
          boxShadow: [BoxShadow(color: context.policeDialogShadow, blurRadius: 40, offset: const Offset(0, 12))],
        ),
        child: Material(
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.08), shape: BoxShape.circle),
                child: const Icon(Icons.delete_forever_rounded, color: AppColors.error, size: 40),
              ),
              const SizedBox(height: 20),
              Text(
                lang.clearAllCasesLabel,
                textAlign: TextAlign.center,
                textDirection: lang.textDirection,
                style: lang.isUrdu
                    ? lang.urduStyle(fontSize: 20, fontWeight: FontWeight.w700, color: context.policeTextPrimary)
                    : GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: context.policeTextPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                lang.clearAllCasesBody,
                textAlign: TextAlign.center,
                textDirection: lang.textDirection,
                style: lang.isUrdu
                    ? lang.urduStyle(fontSize: 14, color: context.policeTextSecondary)
                    : GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, color: context.policeTextSecondary, height: 1.5),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(child: _SettingsDialogBtn(label: lang.cancelText, onTap: () => Navigator.of(context).pop(false), isPrimary: false, isUrdu: lang.isUrdu)),
                  const SizedBox(width: 12),
                  Expanded(child: _SettingsDialogBtn(label: lang.deleteText, onTap: () => Navigator.of(context).pop(true), isPrimary: false, isUrdu: lang.isUrdu, isDestructive: true)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsDialogBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;
  final bool isUrdu;
  final bool isDestructive;
  const _SettingsDialogBtn({required this.label, required this.onTap, required this.isPrimary, this.isUrdu = false, this.isDestructive = false});
  @override
  State<_SettingsDialogBtn> createState() => _SettingsDialogBtnState();
}

class _SettingsDialogBtnState extends State<_SettingsDialogBtn> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween(begin: 1.0, end: 0.95).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isDestructive ? Colors.white : context.policeTextSecondary;
    final borderSide = context.isPoliceDark ? AppColors.darkBorder : Colors.grey.shade300;
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) { _ctrl.reverse(); widget.onTap(); },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: widget.isDestructive ? const LinearGradient(colors: [Color(0xFFE74C3C), Color(0xFFC0392B)]) : null,
            color: widget.isDestructive ? null : Colors.transparent,
            border: widget.isDestructive ? null : Border.all(color: borderSide, width: 1.5),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: widget.isUrdu
                ? GoogleFonts.notoNastaliqUrdu(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)
                : GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: textColor),
          ),
        ),
      ),
    );
  }
}
