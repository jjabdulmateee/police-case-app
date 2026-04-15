import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';
import '../core/theme/app_colors.dart';
import '../models/case_record.dart';
import '../services/pdf_service.dart';
import '../services/language_service.dart';

enum _ExportAction { pdf, print }

Future<void> showExportSheet(
  BuildContext context, {
  required CaseRecord record,
  required int caseNumber,
  LanguageService? lang,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _ExportSheetContent(
      record: record,
      caseNumber: caseNumber,
      parentContext: context,
      lang: lang,
    ),
  );
}

class _ExportSheetContent extends StatefulWidget {
  final CaseRecord record;
  final int caseNumber;
  final BuildContext parentContext;
  final LanguageService? lang;

  const _ExportSheetContent({required this.record, required this.caseNumber, required this.parentContext, this.lang});

  @override
  State<_ExportSheetContent> createState() => _ExportSheetContentState();
}

class _ExportSheetContentState extends State<_ExportSheetContent> {
  bool _loading = false;
  bool get _isUrdu => widget.lang?.isUrdu ?? false;

  Future<void> _handleAction(_ExportAction action) async {
    setState(() => _loading = true);
    try {
      final doc = await PdfService.generateCasePdf(widget.record, caseNumber: widget.caseNumber);
      if (!mounted) return;
      Navigator.of(context).pop();
      if (action == _ExportAction.pdf) {
        await Printing.sharePdf(bytes: await doc.save(), filename: 'Case_${widget.caseNumber}.pdf');
      } else {
        final printed = await Printing.layoutPdf(onLayout: (_) => doc.save(), name: 'Case ${widget.caseNumber}');
        if (!printed && widget.parentContext.mounted) {
          ScaffoldMessenger.of(widget.parentContext).showSnackBar(SnackBar(
            content: const Text('No printer found — please connect a printer and try again.'),
            behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), backgroundColor: AppColors.error,
          ));
        }
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (widget.parentContext.mounted) {
        ScaffoldMessenger.of(widget.parentContext).showSnackBar(SnackBar(
          content: Text('Export failed: $e'), behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.lang;
    return Container(
      decoration: const BoxDecoration(color: AppColors.surfaceCard, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.08), shape: BoxShape.circle),
            child: const Icon(Icons.file_present_rounded, color: AppColors.accent, size: 28),
          ),
          const SizedBox(height: 14),
          Text(
            l?.caseSavedTitle ?? 'Case Saved Successfully',
            textDirection: l?.textDirection,
            style: _isUrdu
                ? GoogleFonts.notoNastaliqUrdu(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)
                : GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            l?.whatNextText ?? 'What would you like to do next?',
            textDirection: l?.textDirection,
            style: _isUrdu
                ? GoogleFonts.notoNastaliqUrdu(fontSize: 13, color: AppColors.textSecondary)
                : GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          if (_loading)
            const Padding(padding: EdgeInsets.symmetric(vertical: 30), child: CircularProgressIndicator(color: AppColors.accent))
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(children: [
                Expanded(child: _ActionTile(icon: Icons.picture_as_pdf_rounded, label: l?.exportPdfText ?? 'Export as PDF', onTap: () => _handleAction(_ExportAction.pdf))),
                const SizedBox(width: 14),
                Expanded(child: _ActionTile(icon: Icons.print_rounded, label: l?.printText ?? 'Print', onTap: () => _handleAction(_ExportAction.print))),
              ]),
            ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l?.skipText ?? 'Skip for now', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textHint)),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}

class _ActionTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.label, required this.onTap});
  @override
  State<_ActionTile> createState() => _ActionTileState();
}

class _ActionTileState extends State<_ActionTile> with SingleTickerProviderStateMixin {
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
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) { _ctrl.reverse(); widget.onTap(); },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 22),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.12), width: 1.5),
          ),
          child: Column(children: [
            Icon(widget.icon, color: AppColors.accent, size: 28),
            const SizedBox(height: 10),
            Text(widget.label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ]),
        ),
      ),
    );
  }
}
