import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:printing/printing.dart';
import '../core/theme/app_colors.dart';
import '../models/case_record.dart';
import '../services/pdf_service.dart';
import '../widgets/font_picker_button.dart';
import 'edit_case_screen.dart';

class CaseDetailScreen extends StatelessWidget {
  final CaseRecord record;
  final int caseNumber;

  const CaseDetailScreen({super.key, required this.record, required this.caseNumber});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box<CaseRecord>>(
      valueListenable: Hive.box<CaseRecord>('cases').listenable(),
      builder: (context, box, _) {
        final headingFont = _resolveFont(record.headingFont);
        final detailsFont = _resolveFont(record.detailsFont);
        final dateStr = _formatDate(record.savedAt);
        final dir = record.isUrdu ? TextDirection.rtl : TextDirection.ltr;

        return Scaffold(
          backgroundColor: const Color(0xFFEEF1F5),
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
                        color: Colors.white, borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: const Icon(Icons.arrow_back_rounded, size: 20, color: AppColors.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: () => _openEdit(context),
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white, borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: const Icon(Icons.edit_rounded, size: 20, color: AppColors.accent),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.check_circle_rounded, size: 14, color: AppColors.success),
                      const SizedBox(width: 4),
                      Text('Completed', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.success)),
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
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 24, offset: const Offset(0, 4)),
                      BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 2, spreadRadius: 1, offset: const Offset(0, 1)),
                    ]),
                    child: Column(crossAxisAlignment: record.isUrdu ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Case #$caseNumber', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textHint, letterSpacing: 0.3)),
                        const Spacer(),
                        Text(dateStr, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w400, color: AppColors.textHint)),
                      ]),
                      const SizedBox(height: 28),
                      if (record.heading.isNotEmpty)
                        SizedBox(
                          width: double.infinity,
                          child: Text(record.heading, textDirection: dir,
                            style: record.isUrdu
                                ? GoogleFonts.notoNastaliqUrdu(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.textPrimary)
                                : headingFont.builder(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                        ),
                      const SizedBox(height: 20),
                      Container(height: 1, decoration: BoxDecoration(gradient: LinearGradient(colors: [
                        AppColors.accent, AppColors.accent.withValues(alpha: 0.15), Colors.transparent]))),
                      const SizedBox(height: 24),
                      if (record.details.isNotEmpty)
                        SizedBox(
                          width: double.infinity,
                          child: Text(record.details, textDirection: dir,
                            style: record.isUrdu
                                ? GoogleFonts.notoNastaliqUrdu(fontSize: 15, fontWeight: FontWeight.w400, color: const Color(0xFF2D3748)).copyWith(height: 2.2)
                                : detailsFont.builder(fontSize: 15, fontWeight: FontWeight.w400, color: const Color(0xFF2D3748)).copyWith(height: 1.85)),
                        ),
                      const SizedBox(height: 40),
                      if (record.editCount > 0) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.only(top: 16),
                          decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade200, width: 0.5))),
                          child: Text(
                            _editMetaText(),
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w400, color: AppColors.textHint, height: 1.4),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Align(alignment: Alignment.centerRight, child: Text(dateStr, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w400, color: AppColors.textHint))),
                    ]),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                decoration: BoxDecoration(color: Colors.white, boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, -4))]),
                child: SafeArea(top: false, child: Row(children: [
                  Expanded(child: _BottomAction(icon: Icons.picture_as_pdf_rounded, label: 'Export PDF', isPrimary: true, onTap: () => _exportPdf(context))),
                  const SizedBox(width: 12),
                  Expanded(child: _BottomAction(icon: Icons.print_rounded, label: 'Print', isPrimary: false, onTap: () => _printCase(context))),
                ])),
              ),
            ]),
          ),
        );
      },
    );
  }

  String _editMetaText() {
    final times = record.editCount == 1 ? '1 time' : '${record.editCount} times';
    if (record.lastEditedAt != null) {
      return 'Edited $times · Last edited ${_formatDate(record.lastEditedAt!)}';
    }
    return 'Edited $times';
  }

  void _openEdit(BuildContext context) {
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, __, ___) => EditCaseScreen(record: record, caseNumber: caseNumber),
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

  Future<void> _exportPdf(BuildContext context) async {
    try {
      final doc = await PdfService.generateCasePdf(record, caseNumber: caseNumber);
      await Printing.sharePdf(bytes: await doc.save(), filename: 'Case_$caseNumber.pdf');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('PDF export failed: $e'),
          behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), backgroundColor: AppColors.error));
      }
    }
  }

  Future<void> _printCase(BuildContext context) async {
    try {
      final doc = await PdfService.generateCasePdf(record, caseNumber: caseNumber);
      final printed = await Printing.layoutPdf(onLayout: (_) => doc.save(), name: 'Case $caseNumber');
      if (!printed && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('No printer found — please connect a printer and try again.'),
          behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), backgroundColor: AppColors.error));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Print failed: $e'),
          behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), backgroundColor: AppColors.error));
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

class _BottomAction extends StatefulWidget {
  final IconData icon; final String label; final bool isPrimary; final VoidCallback onTap;
  const _BottomAction({required this.icon, required this.label, required this.isPrimary, required this.onTap});
  @override
  State<_BottomAction> createState() => _BottomActionState();
}

class _BottomActionState extends State<_BottomAction> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  @override
  void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween(begin: 1.0, end: 0.96).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut)); }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) { _ctrl.reverse(); widget.onTap(); },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(scale: _scale, child: Container(
        height: 48,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
          gradient: widget.isPrimary ? const LinearGradient(colors: AppColors.confirmGradient) : null,
          color: widget.isPrimary ? null : Colors.transparent,
          border: widget.isPrimary ? null : Border.all(color: const Color(0xFFDDE2E8), width: 1.5)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(widget.icon, size: 18, color: widget.isPrimary ? Colors.white : AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(widget.label, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: widget.isPrimary ? Colors.white : AppColors.textPrimary)),
        ]),
      )),
    );
  }
}
