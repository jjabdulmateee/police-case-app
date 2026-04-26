import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/document_format_ids.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/theme_context.dart';
import '../models/document_format_template.dart';
import '../services/document_format_service.dart';
import '../services/language_service.dart';
import '../screens/quick_add_format_screen.dart';
import 'delete_format_confirm_dialog.dart';

String _displayFormatName(DocumentFormatTemplate t, LanguageService lang) {
  if (lang.isUrdu && t.nameUrdu != null && t.nameUrdu!.trim().isNotEmpty) {
    return t.nameUrdu!.trim();
  }
  if (t.id == DocumentFormatIds.fir && lang.isUrdu) return 'FIR';
  return t.name;
}

/// [null] = dismissed without choice. [empty string] = no format. [non-empty] = format id.
Future<String?> showFormatPickerBottomSheet({
  required BuildContext context,
  required LanguageService lang,
}) {
  return showModalBottomSheet<String?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    barrierColor: Colors.black45,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return ListenableBuilder(
        listenable: DocumentFormatService(),
        builder: (context, _) {
          return _FormatPickerBody(lang: lang);
        },
      );
    },
  );
}

class _FormatPickerBody extends StatefulWidget {
  final LanguageService lang;
  const _FormatPickerBody({required this.lang});

  @override
  State<_FormatPickerBody> createState() => _FormatPickerBodyState();
}

class _FormatPickerBodyState extends State<_FormatPickerBody> {
  String? _revealDeleteId;

  void _setReveal(String? id) {
    if (_revealDeleteId == id) return;
    setState(() => _revealDeleteId = id);
  }

  LanguageService get lang => widget.lang;

