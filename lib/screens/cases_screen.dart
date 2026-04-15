import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:printing/printing.dart';
import '../core/theme/app_colors.dart';
import '../models/case_record.dart';
import '../services/pdf_service.dart';
import 'case_detail_screen.dart';

class CasesScreen extends StatelessWidget {
  const CasesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: ValueListenableBuilder<Box<CaseRecord>>(
          valueListenable: Hive.box<CaseRecord>('cases').listenable(),
          builder: (context, box, _) {
            final cases = box.values.toList()..sort((a, b) => b.savedAt.compareTo(a.savedAt));
            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _Header(count: cases.length)),
                if (cases.isEmpty)
                  const SliverFillRemaining(child: _EmptyState())
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                    sliver: SliverList(delegate: SliverChildBuilderDelegate(
                      (context, index) => _CaseCard(record: cases[index], caseNumber: cases.length - index),
                      childCount: cases.length,
                    )),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final int count;
  const _Header({required this.count});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Cases', style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.8)),
        const SizedBox(height: 4),
        Text('$count documented case${count == 1 ? '' : 's'}', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w400, color: AppColors.textSecondary)),
      ]),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(padding: const EdgeInsets.only(bottom: 60), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 80, height: 80, decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(24)),
          child: const Icon(Icons.description_outlined, size: 36, color: AppColors.accent)),
        const SizedBox(height: 24),
        Text('No cases yet', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        Text('Cases you document will show up here.', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textHint)),
      ])),
    );
  }
}

class _CaseCard extends StatelessWidget {
  final CaseRecord record;
  final int caseNumber;
  const _CaseCard({required this.record, required this.caseNumber});

  TextDirection get _dir => record.isUrdu ? TextDirection.rtl : TextDirection.ltr;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => _openDetail(context),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(22, 20, 16, 18),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard, borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF0F0F0), width: 1),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 2))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('Case $caseNumber', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textHint, letterSpacing: 0.3)),
              const Spacer(),
            ]),
            const SizedBox(height: 8),
            Text(
              record.heading.isNotEmpty ? record.heading : 'Untitled Case',
              maxLines: 2, overflow: TextOverflow.ellipsis, textDirection: _dir,
              style: record.isUrdu
                  ? GoogleFonts.notoNastaliqUrdu(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)
                  : GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary, height: 1.3),
            ),
            if (record.details.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(record.preview, maxLines: 2, overflow: TextOverflow.ellipsis, textDirection: _dir,
                style: record.isUrdu
                    ? GoogleFonts.notoNastaliqUrdu(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textSecondary)
                    : GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textSecondary, height: 1.5)),
            ],
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(_formatDate(record.savedAt), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textHint)),
                if (record.editCount > 0) ...[
                  const SizedBox(height: 3),
                  Text('Edited ×${record.editCount}', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w400, color: AppColors.textHint)),
                ],
              ])),
              _ActionDot(onExportPdf: () => _exportPdf(context), onPrint: () => _printCase(context)),
            ]),
          ]),
        ),
      ),
    );
  }

  void _openDetail(BuildContext context) {
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, __, ___) => CaseDetailScreen(record: record, caseNumber: caseNumber),
      transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0.03, 0), end: Offset.zero).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)), child: child)),
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

  String _formatDate(DateTime dt) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '${days[dt.weekday - 1]}, ${months[dt.month - 1]} ${dt.day}, ${dt.year} · $h:$min $ampm';
  }
}

class _ActionDot extends StatelessWidget {
  final VoidCallback onExportPdf;
  final VoidCallback onPrint;
  const _ActionDot({required this.onExportPdf, required this.onPrint});
  @override
  Widget build(BuildContext context) {
    return SizedBox(width: 32, height: 32, child: PopupMenuButton<String>(
      padding: EdgeInsets.zero, icon: Icon(Icons.more_horiz_rounded, size: 20, color: AppColors.textHint),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: AppColors.surfaceCard, elevation: 8, shadowColor: AppColors.shadowMedium, offset: const Offset(0, 36),
      onSelected: (v) { if (v == 'pdf') onExportPdf(); if (v == 'print') onPrint(); },
      itemBuilder: (_) => [
        PopupMenuItem(value: 'pdf', height: 44, child: Row(children: [
          const Icon(Icons.picture_as_pdf_rounded, size: 18, color: AppColors.accent), const SizedBox(width: 10),
          Text('Export as PDF', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500))])),
        PopupMenuItem(value: 'print', height: 44, child: Row(children: [
          const Icon(Icons.print_rounded, size: 18, color: AppColors.accent), const SizedBox(width: 10),
          Text('Print', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500))])),
      ],
    ));
  }
}
