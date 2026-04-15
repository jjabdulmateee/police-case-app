import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/language_service.dart';

class LanguageToggle extends StatefulWidget {
  final LanguageService lang;

  const LanguageToggle({super.key, required this.lang});

  @override
  State<LanguageToggle> createState() => _LanguageToggleState();
}

class _LanguageToggleState extends State<LanguageToggle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;

  static const _kWidth = 120.0;
  static const _kHeight = 38.0;
  static const _kChipPadding = 3.0;

  double get _chipWidth => (_kWidth / 2) - _kChipPadding;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      value: widget.lang.isUrdu ? 1.0 : 0.0,
    );

    _slideAnimation = CurvedAnimation(
      parent: _controller,
      curve: const _SpringCurve(),
    );

    widget.lang.addListener(_onLangChanged);
  }

  @override
  void dispose() {
    widget.lang.removeListener(_onLangChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onLangChanged() {
    if (widget.lang.isUrdu) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  void _selectEn() {
    if (widget.lang.isUrdu) widget.lang.toggle();
  }

  void _selectUr() {
    if (!widget.lang.isUrdu) widget.lang.toggle();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_kHeight / 2),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: AnimatedBuilder(
          animation: _slideAnimation,
          builder: (context, child) {
            final t = _slideAnimation.value;
            return Container(
              width: _kWidth,
              height: _kHeight,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(_kHeight / 2),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: _kChipPadding + t * _chipWidth,
                    top: _kChipPadding,
                    child: Container(
                      width: _chipWidth,
                      height: _kHeight - (_kChipPadding * 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(
                          (_kHeight - _kChipPadding * 2) / 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 6,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _selectEn,
                          child: Center(
                            child: Text(
                              'EN',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight:
                                    t < 0.5 ? FontWeight.w700 : FontWeight.w500,
                                color: Color.lerp(
                                  const Color(0xFF0A1929),
                                  const Color(0xFF9AA5B4),
                                  t,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _selectUr,
                          child: Center(
                            child: Text(
                              'اردو',
                              style: GoogleFonts.notoNastaliqUrdu(
                                fontSize: 13,
                                fontWeight:
                                    t > 0.5 ? FontWeight.w700 : FontWeight.w500,
                                color: Color.lerp(
                                  const Color(0xFF9AA5B4),
                                  const Color(0xFF0A1929),
                                  t,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SpringCurve extends Curve {
  const _SpringCurve();

  @override
  double transformInternal(double t) {
    // Fast attack, slight overshoot, smooth settle — iOS-like spring
    final p = t * t * (3.0 - 2.0 * t); // smooth-step base
    final overshoot = (1.0 + 0.08 * (1.0 - (2.0 * t - 1.0) * (2.0 * t - 1.0)));
    return p * overshoot;
  }
}
