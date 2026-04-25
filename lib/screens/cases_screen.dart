import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:printing/printing.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/theme_context.dart';
import '../models/case_record.dart';
import '../models/case_reference.dart';
import '../services/document_format_service.dart';
import '../services/language_service.dart';
import '../services/pdf_service.dart';
import '../services/printer_service.dart';
import 'case_detail_screen.dart';

class CasesScreen extends StatefulWidget {
  const CasesScreen({super.key});

  @override
  State<CasesScreen> createState() => _CasesScreenState();
}

class _CasesScreenState extends State<CasesScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<CaseRecord> _filterCases(List<CaseRecord> sorted) {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return sorted;
    return sorted.where((c) {
      final h = c.heading.toLowerCase();
      final d = c.details.toLowerCase();
      final preview = c.preview.toLowerCase();
      final ref = c.caseReferenceNo.toLowerCase();
      final fmt = c.caseFormatName.toLowerCase();
      return h.contains(q) ||
          d.contains(q) ||
          preview.contains(q) ||
          ref.contains(q) ||
          (fmt.isNotEmpty && fmt.contains(q)) ||
          c.caseFormatId.toLowerCase().contains(q);
    }).toList();
  }

  int _caseNumber(List<CaseRecord> sortedDesc, CaseRecord record) {
    final i = sortedDesc.indexWhere((r) => r.key == record.key);
    if (i < 0) return sortedDesc.length;
    return sortedDesc.length - i;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: ValueListenableBuilder<Box<CaseRecord>>(
          valueListenable: Hive.box<CaseRecord>('cases').listenable(),
          builder: (context, box, _) {
            final allSorted = box.values.toList()..sort((a, b) => b.savedAt.compareTo(a.savedAt));
            final filtered = _filterCases(allSorted);
            final searchEmpty = _searchController.text.trim().isEmpty;
            final displayList = searchEmpty ? allSorted : filtered;
            final headerCount = searchEmpty ? allSorted.length : filtered.length;

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _Header(count: headerCount, total: allSorted.length, searching: !searchEmpty)),
                SliverToBoxAdapter(child: _CasesSearchBar(controller: _searchController)),
                if (allSorted.isEmpty)
                  const SliverFillRemaining(child: _EmptyStateNoCases())
                else if (filtered.isEmpty)
                  const SliverFillRemaining(child: _EmptyStateNoSearchResults())
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final record = displayList[index];
                          final caseNumber = _caseNumber(allSorted, record);
                          return _CaseCard(record: record, caseNumber: caseNumber, box: box);
                        },
                        childCount: displayList.length,
                      ),
                    ),
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
  final int total;
  final bool searching;
  const _Header({required this.count, required this.total, required this.searching});

  @override
  Widget build(BuildContext context) {
    final sub = searching && count != total
        ? '$count match${count == 1 ? '' : 'es'} · $total total'
        : '$count documented case${count == 1 ? '' : 's'}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          'Cases',
          style: GoogleFonts.inter(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: context.policeTextPrimary,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          sub,
          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w400, color: context.policeTextSecondary),
        ),
      ]),
    );
  }
}

class _CasesSearchBar extends StatelessWidget {
  final TextEditingController controller;
  const _CasesSearchBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    final dark = context.isPoliceDark;
    final border = dark ? AppColors.darkBorder.withValues(alpha: 0.9) : AppColors.primary.withValues(alpha: 0.12);
    final fill = dark ? AppColors.darkSurface.withValues(alpha: 0.95) : AppColors.primary.withValues(alpha: 0.04);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          final hasText = value.text.isNotEmpty;
          return TextField(
            controller: controller,
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500, color: context.policeTextPrimary),
            cursorColor: AppColors.accent,
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: fill,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              prefixIcon: Icon(Icons.search_rounded, color: context.policeTextHint, size: 22),
              suffixIcon: hasText
                  ? IconButton(
                      onPressed: () => controller.clear(),
                      icon: Icon(Icons.clear_rounded, color: context.policeTextHint, size: 20),
                      tooltip: 'Clear',
                    )
                  : null,
              hintText: 'Search cases…',
              hintStyle: GoogleFonts.inter(fontSize: 15, color: context.policeTextHint),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: border)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyStateNoCases extends StatelessWidget {
  const _EmptyStateNoCases();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 60),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.description_outlined, size: 36, color: AppColors.accent),
          ),
          const SizedBox(height: 24),
          Text(
            'No cases yet',
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: context.policeTextPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Cases you document will show up here.',
            style: GoogleFonts.inter(fontSize: 14, color: context.policeTextHint),
          ),
        ]),
      ),
    );
  }
}

