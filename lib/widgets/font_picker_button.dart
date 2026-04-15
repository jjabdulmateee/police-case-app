import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';

class FontOption {
  final String displayName;
  final TextStyle Function({double? fontSize, FontWeight? fontWeight, Color? color})
      builder;

  const FontOption({required this.displayName, required this.builder});
}

final List<FontOption> availableFonts = [
  FontOption(
    displayName: 'Inter',
    builder: ({fontSize, fontWeight, color}) =>
        GoogleFonts.inter(fontSize: fontSize, fontWeight: fontWeight, color: color),
  ),
  FontOption(
    displayName: 'Roboto',
    builder: ({fontSize, fontWeight, color}) =>
        GoogleFonts.roboto(fontSize: fontSize, fontWeight: fontWeight, color: color),
  ),
  FontOption(
    displayName: 'Lora',
    builder: ({fontSize, fontWeight, color}) =>
        GoogleFonts.lora(fontSize: fontSize, fontWeight: fontWeight, color: color),
  ),
  FontOption(
    displayName: 'Playfair Display',
    builder: ({fontSize, fontWeight, color}) =>
        GoogleFonts.playfairDisplay(fontSize: fontSize, fontWeight: fontWeight, color: color),
  ),
  FontOption(
    displayName: 'Source Sans 3',
    builder: ({fontSize, fontWeight, color}) =>
        GoogleFonts.sourceSans3(fontSize: fontSize, fontWeight: fontWeight, color: color),
  ),
  FontOption(
    displayName: 'Merriweather',
    builder: ({fontSize, fontWeight, color}) =>
        GoogleFonts.merriweather(fontSize: fontSize, fontWeight: fontWeight, color: color),
  ),
  FontOption(
    displayName: 'Nunito',
    builder: ({fontSize, fontWeight, color}) =>
        GoogleFonts.nunito(fontSize: fontSize, fontWeight: fontWeight, color: color),
  ),
  FontOption(
    displayName: 'Poppins',
    builder: ({fontSize, fontWeight, color}) =>
        GoogleFonts.poppins(fontSize: fontSize, fontWeight: fontWeight, color: color),
  ),
  FontOption(
    displayName: 'Raleway',
    builder: ({fontSize, fontWeight, color}) =>
        GoogleFonts.raleway(fontSize: fontSize, fontWeight: fontWeight, color: color),
  ),
  FontOption(
    displayName: 'Crimson Text',
    builder: ({fontSize, fontWeight, color}) =>
        GoogleFonts.crimsonText(fontSize: fontSize, fontWeight: fontWeight, color: color),
  ),
];

class FontPickerButton extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const FontPickerButton({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final current = availableFonts[selectedIndex];

    return GestureDetector(
      onTap: () => _showPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.accent.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.font_download_outlined,
              size: 14,
              color: AppColors.accent,
            ),
            const SizedBox(width: 5),
            Text(
              current.displayName,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 14,
              color: AppColors.accent,
            ),
          ],
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _FontPickerSheet(
        selectedIndex: selectedIndex,
        onChanged: (i) {
          onChanged(i);
          Navigator.pop(context);
        },
      ),
    );
  }
}

class _FontPickerSheet extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _FontPickerSheet({
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.55,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Choose Font',
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Select a professional font for this section',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: Colors.grey.shade100),
          Flexible(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: availableFonts.length,
              itemBuilder: (context, index) {
                final font = availableFonts[index];
                final isSelected = index == selectedIndex;

                return InkWell(
                  onTap: () => onChanged(index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    color: isSelected
                        ? AppColors.accent.withValues(alpha: 0.06)
                        : Colors.transparent,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            font.displayName,
                            style: font.builder(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          'Aa Bb Cc',
                          style: font.builder(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: AppColors.accent,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}
