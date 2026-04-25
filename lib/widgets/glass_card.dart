import 'package:flutter/material.dart';
import '../core/theme/theme_context.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    final dark = context.isPoliceDark;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: context.policeCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: dark ? context.policeBorder : Colors.grey.shade100,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: dark ? Colors.black.withValues(alpha: 0.35) : const Color(0x1A0A1929),
            blurRadius: dark ? 24 : 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
