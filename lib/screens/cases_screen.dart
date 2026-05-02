import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:printing/printing.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/theme_context.dart';
import '../main.dart';
import '../models/case_record.dart';
import '../models/case_reference.dart';
import '../services/document_format_service.dart';
import '../services/language_service.dart';
import '../services/pdf_service.dart';
import '../services/printer_service.dart';
import 'case_detail_screen.dart';

enum _FolderScope { all, thisWeek }

class CasesScreen extends StatefulWidget {
  const CasesScreen({super.key});

  @override
  State<CasesScreen> createState() => _CasesScreenState();
}

class _CasesScreenState extends State<CasesScreen> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  _FolderScope _folderScope = _FolderScope.all;
  bool _newestFirst = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
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
      final formBlob = c.formFieldValues.values.map((e) => e.toLowerCase()).join(' ');
      return h.contains(q) ||
          d.contains(q) ||
          preview.contains(q) ||
          ref.contains(q) ||
          (fmt.isNotEmpty && fmt.contains(q)) ||
          c.caseFormatId.toLowerCase().contains(q) ||
          (formBlob.isNotEmpty && formBlob.contains(q));
    }).toList();
  }

  List<CaseRecord> _applyFolderScope(List<CaseRecord> list) {
    if (_folderScope == _FolderScope.all) return list;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - DateTime.monday));
    return list.where((c) => !c.savedAt.isBefore(start)).toList();
  }

  List<CaseRecord> _sortDisplay(List<CaseRecord> list) {
    final copy = List<CaseRecord>.from(list);
    copy.sort((a, b) => _newestFirst ? b.savedAt.compareTo(a.savedAt) : a.savedAt.compareTo(b.savedAt));
    return copy;
  }

  int _caseNumber(List<CaseRecord> sortedDesc, CaseRecord record) {
    final i = sortedDesc.indexWhere((r) => r.key == record.key);
    if (i < 0) return sortedDesc.length;
    return sortedDesc.length - i;
  }

  bool _isThisWeek(DateTime d) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - DateTime.monday));
    return !d.isBefore(start);
  }

  int _countThisWeek(List<CaseRecord> all) => all.where((c) => _isThisWeek(c.savedAt)).length;

  Color _accentForCase(CaseRecord r) {
    if (r.caseFormatId.isEmpty) return AppColors.filesBlue;
    var hash = 0;
    for (final u in r.caseFormatId.codeUnits) {
      hash = (hash * 31 + u) & 0x7fffffff;
    }
    const palette = [
      Color(0xFF1A73E8),
      Color(0xFF00897B),
      Color(0xFF7E57C2),
      Color(0xFFFB8C00),
      Color(0xFFE53935),
    ];
    return palette[hash % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final blue = context.isPoliceDark ? AppColors.accent : AppColors.filesBlue;
    final blueSoft = context.isPoliceDark ? AppColors.accent.withValues(alpha: 0.14) : AppColors.filesBlueSoft;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: ValueListenableBuilder<Box<CaseRecord>>(
          valueListenable: Hive.box<CaseRecord>('cases').listenable(),
          builder: (context, box, _) {
            final allSorted = box.values.toList()..sort((a, b) => b.savedAt.compareTo(a.savedAt));
            final searchEmpty = _searchController.text.trim().isEmpty;
            final afterSearch = searchEmpty ? allSorted : _filterCases(allSorted);
            final scoped = _applyFolderScope(afterSearch);
            final displayList = _sortDisplay(scoped);

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _TopBar(
                    blue: blue,
                    onMenuSelected: (action) {
                      setState(() {
                        if (action == _TopMenu.newest) _newestFirst = true;
                        if (action == _TopMenu.oldest) _newestFirst = false;
                        if (action == _TopMenu.reset) {
                          _folderScope = _FolderScope.all;
                          _searchController.clear();
                          _newestFirst = true;
                        }
                      });
                    },
                  ),
                ),
                SliverToBoxAdapter(child: _PillSearchBar(controller: _searchController, focusNode: _searchFocus)),
                if (allSorted.isEmpty)
                  const SliverFillRemaining(child: _EmptyStateNoCases())
                else if (displayList.isEmpty)
                  SliverFillRemaining(
                    child: searchEmpty ? _EmptyStateScopeEmpty(blue: blue) : const _EmptyStateNoSearchResults(),
                  )
                else ...[
                  SliverToBoxAdapter(
                    child: _SectionHeader(
                      title: 'My folders',
                      trailing: Text(
                        'See all >',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.policeTextHint,
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _QuickFolderGrid(
                      blue: blue,
                      blueSoft: blueSoft,
                      dark: context.isPoliceDark,
                      total: allSorted.length,
                      weekCount: _countThisWeek(allSorted),
                      scope: _folderScope,
                      onNewCase: () => AppShell.switchToTab(context, 0),
                      onPickAll: () => setState(() => _folderScope = _FolderScope.all),
                      onPickWeek: () => setState(() => _folderScope = _FolderScope.thisWeek),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                      child: _SecondaryActionsRow(
                        blue: blue,
                        blueSoft: blueSoft,
                        onNew: () => AppShell.switchToTab(context, 0),
                        onSearchTap: () => _searchFocus.requestFocus(),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _SectionHeader(
                      title: 'Recent cases',
                      trailing: Text(
                        '${displayList.length} items',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.policeTextHint,
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final record = displayList[index];
                          final caseNumber = _caseNumber(allSorted, record);
                          return _CaseRowCard(
                            record: record,
                            caseNumber: caseNumber,
                            box: box,
                            accent: _accentForCase(record),
                          );
                        },
                        childCount: displayList.length,
                      ),
                    ),
                  ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            );
          },
        ),
      ),
    );
  }
}

enum _TopMenu { newest, oldest, reset }

class _TopBar extends StatelessWidget {
  final Color blue;
  final void Function(_TopMenu) onMenuSelected;

  const _TopBar({required this.blue, required this.onMenuSelected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              'Cases',
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: context.policeTextPrimary,
                letterSpacing: -0.6,
              ),
            ),
          ),
          PopupMenuButton<_TopMenu>(
            tooltip: 'More',
            icon: Icon(Icons.more_vert_rounded, color: context.policeTextPrimary),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            color: context.policeCard,
            elevation: 8,
            onSelected: onMenuSelected,
            itemBuilder: (_) => [
              PopupMenuItem(
                value: _TopMenu.newest,
                child: Text('Sort · Newest first', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500)),
              ),
              PopupMenuItem(
                value: _TopMenu.oldest,
                child: Text('Sort · Oldest first', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500)),
              ),
              PopupMenuItem(
                value: _TopMenu.reset,
                child: Text('Reset filters', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PillSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;

  const _PillSearchBar({required this.controller, required this.focusNode});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          final hasText = value.text.isNotEmpty;
          return TextField(
            controller: controller,
            focusNode: focusNode,
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500, color: context.policeTextPrimary),
            cursorColor: AppColors.accent,
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: context.policeSearchFill,
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              prefixIcon: Icon(Icons.search_rounded, color: context.policeTextHint, size: 22),
              suffixIcon: hasText
                  ? IconButton(
                      onPressed: () => controller.clear(),
                      icon: Icon(Icons.clear_rounded, color: context.policeTextHint, size: 20),
                      tooltip: 'Clear',
                    )
                  : null,
              hintText: 'Search',
              hintStyle: GoogleFonts.inter(fontSize: 15, color: context.policeTextHint),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999),
                borderSide: BorderSide(color: AppColors.accent.withValues(alpha: 0.35), width: 1.25),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget trailing;

  const _SectionHeader({required this.title, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Row(
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: context.policeTextPrimary,
            ),
          ),
          const Spacer(),
          trailing,
        ],
      ),
    );
  }
}

