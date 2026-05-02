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
import '../models/form_field_definition.dart';
import 'case_media_service.dart';

class PdfService {
  static Future<pw.Document> generateCasePdf(
    CaseRecord record, {
    required int caseNumber,
    required String caseReference,
    DocumentFormatTemplate? documentFormat,
  }) async {
    final format = documentFormat;
    if (format != null && format.hasBuiltinFormFields) {
      return generateBuiltinFormPdf(
        record,
        caseNumber: caseNumber,
        caseReference: caseReference,
        format: format,
      );
    }

    final isUrdu = record.isUrdu;
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
    const footStyle = pw.TextStyle(
      fontSize: 8,
      color: PdfColor.fromInt(0xFF9AA5B4),
    );
    return pw.Column(
      children: [
        pw.Container(height: 0.5, color: const PdfColor.fromInt(0xFFDDDDDD)),
        pw.SizedBox(height: 8),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text('Generated by Police Case Docs', style: footStyle),
              ),
            ),
            pw.Expanded(
              child: pw.Center(
                child: pw.Text(
                  dateStr,
                  textAlign: pw.TextAlign.center,
                  style: footStyle,
                ),
              ),
            ),
            pw.Expanded(
              child: pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: footStyle),
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

  /// PDF for built-in paper forms (Supplementary Report, future forms).
  static Future<pw.Document> generateBuiltinFormPdf(
    CaseRecord record, {
    required int caseNumber,
    required String caseReference,
    required DocumentFormatTemplate format,
  }) async {
    final isUrdu = record.isUrdu;
    final textDir = isUrdu ? pw.TextDirection.rtl : pw.TextDirection.ltr;
    final values = record.formFieldValues;
    final accent = PdfColor.fromInt(format.accentColorArgb | 0xFF000000);
    final titleColor = const PdfColor.fromInt(0xFF0A1929);
    final subColor = const PdfColor.fromInt(0xFF5A6A7A);
    final bodyColor = const PdfColor.fromInt(0xFF1A1A1A);

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

    final fields = List<FormFieldDefinition>.from(format.builtinFormFields);
    final rowIndices = fields.map((e) => e.rowIndex).toSet().toList()..sort();

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont, boldItalic: boldFont),
    );