class _EmptyStateNoSearchResults extends StatelessWidget {
  const _EmptyStateNoSearchResults();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 60),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.search_off_rounded, size: 48, color: context.policeTextHint.withValues(alpha: 0.5)),
          const SizedBox(height: 20),
          Text(
            'No cases found',
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: context.policeTextPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'کوئی مقدمہ نہیں ملا',
            style: GoogleFonts.notoNastaliqUrdu(fontSize: 18, fontWeight: FontWeight.w600, color: context.policeTextSecondary),
            textDirection: TextDirection.rtl,
          ),
        ]),
      ),
    );
  }
}

class _CaseCard extends StatelessWidget {
  final CaseRecord record;
  final int caseNumber;
  final Box<CaseRecord> box;
  const _CaseCard({required this.record, required this.caseNumber, required this.box});

  TextDirection get _dir => record.isUrdu ? TextDirection.rtl : TextDirection.ltr;

  @override
  Widget build(BuildContext context) {
    final refText = CaseReference.resolve(record, box);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => _openDetail(context),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(22, 20, 16, 18),
          decoration: BoxDecoration(
            color: context.policeCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.policeBorder, width: 1),
            boxShadow: [
              BoxShadow(
                color: context.isPoliceDark ? Colors.black.withValues(alpha: 0.35) : Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(
              children: [
                Text(
                  'Case $caseNumber',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: context.policeTextHint, letterSpacing: 0.3),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    refText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: context.policeTextSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              record.heading.isNotEmpty ? record.heading : 'Untitled Case',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textDirection: _dir,
              style: record.isUrdu
                  ? GoogleFonts.notoNastaliqUrdu(fontSize: 18, fontWeight: FontWeight.w700, color: context.policeTextPrimary)
                  : GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: context.policeTextPrimary, height: 1.3),
            ),
            if (record.details.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                record.preview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textDirection: _dir,
                style: record.isUrdu
                    ? GoogleFonts.notoNastaliqUrdu(fontSize: 14, fontWeight: FontWeight.w400, color: context.policeTextSecondary)
                    : GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, color: context.policeTextSecondary, height: 1.5),
              ),
            ],
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatDate(record.savedAt),
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400, color: context.policeTextHint),
                    ),
                    if (record.editCount > 0) ...[
                      const SizedBox(height: 3),
                      Text(
                        'Edited ×${record.editCount}',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w400, color: context.policeTextHint),
                      ),
                    ],
                  ],
                ),
              ),
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
      final ref = CaseReference.resolve(record, box);
      final doc = await PdfService.generateCasePdf(
        record,
        caseNumber: caseNumber,
        caseReference: ref,
        documentFormat: DocumentFormatService().templateForCaseExport(record),
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

  Future<void> _printCase(BuildContext context) async {
    final lang = LanguageService();
    try {
      final ref = CaseReference.resolve(record, box);
      final doc = await PdfService.generateCasePdf(
        record,
        caseNumber: caseNumber,
        caseReference: ref,
        documentFormat: DocumentFormatService().templateForCaseExport(record),
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
    return SizedBox(
      width: 32,
      height: 32,
      child: PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        icon: Icon(Icons.more_horiz_rounded, size: 20, color: context.policeTextHint),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        color: context.policeCard,
        elevation: 8,
        shadowColor: context.isPoliceDark ? Colors.black54 : AppColors.shadowMedium,
        offset: const Offset(0, 36),
        onSelected: (v) {
          if (v == 'pdf') onExportPdf();
          if (v == 'print') onPrint();
        },
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'pdf',
            height: 44,
            child: Row(children: [
              const Icon(Icons.picture_as_pdf_rounded, size: 18, color: AppColors.accent),
              const SizedBox(width: 10),
              Text('Export as PDF', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: context.policeTextPrimary)),
            ]),
          ),
          PopupMenuItem(
            value: 'print',
            height: 44,
            child: Row(children: [
              const Icon(Icons.print_rounded, size: 18, color: AppColors.accent),
              const SizedBox(width: 10),
              Text('Print', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: context.policeTextPrimary)),
            ]),
          ),
        ],
      ),
    );
  }
}