class _QuickFolderGrid extends StatelessWidget {
  final Color blue;
  final Color blueSoft;
  final bool dark;
  final int total;
  final int weekCount;
  final _FolderScope scope;
  final VoidCallback onNewCase;
  final VoidCallback onPickAll;
  final VoidCallback onPickWeek;

  const _QuickFolderGrid({
    required this.blue,
    required this.blueSoft,
    required this.dark,
    required this.total,
    required this.weekCount,
    required this.scope,
    required this.onNewCase,
    required this.onPickAll,
    required this.onPickWeek,
  });

  @override
  Widget build(BuildContext context) {
    final labelColor = context.policeTextPrimary;
    final subColor = context.policeTextSecondary;

    Widget tile({required Widget child, required VoidCallback onTap}) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: child,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: tile(
              onTap: onNewCase,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        color: blueSoft,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: blue.withValues(alpha: dark ? 0.35 : 0.18)),
                      ),
                      child: Icon(Icons.add_rounded, color: blue, size: 30),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add case',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: labelColor),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: tile(
              onTap: onPickAll,
              child: _FolderTileBody(
                selected: scope == _FolderScope.all,
                label: 'All cases',
                subtitle: '$total files',
                blue: blue,
                dark: dark,
                labelColor: labelColor,
                subColor: subColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: tile(
              onTap: onPickWeek,
              child: _FolderTileBody(
                selected: scope == _FolderScope.thisWeek,
                label: 'This week',
                subtitle: '$weekCount files',
                blue: blue,
                dark: dark,
                labelColor: labelColor,
                subColor: subColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FolderTileBody extends StatelessWidget {
  final bool selected;
  final String label;
  final String subtitle;
  final Color blue;
  final bool dark;
  final Color labelColor;
  final Color subColor;

  const _FolderTileBody({
    required this.selected,
    required this.label,
    required this.subtitle,
    required this.blue,
    required this.dark,
    required this.labelColor,
    required this.subColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          _GlassFolderThumbnail(
            blue: blue,
            dark: dark,
            emphasized: selected,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: labelColor),
          ),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: subColor),
          ),
        ],
      ),
    );
  }
}