  @override
  Widget build(BuildContext context) {
    final svc = DocumentFormatService();
    final all = svc.templates;
    final recent = svc.recentlyUsedForPicker;

    return DraggableScrollableSheet(
      expand: false,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      initialChildSize: 0.72,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: context.policeCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(color: context.policeBorder.withValues(alpha: 0.5)),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: context.isPoliceDark ? 0.5 : 0.12),
                blurRadius: 24,
              ),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.policeTextHint.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        lang.selectFormatTitle,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: context.policeTextPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        _setReveal(null);
                        _onQuickAdd(context, svc);
                      },
                      icon: const Icon(Icons.add, color: AppColors.accent, size: 26),
                      tooltip: lang.quickAddAddFormat,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (n is ScrollStartNotification) _setReveal(null);
                    return false;
                  },
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    children: [
                      _NoFormatChip(
                        lang: lang,
                        onTap: () {
                          _setReveal(null);
                          Navigator.of(context).pop('');
                        },
                      ),
                      if (recent.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _sectionLabel(context, lang.recentlyUsedSection),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 100,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: recent.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 10),
                            itemBuilder: (c, i) {
                              return _FormatThumbCard(
                                t: recent[i],
                                lang: lang,
                                revealDelete: _revealDeleteId == recent[i].id,
                                onRequestReveal: (id) => _setReveal(id),
                                onTap: () {
                                  _setReveal(null);
                                  _select(c, recent[i].id, svc);
                                },
                                onAfterDelete: () => _setReveal(null),
                              );
                            },
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      _sectionLabel(context, lang.allFormatsSection),
                      const SizedBox(height: 10),
                      ...all.map((t) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _FormatListTile(
                            t: t,
                            lang: lang,
                            revealDelete: _revealDeleteId == t.id,
                            onRequestReveal: (id) => _setReveal(id),
                            onTap: () {
                              _setReveal(null);
                              _select(context, t.id, svc);
                            },
                            onAfterDelete: () => _setReveal(null),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _onQuickAdd(BuildContext context, DocumentFormatService svc) async {
    final newId = await Navigator.of(context).push<String?>(
      PageRouteBuilder<String?>(
        pageBuilder: (_, __, ___) => const QuickAddFormatScreen(),
        transitionDuration: const Duration(milliseconds: 360),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (context, animation, __, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
      ),
    );
    if (!context.mounted || newId == null || newId.isEmpty) return;
    await svc.recordFormatPicked(newId);
    if (context.mounted) Navigator.of(context).pop<String>(newId);
  }

  Future<void> _select(BuildContext context, String id, DocumentFormatService svc) async {
    await svc.recordFormatPicked(id);
    if (context.mounted) Navigator.of(context).pop<String>(id);
  }

  Widget _sectionLabel(BuildContext context, String t) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Text(
        t,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: context.policeTextHint,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _NoFormatChip extends StatelessWidget {
  final LanguageService lang;
  final VoidCallback onTap;
  const _NoFormatChip({required this.lang, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(color: context.policeBorder, width: 1.5),
            borderRadius: BorderRadius.circular(14),
            color: context.isPoliceDark ? AppColors.darkSurface : Colors.transparent,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.layers_outlined, size: 20, color: context.policeTextSecondary),
              const SizedBox(width: 8),
              Text(
                lang.noFormatOption,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: context.policeTextPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormatThumbCard extends StatelessWidget {
  final DocumentFormatTemplate t;
  final LanguageService lang;
  final VoidCallback onTap;
  final bool revealDelete;
  final void Function(String id) onRequestReveal;
  final VoidCallback onAfterDelete;

  const _FormatThumbCard({
    required this.t,
    required this.lang,
    required this.onTap,
    required this.revealDelete,
    required this.onRequestReveal,
    required this.onAfterDelete,
  });

  @override
  Widget build(BuildContext context) {
    final deletable = !t.isSystem;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.policeBorder),
          color: context.isPoliceDark ? AppColors.darkSurface : AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            InkWell(
              onTap: onTap,
              onLongPress: deletable ? () => onRequestReveal(t.id) : null,
              borderRadius: BorderRadius.circular(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      child: _FormatThumbVisual(t: t),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    child: Text(
                      _displayFormatName(t, lang),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: context.policeTextPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (deletable)
              PositionedDirectional(
                top: 4,
                end: 4,
                child: ClipRect(
                  child: AnimatedSlide(
                    offset: revealDelete ? Offset.zero : const Offset(1, 0),
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    child: Material(
                      color: context.policeCard,
                      borderRadius: BorderRadius.circular(20),
                      elevation: 2,
                      shadowColor: Colors.black26,
                      child: IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        onPressed: revealDelete ? () => _onDeleteFormat(context) : null,
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: AppColors.error,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _onDeleteFormat(BuildContext context) async {
    await confirmAndDeleteFormat(
      context,
      lang: lang,
      t: t,
    );
    onAfterDelete();
  }
}

class _FormatThumbVisual extends StatelessWidget {
  final DocumentFormatTemplate t;
  const _FormatThumbVisual({required this.t});

  @override
  Widget build(BuildContext context) {
    if (t.isScan && t.imageFile(DocumentFormatService().documentsPath)?.existsSync() == true) {
      return Image.file(
        t.imageFile(DocumentFormatService().documentsPath)!,
        fit: BoxFit.cover,
        height: 56,
        errorBuilder: (_, __, ___) => _accentFill(t, 56),
      );
    }
    return _accentFill(t, 56);
  }

  Widget _accentFill(DocumentFormatTemplate t, double h) {
    return Container(
      height: h,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(t.accentColorArgb | 0xFF000000),
            Color(t.accentColorArgb | 0xFF000000).withValues(alpha: 0.55),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          t.isSystem ? Icons.verified_outlined : Icons.tune,
          color: Colors.white70,
          size: 22,
        ),
      ),
    );
  }
}

class _FormatListTile extends StatelessWidget {
  final DocumentFormatTemplate t;
  final LanguageService lang;
  final VoidCallback onTap;
  final bool revealDelete;
  final void Function(String id) onRequestReveal;
  final VoidCallback onAfterDelete;

  const _FormatListTile({
    required this.t,
    required this.lang,
    required this.onTap,
    required this.revealDelete,
    required this.onRequestReveal,
    required this.onAfterDelete,
  });

  String _badge() {
    if (t.isSystem) return lang.formatBadgePrebuilt;
    if (t.isScan) return lang.formatBadgeScanned;
    return lang.formatBadgeCustom;
  }

  Future<void> _onDeleteFormat(BuildContext context) async {
    await confirmAndDeleteFormat(
      context,
      lang: lang,
      t: t,
    );
    onAfterDelete();
  }

  @override
  Widget build(BuildContext context) {
    final deletable = !t.isSystem;
    return Material(
      color: context.policeCard,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.policeBorder.withValues(alpha: 0.8)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  onLongPress: deletable ? () => onRequestReveal(t.id) : null,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        _MiniPreview(t: t, size: 44),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _displayFormatName(t, lang),
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: context.policeTextPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _badge(),
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.accent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (deletable)
              ClipRect(
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  alignment: AlignmentDirectional.centerEnd,
                  child: revealDelete
                      ? IconButton(
                          onPressed: () => _onDeleteFormat(context),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: AppColors.error,
                            size: 22,
                          ),
                          tooltip: lang.deleteText,
                        )
                      : const SizedBox(height: 48, width: 0),
                ),
              ),
            if (t.isSystem)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 4),
                child: Icon(
                  Icons.lock_outline_rounded,
                  color: context.policeTextHint,
                  size: 20,
                ),
              ),
            if (!revealDelete || t.isSystem)
              Padding(
                padding: EdgeInsetsDirectional.only(end: deletable && !t.isSystem ? 6 : 10),
                child: Icon(Icons.chevron_right, color: context.policeTextHint, size: 22),
              ),
          ],
        ),
      ),
    );
  }
}

class _MiniPreview extends StatelessWidget {
  final DocumentFormatTemplate t;
  final double size;
  const _MiniPreview({required this.t, required this.size});

  @override
  Widget build(BuildContext context) {
    final f = t.imageFile(DocumentFormatService().documentsPath);
    if (t.isScan && f != null && f.existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(
          f,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          colors: [
            Color(t.accentColorArgb | 0xFF000000),
            Color(t.accentColorArgb | 0xFF000000).withValues(alpha: 0.6),
          ],
        ),
      ),
      child: Icon(
        t.isSystem ? Icons.assignment_outlined : Icons.text_fields,
        color: Colors.white70,
        size: 22,
      ),
    );
  }
}
