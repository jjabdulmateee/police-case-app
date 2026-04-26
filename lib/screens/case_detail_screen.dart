import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:printing/printing.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/theme_context.dart';
import '../models/case_record.dart';
import '../models/case_reference.dart';
import '../core/constants.dart';
import '../services/document_format_service.dart';
import '../services/language_service.dart';
import '../services/pdf_service.dart';
import '../services/printer_service.dart';
import '../models/form_field_definition.dart';
import '../widgets/case_media_section.dart';
import '../widgets/font_picker_button.dart';
import 'builtin_form_screen.dart';
import 'edit_case_screen.dart';

String _formatLineForCase(CaseRecord live) {
  if (live.caseFormatName.isNotEmpty) return live.caseFormatName;
  if (live.caseFormatId.isEmpty) return '';
  return DocumentFormatService().getById(live.caseFormatId)?.name ?? live.caseFormatId;
}

class CaseDetailScreen extends StatelessWidget {
  final CaseRecord record;
  final int caseNumber;

  const CaseDetailScreen({super.key, required this.record, required this.caseNumber});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box<CaseRecord>>(
      valueListenable: Hive.box<CaseRecord>('cases').listenable(),
      builder: (context, box, _) {
        final live = box.get(record.key) ?? record;
        final headingFont = _resolveFont(live.headingFont);
        final detailsFont = _resolveFont(live.detailsFont);
        final dateStr = _formatDate(live.savedAt);
        final dir = live.isUrdu ? TextDirection.rtl : TextDirection.ltr;
        final refText = CaseReference.resolve(live, box);
        final formatLabel = _formatLineForCase(live);
        final bodyDetailColor = context.isPoliceDark ? AppColors.darkTextSecondary : const Color(0xFF2D3748);

        return Scaffold(
          backgroundColor: context.policeScaffold,
          body: SafeArea(
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: context.policeIconButtonBg,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: context.isPoliceDark ? 0.25 : 0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(Icons.arrow_back_rounded, size: 20, color: context.policeTextPrimary),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: () => _openEdit(context, live),
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: context.policeIconButtonBg,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: context.isPoliceDark ? 0.25 : 0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.edit_rounded, size: 20, color: AppColors.accent),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: context.isPoliceDark ? 0.18 : 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.check_circle_rounded, size: 14, color: AppColors.success),
                      const SizedBox(width: 4),
                      Text(
                        'Completed',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.success),
                      ),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: 500),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
                    decoration: BoxDecoration(
                      color: context.policeDocumentPaper,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.policeBorder.withValues(alpha: 0.65)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: context.isPoliceDark ? 0.35 : 0.06),
                          blurRadius: 24,
                          offset: const Offset(0, 4),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: context.isPoliceDark ? 0.2 : 0.02),
                          blurRadius: 2,
                          spreadRadius: 1,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: live.isUrdu ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(
                            'Case #$caseNumber',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: context.policeTextHint,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            dateStr,
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w400, color: context.policeTextHint),
                          ),
                        ]),
                        const SizedBox(height: 10),
                        Align(
                          alignment: live.isUrdu ? Alignment.centerRight : Alignment.centerLeft,
                          child: Text(
                            refText,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accent,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        if (formatLabel.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: live.isUrdu ? Alignment.centerRight : Alignment.centerLeft,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.description_outlined, size: 14, color: AppColors.textHint),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    formatLabel,
                                    textDirection: dir,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: context.policeTextHint,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        if (live.formFieldValues.isNotEmpty) ...[
                          _BuiltinCaseFormValues(record: live),
                          const SizedBox(height: 16),
                        ] else ...[
                          if (live.heading.isNotEmpty)
                            SizedBox(
                              width: double.infinity,
                              child: Text(
                                live.heading,
                                textDirection: dir,
                                style: live.isUrdu
                                    ? GoogleFonts.notoNastaliqUrdu(
                                        fontSize: 26, fontWeight: FontWeight.w700, color: context.policeTextPrimary)
                                    : headingFont.builder(
                                        fontSize: 26, fontWeight: FontWeight.w700, color: context.policeTextPrimary),
                              ),
                            ),
                          const SizedBox(height: 20),
                          Container(
                            height: 1,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.accent,
                                  AppColors.accent.withValues(alpha: 0.15),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          if (live.details.isNotEmpty)
                            SizedBox(
                              width: double.infinity,
                              child: Text(
                                live.details,
                                textDirection: dir,
                                style: live.isUrdu
                                    ? GoogleFonts.notoNastaliqUrdu(
                                        fontSize: 15, fontWeight: FontWeight.w400, color: bodyDetailColor,
                                      ).copyWith(height: 2.2)
                                    : detailsFont
                                        .builder(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w400,
                                          color: bodyDetailColor,
                                        )
                                        .copyWith(height: 1.85),
                              ),
                            ),
                        ],
                        if (kMediaEnabled && live.mediaIds.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          CaseMediaSection(
                            caseId: live.key.toString(),
                            isEditable: false,
                          ),
                        ],
                        const SizedBox(height: 40),
                        if (live.editCount > 0) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.only(top: 16),
                            decoration: BoxDecoration(
                              border: Border(top: BorderSide(color: context.policeDivider, width: 0.5)),
                            ),
                            child: Text(
                              _editMetaText(live),
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                                color: context.policeTextHint,
                                height: 1.4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            dateStr,
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w400, color: context.policeTextHint),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                decoration: BoxDecoration(
                  color: context.policeBottomBarBg,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: context.isPoliceDark ? 0.35 : 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Row(children: [
                    Expanded(
                      child: _BottomAction(
                        icon: Icons.picture_as_pdf_rounded,
                        label: 'Export PDF',
                        isPrimary: true,
                        onTap: () => _exportPdf(context, live, box),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _BottomAction(
                        icon: Icons.print_rounded,
                        label: 'Print',
                        isPrimary: false,
                        onTap: () => _printCase(context, live, box),
                      ),
                    ),
                  ]),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }

  String _editMetaText(CaseRecord live) {
    final times = live.editCount == 1 ? '1 time' : '${live.editCount} times';
    if (live.lastEditedAt != null) {
      return 'Edited $times · Last edited ${_formatDate(live.lastEditedAt!)}';
    }
    return 'Edited $times';
  }

  void _openEdit(BuildContext context, CaseRecord live) {
    final fmt = DocumentFormatService()
        .getById(live.formId.isNotEmpty ? live.formId : live.caseFormatId);
    if (fmt != null && fmt.hasBuiltinFormFields) {
      Navigator.of(context).push(PageRouteBuilder(
        pageBuilder: (_, __, ___) => BuiltinFormScreen(
          format: fmt,
          initialValues: Map<String, String>.from(live.formFieldValues),
          existingRecord: live,
        ),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0.03, 0), end: Offset.zero)
                .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
        transitionDuration: const Duration(milliseconds: 300),
      ));
      return;
    }
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, __, ___) => EditCaseScreen(record: live, caseNumber: caseNumber),
      transitionsBuilder: (_, anim, __, child) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0.03, 0), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
      transitionDuration: const Duration(milliseconds: 300),
    ));
  }

  Future<void> _exportPdf(BuildContext context, CaseRecord live, Box<CaseRecord> box) async {
    try {
      final ref = CaseReference.resolve(live, box);
      final doc = await PdfService.generateCasePdf(
        live,
        caseNumber: caseNumber,
        caseReference: ref,
        documentFormat: DocumentFormatService().templateForCaseExport(live),
      );
      await Printing.sharePdf(bytes: await doc.save(), filename: 'Case_$caseNumber.pdf');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('PDF export failed: $e'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  Future<void> _printCase(BuildContext context, CaseRecord live, Box<CaseRecord> box) async {
    final lang = LanguageService();
    try {
      final ref = CaseReference.resolve(live, box);
      final doc = await PdfService.generateCasePdf(
        live,
        caseNumber: caseNumber,
        caseReference: ref,
        documentFormat: DocumentFormatService().templateForCaseExport(live),
      );
      final list = await doc.save();
      if (!context.mounted) return;
      await printPdfWithDirectFallback(
        context,
        lang: lang,
        getPdf: () async => Uint8List.fromList(list),
        jobName: 'Case $caseNumber',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Print failed: $e'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  FontOption _resolveFont(String name) {
    return availableFonts.firstWhere((f) => f.displayName == name, orElse: () => availableFonts.first);
  }

  String _formatDate(DateTime dt) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '${days[dt.weekday - 1]}, ${months[dt.month - 1]} ${dt.day}, ${dt.year} · $h:$min $ampm';
  }
}

/// Read-only structured display for [CaseRecord.formFieldValues] (built-in paper forms).
class _BuiltinCaseFormValues extends StatelessWidget {
  final CaseRecord record;
  const _BuiltinCaseFormValues({required this.record});

  @override
  Widget build(BuildContext context) {
    final tpl = DocumentFormatService().getById(record.formId.isNotEmpty ? record.formId : record.caseFormatId);
    final defs = tpl?.builtinFormFields;
    final dir = record.isUrdu ? TextDirection.rtl : TextDirection.ltr;
    final bodyColor = context.isPoliceDark ? AppColors.darkTextSecondary : const Color(0xFF2D3748);

    if (defs != null && defs.isNotEmpty) {
      return Column(
        crossAxisAlignment: record.isUrdu ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          for (final f in defs) ..._widgetsForField(context, f, record, dir, bodyColor),
        ],
      );
    }

    final keys = record.formFieldValues.keys.toList()..sort();
    return Column(
      crossAxisAlignment: record.isUrdu ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        for (final k in keys)
          if ((record.formFieldValues[k] ?? '').trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: record.isUrdu ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(
                    k,
                    textDirection: dir,
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: context.policeTextHint),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    record.formFieldValues[k] ?? '',
                    textDirection: dir,
                    style: record.isUrdu
                        ? GoogleFonts.notoNastaliqUrdu(fontSize: 15, color: bodyColor, height: 1.8)
                        : GoogleFonts.inter(fontSize: 14, color: bodyColor, height: 1.5),
                  ),
                ],
              ),
            ),
      ],
    );
  }

  List<Widget> _widgetsForField(
    BuildContext context,
    FormFieldDefinition f,
    CaseRecord record,
    TextDirection dir,
    Color bodyColor,
  ) {
    final v = record.formFieldValues;
    if (f.type == FormFieldType.table) {
      final cols = f.tableColumns ?? [];
      final out = <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 6),
          child: Text(
            f.labelForLanguage(record.isUrdu),
            textDirection: dir,
            style: record.isUrdu
                ? GoogleFonts.notoNastaliqUrdu(fontSize: 16, fontWeight: FontWeight.w700, color: context.policeTextPrimary)
                : GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: context.policeTextPrimary),
          ),
        ),
      ];
      for (var r = 0; r < f.tableRowCount; r++) {
        var rowEmpty = true;
        for (var c = 0; c < cols.length; c++) {
          if ((v[formCellKey(f.id, r, c)] ?? '').trim().isNotEmpty) rowEmpty = false;
        }
        if (rowEmpty) continue;
        out.add(
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border.all(color: context.policeBorder.withValues(alpha: 0.85)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: record.isUrdu ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(
                  '— ${r + 1}',
                  style: GoogleFonts.inter(fontSize: 10, color: context.policeTextHint),
                ),
                const SizedBox(height: 6),
                for (var c = 0; c < cols.length; c++)
                  if ((v[formCellKey(f.id, r, c)] ?? '').trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Column(
                        crossAxisAlignment: record.isUrdu ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          Text(
                            record.isUrdu ? cols[c].labelUrdu : cols[c].labelEnglish,
                            textDirection: dir,
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: context.policeTextHint),
                          ),
                          Text(
                            v[formCellKey(f.id, r, c)] ?? '',
                            textDirection: dir,
                            style: record.isUrdu
                                ? GoogleFonts.notoNastaliqUrdu(fontSize: 14, color: bodyColor, height: 1.6)
                                : GoogleFonts.inter(fontSize: 13, color: bodyColor, height: 1.4),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        );
      }
      return out;
    }

    final val = v[f.id] ?? '';
    if (val.trim().isEmpty) return [];
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: record.isUrdu ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              f.labelForLanguage(record.isUrdu),
              textDirection: dir,
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: context.policeTextHint),
            ),
            const SizedBox(height: 4),
            Text(
              val,
              textDirection: dir,
              style: record.isUrdu
                  ? GoogleFonts.notoNastaliqUrdu(fontSize: 16, color: bodyColor, height: 1.9)
                  : GoogleFonts.inter(fontSize: 15, color: bodyColor, height: 1.5),
            ),
          ],
        ),
      ),
    ];
  }
}

class _BottomAction extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isPrimary;
  final VoidCallback onTap;
  const _BottomAction({required this.icon, required this.label, required this.isPrimary, required this.onTap});
  @override
  State<_BottomAction> createState() => _BottomActionState();
}

class _BottomActionState extends State<_BottomAction> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween(begin: 1.0, end: 0.96).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = context.isPoliceDark ? AppColors.darkBorder : const Color(0xFFDDE2E8);
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: widget.isPrimary ? const LinearGradient(colors: AppColors.confirmGradient) : null,
            color: widget.isPrimary ? null : Colors.transparent,
            border: widget.isPrimary ? null : Border.all(color: borderColor, width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.icon,
                size: 18,
                color: widget.isPrimary ? Colors.white : context.policeTextSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: widget.isPrimary ? Colors.white : context.policeTextPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
