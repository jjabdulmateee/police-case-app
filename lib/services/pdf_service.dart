import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import '../core/constants.dart';
import '../models/case_media.dart';
import '../models/case_record.dart';
import '../models/document_format_template.dart';
import 'case_media_service.dart';

class PdfService {
  static Future<pw.Document> generateCasePdf(
    CaseRecord record, {
    required int caseNumber,
    required String caseReference,
    DocumentFormatTemplate? documentFormat,
  }) async {
    final isUrdu = record.isUrdu;
    final format = documentFormat;
    final accent = PdfColor.fromInt((format != null && format.isCustom) ? format.accentColorArgb : 0xFF3399FF);

    Uint8List? scanHeaderBytes;
    if (format != null && format.isScan && format.imageRelativePath != null) {
      final base = await getApplicationDocumentsDirectory();
      final f = format.imageFile(base.path);
      if (f != null && f.existsSync()) {
        try {
          scanHeaderBytes = await f.readAsBytes();
        } catch (_) {
          scanHeaderBytes = null;
        }
      }
    }

    pw.Font baseFont;
    pw.Font boldFont;

    try {
      baseFont = isUrdu
          ? await PdfGoogleFonts.notoNastaliqUrduRegular()
          : await PdfGoogleFonts.interRegular();
      boldFont = isUrdu
          ? await PdfGoogleFonts.notoNastaliqUrduBold()
          : await PdfGoogleFonts.interBold();
    } catch (_) {
      baseFont = pw.Font.helvetica();
      boldFont = pw.Font.helveticaBold();
    }

    double? scanPixelW;
    double? scanPixelH;
    if (scanHeaderBytes != null) {
      final codec = await ui.instantiateImageCodec(scanHeaderBytes);
      final fr = await codec.getNextFrame();
      scanPixelW = fr.image.width.toDouble();
      scanPixelH = fr.image.height.toDouble();
      fr.image.dispose();
    }

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont, boldItalic: boldFont),
    );

    final dateStr = _formatDate(record.savedAt);
    final textDir = isUrdu ? pw.TextDirection.rtl : pw.TextDirection.ltr;
    final scanBytes = scanHeaderBytes; // promote for closure

    final titleColor = const PdfColor.fromInt(0xFF0A1929);
    final subColor = const PdfColor.fromInt(0xFF5A6A7A);
    final bodyTextColor = const PdfColor.fromInt(0xFF1A1A1A);
    final headingColor = const PdfColor.fromInt(0xFF0A1929);
    final dividerColor = (format != null && format.isCustom) ? accent : const PdfColor.fromInt(0xFF3399FF);

    final attachmentWidgets = await _buildCaseMediaAttachmentWidgets(
      record,
      textDir: textDir,
      titleColor: titleColor,
      bodyTextColor: bodyTextColor,
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: textDir,
        margin: const pw.EdgeInsets.symmetric(horizontal: 50, vertical: 48),
        header: (ctx) => _buildPageHeader(
          ctx,
          caseNumber: caseNumber,
          caseReference: caseReference,
          record: record,
          format: format,
          scanHeaderBytes: scanBytes,
          scanPixelW: scanPixelW,
          scanPixelH: scanPixelH,
          textDirection: textDir,
          overlayFont: baseFont,
          accent: accent,
          titleColor: titleColor,
          subColor: subColor,
        ),
        footer: (ctx) => _buildFooter(ctx, dateStr),
        build: (ctx) => [
          pw.SizedBox(height: 12),
          if (record.heading.isNotEmpty)
            pw.Directionality(
              textDirection: textDir,
              child: pw.Text(
                record.heading,
                textDirection: textDir,
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  color: headingColor,
                ),
              ),
            ),
          pw.SizedBox(height: 16),
          pw.Container(height: 1.5, decoration: pw.BoxDecoration(color: dividerColor)),
          pw.SizedBox(height: 20),
          if (record.details.isNotEmpty)
            pw.Directionality(
              textDirection: textDir,
              child: pw.Text(
                record.details,
                textDirection: textDir,
                style: pw.TextStyle(fontSize: 12, color: bodyTextColor, lineSpacing: 6),
              ),
            ),
          ...attachmentWidgets,
          pw.SizedBox(height: 32),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              dateStr,
              style: pw.TextStyle(
                fontSize: 9,
                color: const PdfColor.fromInt(0xFF9AA5B4),
                fontStyle: pw.FontStyle.normal,
              ),
            ),
          ),
        ],
      ),
    );
    return doc;
  }

  static Future<List<pw.Widget>> _buildCaseMediaAttachmentWidgets(
    CaseRecord record, {
    required pw.TextDirection textDir,
    required PdfColor titleColor,
    required PdfColor bodyTextColor,
  }) async {
    if (kIsWeb || !kMediaEnabled || record.mediaIds.isEmpty) {
      return [];
    }
    final key = record.key;
    if (key == null) return [];
    await CaseMediaService().init();
    final svc = CaseMediaService();
    final list = svc.getMediaForCase(key.toString());
    if (list.isEmpty) return [];
    final ur = record.isUrdu;
    final heading = ur ? 'منسلکات' : 'Attachments';
    final out = <pw.Widget>[
      pw.SizedBox(height: 24),
      pw.Directionality(
        textDirection: textDir,
        child: pw.Text(
          heading,
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: titleColor),
        ),
      ),
      pw.SizedBox(height: 10),
    ];
    for (final m in list) {
      final typeLabel = _caseMediaTypePdfLabel(m.type, ur);
      out.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 10),
          child: pw.Directionality(
            textDirection: textDir,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '[$typeLabel] ',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColor.fromInt(0xFF3399FF)),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        m.fileName,
                        style: pw.TextStyle(fontSize: 10, color: bodyTextColor),
                      ),
                    ),
                  ],
                ),
                if (m.caption != null && m.caption!.trim().isNotEmpty)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 2, left: 4),
                    child: pw.Text(
                      m.caption!,
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: const PdfColor.fromInt(0xFF7A7A7A),
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      final thumb = await svc.readBytesForPdfThumbnail(m);
      if (thumb != null && thumb.isNotEmpty) {
        out.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 8, bottom: 6),
            child: pw.Image(
              pw.MemoryImage(thumb),
              width: 200,
              fit: pw.BoxFit.contain,
            ),
          ),
        );
      }
    }
    return out;
  }

  static String _caseMediaTypePdfLabel(CaseMediaType t, bool ur) {
    if (ur) {
      switch (t) {
        case CaseMediaType.image:
          return 'تصویر';
        case CaseMediaType.video:
          return 'ویڈیو';
        case CaseMediaType.audio:
          return 'آڈیو';
        case CaseMediaType.document:
          return 'دستاویز';
      }
    }
    switch (t) {
      case CaseMediaType.image:
        return 'Image';
      case CaseMediaType.video:
        return 'Video';
      case CaseMediaType.audio:
        return 'Audio';
      case CaseMediaType.document:
        return 'Document';
    }
  }

  /// A4 with horizontal 50+50 pt margin: printable width.
  static const _scanAreaWidth = 495.0;

  static pw.Widget _buildPageHeader(
    pw.Context ctx, {
    required int caseNumber,
    required String caseReference,
    required CaseRecord record,
    required DocumentFormatTemplate? format,
    required Uint8List? scanHeaderBytes,
    required double? scanPixelW,
    required double? scanPixelH,
    required pw.TextDirection textDirection,
    required pw.Font overlayFont,
    required PdfColor accent,
    required PdfColor titleColor,
    required PdfColor subColor,
  }) {
    const defaultTitle = 'POLICE CASE DOCUMENTATION';
    final isFirst = ctx.pageNumber == 1;
    final hasScan = format?.isScan == true;
    final showScanImage = isFirst && hasScan && scanHeaderBytes != null;
    final showCaseBadge = format == null || format.isScan || (format.isCustom && format.showCaseBadge);

    String title1 = defaultTitle;
    String? title2;
    if (format != null && format.isCustom) {
      if (format.titleLine1 != null && format.titleLine1!.isNotEmpty) {
        title1 = format.titleLine1!;
      }
      title2 = (format.titleLine2 != null && format.titleLine2!.isNotEmpty) ? format.titleLine2 : null;
    }

    final parts = <pw.Widget>[];

    if (showScanImage) {
      final areaW = _scanAreaWidth;
      final sw = scanPixelW;
      final sh = scanPixelH;
      final h = (sw != null && sh != null && sh > 0) ? (areaW * sh / sw) : 100.0;
      final canOverlay = format != null && format.isScan && format.scannedFields.isNotEmpty;
      if (canOverlay) {
        parts.add(
          pw.SizedBox(
            width: areaW,
            height: h,
            child: pw.Stack(
              children: [
                pw.Positioned.fill(
                  child: pw.Image(
                    pw.MemoryImage(scanHeaderBytes),
                    width: areaW,
                    height: h,
                    fit: pw.BoxFit.fill,
                  ),
                ),
                ..._buildScannedFieldOverlays(
                  format,
                  record,
                  areaW,
                  h,
                  textDirection: textDirection,
                  font: overlayFont,
                ),
              ],
            ),
          ),
        );
      } else {
        parts.add(
          pw.Center(
            child: pw.Image(
              pw.MemoryImage(scanHeaderBytes),
              width: areaW,
              height: h,
              fit: pw.BoxFit.contain,
            ),
          ),
        );
      }
      parts.add(pw.SizedBox(height: 8));
      parts.add(
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(
              child: pw.Text(
                'Ref: $caseReference',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: subColor,
                ),
              ),
            ),
            if (showCaseBadge)
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: const PdfColor.fromInt(0xFFF0F4F8),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  'Case #$caseNumber',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: const PdfColor.fromInt(0xFF3399FF),
                  ),
                ),
              ),
          ],
        ),
      );
      parts.add(pw.SizedBox(height: 8));
      parts.add(pw.Container(height: 0.5, color: const PdfColor.fromInt(0xFFDDDDDD)));
      return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: parts);
    }

    // Default / custom / scan continuation pages: title row + ref + line
    parts.add(
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  title1,
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: titleColor,
                    letterSpacing: 1.2,
                  ),
                ),
                if (title2 != null) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    title2,
                    style: pw.TextStyle(fontSize: 8, color: subColor),
                  ),
                ],
              ],
            ),
          ),
          if (showCaseBadge)
            pw.Container(
              margin: const pw.EdgeInsets.only(left: 8),
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xFFF0F4F8),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(
                'Case #$caseNumber',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: accent,
                ),
              ),
            ),
        ],
      ),
    );
    parts.add(pw.SizedBox(height: 8));
    parts.add(
      pw.Text(
        'Ref: $caseReference',
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: subColor,
          letterSpacing: 0.1,
        ),
      ),
    );
    parts.add(pw.SizedBox(height: 6));
    parts.add(pw.Container(height: 0.5, color: const PdfColor.fromInt(0xFFDDDDDD)));
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: parts);
  }

  static pw.Widget _buildFooter(pw.Context ctx, String dateStr) {
    return pw.Column(
      children: [
        pw.Container(height: 0.5, color: const PdfColor.fromInt(0xFFDDDDDD)),
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Generated by Police Case Docs',
              style: const pw.TextStyle(
                fontSize: 8,
                color: PdfColor.fromInt(0xFF9AA5B4),
              ),
            ),
            pw.Text(
              'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: const pw.TextStyle(
                fontSize: 8,
                color: PdfColor.fromInt(0xFF9AA5B4),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static List<pw.Widget> _buildScannedFieldOverlays(
    DocumentFormatTemplate format,
    CaseRecord record,
    double areaW,
    double areaH, {
    required pw.TextDirection textDirection,
    required pw.Font font,
  }) {
    final w = <pw.Widget>[];
    for (final f in format.scannedFields) {
      final v = record.scannedFieldValues[f.id] ?? '';
      if (v.isEmpty) continue;
      w.add(
        pw.Positioned(
          left: f.x * areaW,
          top: f.y * areaH,
          child: pw.Directionality(
            textDirection: textDirection,
            child: pw.SizedBox(
              width: 120,
              child: pw.Text(
                v,
                textDirection: textDirection,
                maxLines: 8,
                style: pw.TextStyle(
                  font: font,
                  fontSize: 8.5,
                  lineSpacing: 1.1,
                ),
                softWrap: true,
              ),
            ),
          ),
        ),
      );
    }
    return w;
  }

  static String _formatDate(DateTime dt) {
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '${days[dt.weekday - 1]}, ${months[dt.month - 1]} ${dt.day}, ${dt.year} at $h:$min $ampm';
  }
}
