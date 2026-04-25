import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/theme_context.dart';
import '../models/document_format_template.dart';
import '../services/document_format_service.dart';
import '../services/language_service.dart';

/// Premium-styled confirmation (matches [showConfirmDialog] / complete-case style).
Future<bool> showDeleteFormatConfirmDialog(
  BuildContext context, {
  required LanguageService lang,
}) async {
  return await showGeneralDialog<bool>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Dismiss',
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, __, ___) => const SizedBox.shrink(),
        transitionBuilder: (ctx, anim, __, child) {
          final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
          return ScaleTransition(
            scale: curved,
            child: FadeTransition(opacity: anim, child: _DeleteFormatDialogContent(lang: lang)),
          );
        },
      ) ??
      false;
}

class _DeleteFormatDialogContent extends StatelessWidget {
  final LanguageService lang;
  const _DeleteFormatDialogContent({required this.lang});

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
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 40),
              ),
              const SizedBox(height: 20),
              Text(
                lang.deleteFormatDialogTitle,
                textAlign: TextAlign.center,
                textDirection: lang.textDirection,
                style: lang.isUrdu
                    ? lang.urduStyle(fontSize: 20, fontWeight: FontWeight.w700, color: context.policeTextPrimary)
                    : GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: context.policeTextPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                lang.deleteFormatDialogBody,
                textAlign: TextAlign.center,
                textDirection: lang.textDirection,
                style: lang.isUrdu
                    ? lang.urduStyle(fontSize: 14, color: context.policeTextSecondary)
                    : GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, color: context.policeTextSecondary, height: 1.5),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: _DialogPillButton(
                      label: lang.cancelText,
                      onTap: () => Navigator.of(context).pop(false),
                      isDestructive: false,
                      isUrdu: lang.isUrdu,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DialogPillButton(
                      label: lang.deleteText,
                      onTap: () => Navigator.of(context).pop(true),
                      isDestructive: true,
                      isUrdu: lang.isUrdu,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogPillButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;
  final bool isUrdu;

  const _DialogPillButton({required this.label, required this.onTap, required this.isDestructive, this.isUrdu = false});

  @override
  State<_DialogPillButton> createState() => _DialogPillButtonState();
}

class _DialogPillButtonState extends State<_DialogPillButton> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween(begin: 1.0, end: 0.95).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = context.isPoliceDark ? AppColors.darkBorder : Colors.grey.shade300;
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
            color: widget.isDestructive ? AppColors.error : Colors.transparent,
            border: widget.isDestructive ? null : Border.all(color: borderColor, width: 1.5),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: widget.isUrdu
                ? GoogleFonts.notoNastaliqUrdu(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: widget.isDestructive ? Colors.white : context.policeTextSecondary,
                  )
                : GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: widget.isDestructive ? Colors.white : context.policeTextSecondary,
                  ),
          ),
        ),
      ),
    );
  }
}

/// Deletes after confirmation. Shows snackbar if the removed format was active.
/// [scaffoldMessenger] may be the root scaffold; fall back to [context] if null.
Future<void> confirmAndDeleteFormat(
  BuildContext context, {
  required LanguageService lang,
  required DocumentFormatTemplate t,
  ScaffoldMessengerState? scaffoldMessenger,
}) async {
  final svc = DocumentFormatService();
  if (t.isSystem) return;
  final wasActive = svc.activeId == t.id;
  if (!context.mounted) return;
  final ok = await showDeleteFormatConfirmDialog(context, lang: lang);
  if (ok != true) return;
  await svc.deleteById(t.id);
  if (!context.mounted) return;
  if (wasActive) {
    (scaffoldMessenger ?? ScaffoldMessenger.of(context)).showSnackBar(
      SnackBar(
        content: Text(
          lang.activeFormatDeletedSnackbar,
          textDirection: lang.textDirection,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: AppColors.accent,
      ),
    );
  }
}