    final title1 = isUrdu ? (format.nameUrdu ?? format.name) : format.name;
    final String? sub1 = isUrdu ? format.formDocumentSubheaderUrdu : format.formDocumentSubheaderEnglish;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: textDir,
        margin: const pw.EdgeInsets.all(40),
        build: (ctx) => [
          pw.Center(
            child: pw.Text(
              title1,
              textDirection: textDir,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: titleColor,
              ),
            ),
          ),
          if (sub1 != null && sub1.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Center(
              child: pw.Text(
                sub1,
                textDirection: textDir,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 10,
                  color: subColor,
                  font: baseFont,
                ),
              ),
            ),
          ],
          pw.SizedBox(height: 10),
          pw.Container(height: 0.5, color: accent),
          pw.SizedBox(height: 10),
          pw.Center(
            child: pw.Text(
              'Ref: $caseReference   ·   Case #$caseNumber',
              textDirection: textDir,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontSize: 8,
                color: subColor,
                font: baseFont,
              ),
            ),
          ),
          pw.SizedBox(height: 8),
          ..._builtinPdfRows(
            rowIndices: rowIndices,
            fields: fields,
            isUrdu: isUrdu,
            values: values,
            textDir: textDir,
            subColor: subColor,
            bodyColor: bodyColor,
            baseFont: baseFont,
            boldFont: boldFont,
            accent: accent,
          ),
        ],
        footer: (ctx) => _buildFooter(ctx, _formatDate(record.savedAt)),
      ),
    );
    return doc;
  }

  static List<pw.Widget> _builtinPdfRows({
    required List<int> rowIndices,
    required List<FormFieldDefinition> fields,
    required bool isUrdu,
    required Map<String, String> values,
    required pw.TextDirection textDir,
    required PdfColor subColor,
    required PdfColor bodyColor,
    required pw.Font baseFont,
    required pw.Font boldFont,
    required PdfColor accent,
  }) {
    final out = <pw.Widget>[];
    for (final ri in rowIndices) {
      final row = fields.where((e) => e.rowIndex == ri).toList();
      if (row.isEmpty) continue;
      if (row.length == 1 && row.first.type == FormFieldType.table) {
        out.add(_builtinPdfTable(
          field: row.first,
          isUrdu: isUrdu,
          values: values,
          textDir: textDir,
          bodyColor: bodyColor,
          baseFont: baseFont,
          boldFont: boldFont,
          accent: accent,
        ));
        out.add(pw.SizedBox(height: 10));
        continue;
      }
      if (row.length == 1) {
        final f = row.first;
        out.add(
          _builtinFieldBlock(
            label: isUrdu ? f.labelUrdu : f.labelEnglish,
            value: values[f.id] ?? '',
            textDir: textDir,
            isUrdu: isUrdu,
            subColor: subColor,
            bodyColor: bodyColor,
            baseFont: baseFont,
            boldFont: boldFont,
            fullWidth: true,
          ),
        );
        out.add(pw.SizedBox(height: 6));
        continue;
      }
      out.add(
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: _builtinFieldBlock(
                label: isUrdu ? row[0].labelUrdu : row[0].labelEnglish,
                value: values[row[0].id] ?? '',
                textDir: textDir,
                isUrdu: isUrdu,
                subColor: subColor,
                bodyColor: bodyColor,
                baseFont: baseFont,
                boldFont: boldFont,
                fullWidth: false,
              ),
            ),
            pw.SizedBox(width: 10),
            if (row.length > 1)
              pw.Expanded(
                child: _builtinFieldBlock(
                  label: isUrdu ? row[1].labelUrdu : row[1].labelEnglish,
                  value: values[row[1].id] ?? '',
                  textDir: textDir,
                  isUrdu: isUrdu,
                  subColor: subColor,
                  bodyColor: bodyColor,
                  baseFont: baseFont,
                  boldFont: boldFont,
                  fullWidth: false,
                ),
              ),
          ],
        ),
      );
      out.add(pw.SizedBox(height: 6));
    }
    return out;
  }

  static pw.Widget _builtinFieldBlock({
    required String label,
    required String value,
    required pw.TextDirection textDir,
    required bool isUrdu,
    required PdfColor subColor,
    required PdfColor bodyColor,
    required pw.Font baseFont,
    required pw.Font boldFont,
    required bool fullWidth,
  }) {
    const lineGrey = PdfColor.fromInt(0xFFD1D5DB);
    final align = isUrdu ? pw.TextAlign.right : pw.TextAlign.left;
    return pw.Directionality(
      textDirection: textDir,
      child: pw.Column(
        crossAxisAlignment: isUrdu ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            textAlign: align,
            style: pw.TextStyle(
              fontSize: 8,
              color: subColor,
              font: baseFont,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 1),
          pw.Container(
            width: fullWidth ? double.infinity : null,
            padding: const pw.EdgeInsets.only(bottom: 2, top: 1),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: lineGrey, width: 0.5),
              ),
            ),
            child: pw.Text(
              value.isEmpty ? ' ' : value,
              textAlign: align,
              style: pw.TextStyle(fontSize: 10, color: bodyColor, font: baseFont, lineSpacing: 1.1),
            ),
          ),
        ],
      ),
    );
  }

  static const int _kPdfInvestigationTableBodyRows = 15;

  static pw.Widget _builtinPdfTable({
    required FormFieldDefinition field,
    required bool isUrdu,
    required Map<String, String> values,
    required pw.TextDirection textDir,
    required PdfColor bodyColor,
    required PdfColor accent,
    required pw.Font baseFont,
    required pw.Font boldFont,
  }) {
    final cols = field.tableColumns ?? [];
    if (cols.isEmpty) return pw.SizedBox();
    final flex = <int>[for (final c in cols) c.flex];
    const border = PdfColor.fromInt(0xFFE5E7EB);
    final headerFill = const PdfColor.fromInt(0xFFF8F9FA);
    final rowAlt = const PdfColor.fromInt(0xFFFAFAFA);
    final narrative = resolveTableNarrative(field.id, values);
    final serial = resolveTableSerial(field.id, values);
    final datetime = resolveTableDatetime(field.id, values);

    final tableRows = <pw.TableRow>[
      pw.TableRow(
        children: List<pw.Widget>.generate(
          cols.length,
          (i) {
            final c = cols[i];
            final ta = i == 0
                ? (isUrdu ? pw.TextAlign.right : pw.TextAlign.left)
                : pw.TextAlign.center;
            return pw.Container(
              color: headerFill,
              padding: const pw.EdgeInsets.all(12),
              child: pw.Text(
                isUrdu ? c.labelUrdu : c.labelEnglish,
                textDirection: textDir,
                textAlign: ta,
                style: pw.TextStyle(
                  fontSize: 6.0,
                  font: boldFont,
                  color: const PdfColor.fromInt(0xFF374151),
                ),
                maxLines: 4,
              ),
            );
          },
        ),
      ),
    ];
    for (var r = 0; r < _kPdfInvestigationTableBodyRows; r++) {
      final bg = r % 2 == 0 ? null : rowAlt;
      final t0 = r == 0 ? narrative : ' ';
      final t1 = r == 0 ? serial : ' ';
      final t2 = r == 0 ? datetime : ' ';
      final row = <pw.Widget>[];
      for (var c = 0; c < cols.length; c++) {
        final v = c == 0 ? t0 : (c == 1 ? t1 : t2);
        final isWide = c == 0;
        final ta = c == 0
            ? (isUrdu ? pw.TextAlign.right : pw.TextAlign.left)
            : pw.TextAlign.center;
        row.add(
          pw.Container(
            color: bg,
            padding: pw.EdgeInsets.symmetric(horizontal: 4, vertical: r == 0 && isWide ? 5 : 4),
            child: isWide
                ? pw.Text(
                    v.isEmpty ? ' ' : v,
                    textDirection: textDir,
                    textAlign: ta,
                    style: pw.TextStyle(
                      fontSize: 7.5,
                      font: baseFont,
                      color: bodyColor,
                      lineSpacing: 1.15,
                    ),
                    maxLines: r == 0 ? 30 : 1,
                )
                : pw.Text(
                    v.isEmpty ? ' ' : v,
                    textDirection: textDir,
                    textAlign: ta,
                    maxLines: r == 0 ? 8 : 1,
                    style: pw.TextStyle(
                      fontSize: 7.5,
                      font: baseFont,
                      color: bodyColor,
                    ),
                  ),
        ),
        );
      }
      tableRows.add(pw.TableRow(children: row));
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Text(
          isUrdu ? field.labelUrdu : field.labelEnglish,
          textDirection: textDir,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            font: boldFont,
            fontSize: 6.5,
            color: accent,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.Container(
          height: 0.75,
          margin: const pw.EdgeInsets.only(top: 4, bottom: 8),
          color: accent,
        ),
        pw.Table(
          border: pw.TableBorder.all(color: border, width: 0.5),
          columnWidths: {
            for (var i = 0; i < flex.length; i++) i: pw.FlexColumnWidth(flex[i].toDouble()),
          },
          children: tableRows,
        ),
      ],
    );
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
