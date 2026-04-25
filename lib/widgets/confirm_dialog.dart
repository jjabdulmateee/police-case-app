import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/theme_context.dart';
import '../services/language_service.dart';

Future<bool> showConfirmDialog(BuildContext context, {required LanguageService lang}) async {
  return await showGeneralDialog<bool>(
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
            child: FadeTransition(opacity: anim, child: _ConfirmDialogContent(lang: lang)),
          );
        },
      ) ??
      false;
}

class _ConfirmDialogContent extends StatelessWidget {
  final LanguageService lang;
  const _ConfirmDialogContent({required this.lang});

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
                decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.08), shape: BoxShape.circle),
                child: const Icon(Icons.check_circle_outline_rounded, color: AppColors.accent, size: 40),
              ),
              const SizedBox(height: 20),
              Text(
                lang.completeDialogTitle,
                textAlign: TextAlign.center,
                textDirection: lang.textDirection,
                style: lang.isUrdu
                    ? lang.urduStyle(fontSize: 20, fontWeight: FontWeight.w700, color: context.policeTextPrimary)
                    : GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: context.policeTextPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                lang.completeDialogBody,
                textAlign: TextAlign.center,
                textDirection: lang.textDirection,
                style: lang.isUrdu
                    ? lang.urduStyle(fontSize: 14, color: context.policeTextSecondary)
                    : GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, color: context.policeTextSecondary, height: 1.5),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(child: _DialogButton(label: lang.cancelText, onTap: () => Navigator.of(context).pop(false), isPrimary: false, isUrdu: lang.isUrdu)),
                  const SizedBox(width: 12),
                  Expanded(child: _DialogButton(label: lang.completeText, onTap: () => Navigator.of(context).pop(true), isPrimary: true, isUrdu: lang.isUrdu)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;
  final bool isUrdu;

  const _DialogButton({required this.label, required this.onTap, required this.isPrimary, this.isUrdu = false});

  @override
  State<_DialogButton> createState() => _DialogButtonState();
}

class _DialogButtonState extends State<_DialogButton> with SingleTickerProviderStateMixin {
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
            gradient: widget.isPrimary ? const LinearGradient(colors: AppColors.confirmGradient) : null,
            color: widget.isPrimary ? null : Colors.transparent,
            border: widget.isPrimary ? null : Border.all(color: borderColor, width: 1.5),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: widget.isUrdu
                ? GoogleFonts.notoNastaliqUrdu(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: widget.isPrimary ? Colors.white : context.policeTextSecondary,
                  )
                : GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: widget.isPrimary ? Colors.white : context.policeTextSecondary,
                  ),
          ),
        ),
      ),
    );
  }
}