class _GlassFolderThumbnail extends StatelessWidget {
  final Color blue;
  final bool dark;
  final bool emphasized;

  const _GlassFolderThumbnail({
    required this.blue,
    required this.dark,
    required this.emphasized,
  });

  @override
  Widget build(BuildContext context) {
    final ring = emphasized ? blue.withValues(alpha: 0.85) : Colors.transparent;
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ring, width: emphasized ? 2 : 0),
          boxShadow: [
            BoxShadow(
              color: blue.withValues(alpha: dark ? 0.35 : 0.22),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color.lerp(blue, Colors.white, dark ? 0.08 : 0.15)!,
                    blue,
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: dark ? 0.06 : 0.14),
                          Colors.white.withValues(alpha: dark ? 0.02 : 0.06),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Center(
              child: Icon(
                Icons.folder_rounded,
                size: 34,
                color: Colors.white.withValues(alpha: 0.95),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecondaryActionsRow extends StatelessWidget {
  final Color blue;
  final Color blueSoft;
  final VoidCallback onNew;
  final VoidCallback onSearchTap;

  const _SecondaryActionsRow({
    required this.blue,
    required this.blueSoft,
    required this.onNew,
    required this.onSearchTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Material(
          color: blueSoft,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            onTap: onNew,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                'New +',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: blue),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Material(
            color: blueSoft,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              onTap: onSearchTap,
              borderRadius: BorderRadius.circular(999),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, color: blue.withValues(alpha: 0.85), size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Search',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: blue.withValues(alpha: 0.9)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
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
            child: const Icon(Icons.folder_open_rounded, size: 36, color: AppColors.accent),
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

class _EmptyStateScopeEmpty extends StatelessWidget {
  final Color blue;

  const _EmptyStateScopeEmpty({required this.blue});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 60),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.date_range_rounded, size: 48, color: blue.withValues(alpha: 0.55)),
          const SizedBox(height: 20),
          Text(
            'Nothing this week',
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: context.policeTextPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'Try “All cases” or clear filters from the menu.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 14, color: context.policeTextHint),
          ),
        ]),
      ),
    );
  }
}

class _CaseRowCard extends StatelessWidget {
  final CaseRecord record;
  final int caseNumber;
  final Box<CaseRecord> box;
  final Color accent;

  const _CaseRowCard({
    required this.record,
    required this.caseNumber,
    required this.box,
    required this.accent,
  });

  TextDirection get _dir => record.isUrdu ? TextDirection.rtl : TextDirection.ltr;

  @override
  Widget build(BuildContext context) {
    final refText = CaseReference.resolve(record, box);
    final title = record.heading.isNotEmpty ? record.heading : 'Untitled Case';
    final meta = '${refText.isNotEmpty ? '$refText · ' : ''}${_formatShortDate(record.savedAt)}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => _openDetail(context),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
          decoration: BoxDecoration(
            color: context.policeCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.policeBorder, width: 1),
            boxShadow: [
              BoxShadow(
                color: context.isPoliceDark ? Colors.black.withValues(alpha: 0.35) : Colors.black.withValues(alpha: 0.05),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accent,
                      Color.lerp(accent, Colors.black, 0.18)!,
                    ],
                  ),
                ),
                child: Icon(Icons.description_rounded, color: Colors.white.withValues(alpha: 0.95), size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: _dir,
                      style: record.isUrdu
                          ? GoogleFonts.notoNastaliqUrdu(fontSize: 17, fontWeight: FontWeight.w700, color: context.policeTextPrimary)
                          : GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: context.policeTextPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: context.policeTextSecondary),
                    ),
                  ],
                ),
              ),
              _CaseOverflowMenu(
                onExportPdf: () => _exportPdf(context),
                onPrint: () => _printCase(context),
              ),
            ],
          ),
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

  String _formatShortDate(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} · $h:$min $ampm';
  }
}

class _CaseOverflowMenu extends StatelessWidget {
  final VoidCallback onExportPdf;
  final VoidCallback onPrint;

  const _CaseOverflowMenu({required this.onExportPdf, required this.onPrint});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        icon: Icon(Icons.more_vert_rounded, size: 22, color: context.policeTextHint),
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
