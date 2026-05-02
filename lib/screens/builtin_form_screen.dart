import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:printing/printing.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/theme_context.dart';
import '../main.dart';
import '../models/case_record.dart';
import '../models/document_format_template.dart' show DocumentFormatTemplate;
import '../models/form_field_definition.dart';
import '../models/case_reference.dart';
import '../services/document_format_service.dart';
import '../services/language_service.dart';
import '../services/pdf_service.dart';
import '../widgets/export_bottom_sheet.dart';
import '../widgets/font_picker_button.dart';
import '../widgets/language_toggle.dart';

// Light-mode premium document spec (dark mode uses theme-aware fallbacks).
const Color _kPageBg = Color(0xFFF0F2F5);
const Color _kLabel = Color(0xFF6B7280);
const Color _kFieldText = Color(0xFF1A1A2E);
const Color _kLineIdle = Color(0xFFD1D5DB);
const Color _kLineFocus = Color(0xFF3399FF);
/// Legacy row-based table; notebook UI uses [tableNarrativeKey] / [tableSerialKey] / [tableDatetimeKey].

/// Premium built-in form: floating mic, spacious fields, dynamic investigation table.
class BuiltinFormScreen extends StatefulWidget {
  final DocumentFormatTemplate format;

  /// Pre-fill (e.g. edit flow). Keys match [formCellKey] and field [id]s.
  final Map<String, String>? initialValues;

  /// When set, [Save] updates this case instead of inserting a new one.
  final CaseRecord? existingRecord;

  const BuiltinFormScreen({
    super.key,
    required this.format,
    this.initialValues,
    this.existingRecord,
  });

  @override
  State<BuiltinFormScreen> createState() => _BuiltinFormScreenState();
}

class _BuiltinFormScreenState extends State<BuiltinFormScreen> with TickerProviderStateMixin {
  final LanguageService _lang = LanguageService();
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  final SpeechToText _speech = SpeechToText();

  bool _speechAvailable = false;
  bool _isListening = false;
  bool _wantListening = false;
  String? _voiceKey;
  String _textBeforeListen = '';
  int _gen = 0;

  String? _focusedKey;
  bool _showEmptyHint = true;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _lang.addListener(_onLang);
    _lang.init();
    _initFieldControllers();
    _attachFocusListeners();
    _initSpeech();
  }

  void _onLang() => setState(() {});

  void _initFieldControllers() {
    final init = widget.initialValues ?? const <String, String>{};
    for (final f in widget.format.builtinFormFields) {
      if (f.type == FormFieldType.table) {
        final nKey = tableNarrativeKey(f.id);
        final sKey = tableSerialKey(f.id);
        final dKey = tableDatetimeKey(f.id);
        _controllers[nKey] = TextEditingController(text: resolveTableNarrative(f.id, init));
        _controllers[sKey] = TextEditingController(text: resolveTableSerial(f.id, init));
        _controllers[dKey] = TextEditingController(text: resolveTableDatetime(f.id, init));
        _focusNodes[nKey] = FocusNode();
        _focusNodes[sKey] = FocusNode();
        _focusNodes[dKey] = FocusNode();
      } else {
        _controllers[f.id] = TextEditingController(text: init[f.id] ?? '');
        _focusNodes[f.id] = FocusNode();
      }
    }
  }

  void _attachFocusListeners() {
    for (final e in _focusNodes.entries) {
      e.value.addListener(_makeFocusListener(e.key));
    }
  }

  @override
  void dispose() {
    _lang.removeListener(_onLang);
    _pulseController.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final n in _focusNodes.values) {
      n.dispose();
    }
    _speech.stop();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onError: _onSpeechError,
      onStatus: _onSpeechStatus,
    );
    if (mounted) setState(() {});
  }

  void _onSpeechError(SpeechRecognitionError error) {
    if (!_wantListening || _voiceKey == null) {
      _stopVoice();
      return;
    }
    if (error.errorMsg == 'error_busy') {
      _scheduleRestart(delayMs: 300);
      return;
    }
    _scheduleRestart();
  }

  void _onSpeechStatus(String status) {
    if (!mounted) return;
    if (status == 'listening' && _isListening == false) {
      setState(() => _isListening = true);
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
      return;
    }
    if (status == 'notListening' || status == 'done') {
      setState(() => _isListening = false);
      if (_wantListening && _voiceKey != null) {
        _scheduleRestart(delayMs: 150);
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    }
  }

  void _scheduleRestart({int delayMs = 150}) {
    final g = _gen;
    Future<void>.delayed(Duration(milliseconds: delayMs), () {
      if (!mounted) return;
      if (!_wantListening || _voiceKey == null) return;
      if (g != _gen) return;
      _textBeforeListen = _controllers[_voiceKey!]?.text ?? '';
      _startListenSession(g);
    });
  }

  void _startListenSession(int g) {
    if (!_wantListening || _voiceKey == null || g != _gen) return;
    final loc = (widget.existingRecord?.isUrdu ?? _lang.isUrdu) ? 'ur_PK' : 'en_US';
    _speech.listen(
      onResult: _onSpeechResult,
      localeId: loc,
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 8),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        listenMode: ListenMode.dictation,
      ),
    );
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    final key = _voiceKey;
    if (key == null) return;
    final text = result.recognizedWords;
    if (text.isEmpty) return;
    final controller = _controllers[key];
    if (controller == null) return;
    final allowMultiline = key.endsWith('_narrative') || key.endsWith('_serial') || key.endsWith('_datetime');
    final cleaned = allowMultiline ? text : text.replaceAll('\n', ' ').trim();
    final sep = _textBeforeListen.isEmpty ? '' : ' ';
    controller.value = TextEditingValue(
      text: _textBeforeListen + sep + cleaned,
      selection: TextSelection.collapsed(offset: (_textBeforeListen + sep + cleaned).length),
    );
    if (result.finalResult) {
      _textBeforeListen = controller.text;
    }
    setState(() {});
  }

  void _onFabPressed() {
    if (!_speechAvailable) return;
    final key = _focusedKey;
    if (key == null) {
      final ur = _ur;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ur ? 'پہلے کوئی خانہ دبائیں' : 'Tap a field first to use the microphone'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_wantListening && _voiceKey == key) {
      _stopVoice();
      return;
    }
    if (_wantListening) _stopVoice();
    _voiceKey = key;
    _textBeforeListen = _controllers[key]?.text ?? '';
    setState(() {
      _wantListening = true;
      _isListening = true;
    });
    _gen++;
    _startListenSession(_gen);
  }

  void _stopVoice() {
    _wantListening = false;
    _gen++;
    _speech.stop();
    _pulseController.stop();
    _pulseController.reset();
    setState(() {
      _isListening = false;
      _voiceKey = null;
    });
  }

  bool get _ur => widget.existingRecord?.isUrdu ?? _lang.isUrdu;

  Map<String, String> _collectValues() {
    final m = <String, String>{};
    for (final e in _controllers.entries) {
      final t = e.value.text.trim();
      if (t.isNotEmpty) m[e.key] = t;
    }
    return m;
  }

  String _detailsSummary() {
    final ur = _ur;
    final values = _collectValues();
    if (values.isEmpty) return '';
    final lines = <String>[];
    for (final f in widget.format.builtinFormFields) {
      if (f.type == FormFieldType.table) {
        final tc = f.tableColumns ?? const <FormTableColumnDef>[];
        final n = values[tableNarrativeKey(f.id)];
        final s = values[tableSerialKey(f.id)];
        final d = values[tableDatetimeKey(f.id)];
        if (n != null && n.isNotEmpty) {
          final lab = tc.isNotEmpty ? (ur ? tc[0].labelUrdu : tc[0].labelEnglish) : (ur ? f.labelUrdu : f.labelEnglish);
          lines.add('$lab: $n');
        }
        if (s != null && s.isNotEmpty) {
          final lab = tc.length > 1 ? (ur ? tc[1].labelUrdu : tc[1].labelEnglish) : '';
          lines.add('${ur ? f.labelUrdu : f.labelEnglish} $lab: $s');
        }
        if (d != null && d.isNotEmpty) {
          final lab = tc.length > 2 ? (ur ? tc[2].labelUrdu : tc[2].labelEnglish) : '';
          lines.add('${ur ? f.labelUrdu : f.labelEnglish} $lab: $d');
        }
      } else {
        final v = values[f.id];
        if (v != null && v.isNotEmpty) {
          lines.add('${ur ? f.labelUrdu : f.labelEnglish}: $v');
        }
      }
    }
    return lines.join('\n');
  }

  String _appBarTitle() {
    if (_ur && widget.format.nameUrdu != null && widget.format.nameUrdu!.isNotEmpty) {
      return widget.format.nameUrdu!;
    }
    return widget.format.name;
  }

  String _speakingLabel() {
    final key = _focusedKey;
    if (key == null) return _ur ? 'کوئی فعال خانہ نہیں' : 'No field selected';
    final ur = _ur;
    for (final f in widget.format.builtinFormFields) {
      if (f.type == FormFieldType.table) {
        if (key == tableNarrativeKey(f.id)) {
          final col = f.tableColumns != null && f.tableColumns!.isNotEmpty ? f.tableColumns![0] : null;
          final name = col != null ? (ur ? col.labelUrdu : col.labelEnglish) : f.labelEnglish;
          return _ur ? 'بولیں: $name' : 'Speaking into: $name';
        }
        if (key == tableSerialKey(f.id)) {
          final col = f.tableColumns != null && f.tableColumns!.length > 1 ? f.tableColumns![1] : null;
          final name = col != null ? (ur ? col.labelUrdu : col.labelEnglish) : 'Serial';
          return _ur ? 'بولیں: $name' : 'Speaking into: $name';
        }
        if (key == tableDatetimeKey(f.id)) {
          final col = f.tableColumns != null && f.tableColumns!.length > 2 ? f.tableColumns![2] : null;
          final name = col != null ? (ur ? col.labelUrdu : col.labelEnglish) : 'Date & time';
          return _ur ? 'بولیں: $name' : 'Speaking into: $name';
        }
      } else if (f.id == key) {
        return _ur ? 'بولیں: ${f.labelUrdu}' : 'Speaking into: ${f.labelEnglish}';
      }
    }
    return _ur ? 'بولیں' : 'Speaking';
  }

  Future<void> _saveOrUpdate() async {
    final box = Hive.box<CaseRecord>('cases');
    final sid = widget.format.id;
    final heading = _ur ? (widget.format.nameUrdu ?? widget.format.name) : widget.format.name;
    final existing = widget.existingRecord;
    if (existing != null && existing.key != null) {
      existing.heading = heading;
      existing.details = _detailsSummary();
      existing.caseFormatId = sid;
      existing.caseFormatName = widget.format.name;
      existing.formFieldValues = _collectValues();
      existing.formId = sid;
      existing.headingFont = availableFonts.first.displayName;
      existing.detailsFont = availableFonts.first.displayName;
      existing.editCount = existing.editCount + 1;
      existing.lastEditedAt = DateTime.now();
      await existing.save();
    } else {
      final year = DateTime.now().year;
      final ref = CaseReference.formatAuto(box.length + 1, year);
      final rec = CaseRecord(
        heading: heading,
        details: _detailsSummary(),
        headingFont: availableFonts.first.displayName,
        detailsFont: availableFonts.first.displayName,
        savedAt: DateTime.now(),
        caseLanguage: _lang.code,
        caseReferenceNo: ref,
        caseFormatId: sid,
        caseFormatName: widget.format.name,
        formFieldValues: _collectValues(),
        formId: sid,
      );
      await box.add(rec);
    }
    await DocumentFormatService().recordFormatUsedInSavedCase(sid);
    if (mounted) HapticFeedback.mediumImpact();
  }

  Future<CaseRecord> _buildRecordForExport() async {
    final box = Hive.box<CaseRecord>('cases');
    final y = DateTime.now().year;
    final ref = widget.existingRecord?.caseReferenceNo.trim().isNotEmpty == true
        ? widget.existingRecord!.caseReferenceNo
        : CaseReference.formatAuto((widget.existingRecord != null) ? box.length : box.length + 1, y);
    final sid = widget.format.id;
    return CaseRecord(
      heading: _ur ? (widget.format.nameUrdu ?? widget.format.name) : widget.format.name,
      details: _detailsSummary(),
      headingFont: availableFonts.first.displayName,
      detailsFont: availableFonts.first.displayName,
      savedAt: DateTime.now(),
      caseLanguage: widget.existingRecord?.caseLanguage ?? _lang.code,
      caseReferenceNo: ref,
      caseFormatId: sid,
      caseFormatName: widget.format.name,
      formFieldValues: _collectValues(),
      formId: sid,
    );
  }

  Future<void> _onSaveCase() async {
    await _saveOrUpdate();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_ur ? 'مقدمہ محفوظ ہو گیا' : 'Case saved'),
        backgroundColor: AppColors.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    AppShell.switchToTab(context, 1);
    if (widget.existingRecord != null) Navigator.of(context).pop();
  }

  Future<void> _onSaveAndExportAppBar() async {
    await _saveOrUpdate();
    if (!mounted) return;
    final box = Hive.box<CaseRecord>('cases');
    if (widget.existingRecord?.key != null) {
      final rec = box.get(widget.existingRecord!.key) ?? widget.existingRecord!;
      final idx = _caseNumberFor(box, rec);
      await showExportSheet(context, record: rec, caseNumber: idx, lang: _lang);
    } else {
      final rec = box.getAt(box.length - 1);
      if (rec != null) {
        await showExportSheet(context, record: rec, caseNumber: box.length, lang: _lang);
      }
    }
    if (mounted) {
      AppShell.switchToTab(context, 1);
      if (widget.existingRecord != null) Navigator.of(context).pop();
    }
  }

  int _caseNumberFor(Box<CaseRecord> box, CaseRecord r) {
    final sorted = box.values.toList()..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    final i = sorted.indexWhere((e) => e.key == r.key);
    if (i < 0) return box.length;
    return sorted.length - i;
  }

  Future<void> _onExportPdf() async {
    try {
      final record = await _buildRecordForExport();
      final box = Hive.box<CaseRecord>('cases');
      final y = DateTime.now().year;
      final ref = record.caseReferenceNo.isNotEmpty
          ? record.caseReferenceNo
          : CaseReference.formatAuto(box.length + 1, y);
      final caseNum = widget.existingRecord?.key != null
          ? _caseNumberFor(box, widget.existingRecord!)
          : (box.length + 1);
      final doc = await PdfService.generateCasePdf(
        record,
        caseNumber: caseNum,
        caseReference: ref,
        documentFormat: widget.format,
      );
      if (!mounted) return;
      await Printing.sharePdf(bytes: await doc.save(), filename: 'Case_${widget.format.id}.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF failed: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void Function() _makeFocusListener(String k) {
    return () {
      if (_focusNodes[k]!.hasFocus) {
        if (_showEmptyHint) setState(() => _showEmptyHint = false);
        setState(() => _focusedKey = k);
      } else {
        if (FocusManager.instance.primaryFocus == null) {
          setState(() {
            if (_focusedKey == k) _focusedKey = null;
          });
        }
      }
    };
  }

  @override
  Widget build(BuildContext context) {
    final ur = _ur;
    final dir = ur ? TextDirection.rtl : TextDirection.ltr;
    final fields = widget.format.builtinFormFields;
    final rowIndices = fields.map((e) => e.rowIndex).toSet().toList()..sort();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = isDark ? context.policeScaffold : _kPageBg;
    final cardColor = isDark ? context.policeDocumentPaper : Colors.white;
    final fabOnLeft = dir == TextDirection.rtl;

    return ListenableBuilder(
      listenable: _lang,
      builder: (context, __) {
        return Directionality(
          textDirection: dir,
          child: Scaffold(
            backgroundColor: pageBg,
            appBar: AppBar(
              elevation: 0,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: Text(
                _appBarTitle(),
                style: ur
                    ? _lang.urduStyle(fontSize: 18, fontWeight: FontWeight.w700)
                    : GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              actions: [
                if (widget.existingRecord == null) LanguageToggle(lang: _lang),
                TextButton(
                  onPressed: _onSaveAndExportAppBar,
                  child: Text(
                    ur ? 'محفوظ و برآمد' : 'Save & Export',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ),
            body: Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: 120),
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                            border: Border.all(color: context.policeBorder.withValues(alpha: 0.35)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (_showEmptyHint) ...[
                                  Text(
                                    ur ? 'کوئی بھی خانہ دبائیں • مائیک بٹن سے بولیں' : 'Tap any field to start filling • Use the mic button to speak',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: isDark ? context.policeTextHint : const Color(0xFF9CA3AF),
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                ],
                                _buildDocumentCardHeader(context, ur, isDark),
                                const SizedBox(height: 32),
                                for (final ri in rowIndices) _buildRow(ri, fields.where((e) => e.rowIndex == ri).toList(), isDark, ur),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    _bottomBar(ur, isDark),
                  ],
                ),
                Positioned(
                  right: fabOnLeft ? null : 20,
                  left: fabOnLeft ? 20 : null,
                  bottom: 100,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: fabOnLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                    children: [
                      if (_speechAvailable)
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 200),
                          child: Text(
                            _speakingLabel(),
                            textAlign: fabOnLeft ? TextAlign.start : TextAlign.end,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: context.policeTextSecondary,
                            ),
                          ),
                        ),
                      if (_speechAvailable) const SizedBox(height: 8),
                      if (_speechAvailable)
                        ScaleTransition(
                          scale: _wantListening
                              ? Tween<double>(begin: 1, end: 1.12).animate(
                                  CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
                                )
                              : const AlwaysStoppedAnimation(1),
                          child: Material(
                            color: _wantListening ? AppColors.error : AppColors.accent,
                            shape: const CircleBorder(),
                            elevation: 6,
                            child: InkWell(
                              onTap: _onFabPressed,
                              customBorder: const CircleBorder(),
                              child: SizedBox(
                                width: 56,
                                height: 56,
                                child: Icon(Icons.mic_rounded, color: Colors.white, size: 28),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _bottomBar(bool ur, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      decoration: BoxDecoration(
        color: isDark ? context.policeBottomBarBg : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -2),
          ),
        ],
        border: Border(top: BorderSide(color: context.policeBorder.withValues(alpha: 0.3))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: _BottomPrimaryButton(
                label: ur ? 'مقدمہ محفوظ' : 'Save Case',
                onPressed: _onSaveCase,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _BottomOutlineButton(
                label: ur ? 'PDF' : 'Export PDF',
                onPressed: _onExportPdf,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentCardHeader(BuildContext context, bool ur, bool isDark) {
    final f = widget.format;
    if (ur) {
      return Column(
        children: [
          Text(
            f.nameUrdu ?? f.name,
            textAlign: TextAlign.center,
            style: _lang.urduStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          if (f.formDocumentSubheaderUrdu != null) ...[
            const SizedBox(height: 8),
            Text(
              f.formDocumentSubheaderUrdu!,
              textAlign: TextAlign.center,
              style: _lang.urduStyle(fontSize: 14, fontWeight: FontWeight.w500, color: context.policeTextSecondary),
            ),
          ],
        ],
      );
    }
    final sub = f.formDocumentSubheaderEnglish;
    return Column(
      children: [
        Text(
          f.name,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w800, color: context.policeTextPrimary),
        ),
        if (sub != null && sub.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            sub,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? context.policeTextSecondary : const Color(0xFF6B7280),
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRow(int rowIndex, List<FormFieldDefinition> rowFields, bool isDark, bool ur) {
    if (rowFields.isEmpty) return const SizedBox.shrink();
    if (rowFields.length == 1 && rowFields.first.type == FormFieldType.table) {
      return _InvestigationNotebookTable(
        key: const ValueKey('builtin_investigation_table'),
        field: rowFields.first,
        isUrdu: ur,
        isDark: isDark,
        lang: _lang,
        controllers: _controllers,
        focusNodes: _focusNodes,
        onFirstInteraction: () {
          if (_showEmptyHint) setState(() => _showEmptyHint = false);
        },
      );
    }
    if (rowFields.length == 1) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: _PremiumField(
          def: rowFields.first,
          lang: _lang,
          isUrdu: ur,
          isDark: isDark,
          onFieldInteraction: () {
            if (_showEmptyHint) setState(() => _showEmptyHint = false);
          },
          controller: _controllers[rowFields.first.id]!,
          focusNode: _focusNodes[rowFields.first.id]!,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _PremiumField(
              def: rowFields[0],
              lang: _lang,
              isUrdu: ur,
              isDark: isDark,
              onFieldInteraction: () {
                if (_showEmptyHint) setState(() => _showEmptyHint = false);
              },
              controller: _controllers[rowFields[0].id]!,
              focusNode: _focusNodes[rowFields[0].id]!,
            ),
          ),
          const SizedBox(width: 16),
          if (rowFields.length > 1)
            Expanded(
              child: _PremiumField(
                def: rowFields[1],
                lang: _lang,
                isUrdu: ur,
                isDark: isDark,
                onFieldInteraction: () {
                  if (_showEmptyHint) setState(() => _showEmptyHint = false);
                },
                controller: _controllers[rowFields[1].id]!,
                focusNode: _focusNodes[rowFields[1].id]!,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Widgets ─────────────────────────────────────────────────

class _BottomPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _BottomPrimaryButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        backgroundColor: AppColors.accent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(label, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
    );
  }
}

class _BottomOutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _BottomOutlineButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        side: const BorderSide(color: AppColors.accent, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(label, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.accent)),
    );
  }
}

class _PremiumField extends StatelessWidget {
  final FormFieldDefinition def;
  final LanguageService lang;
  final bool isUrdu;
  final bool isDark;
  final VoidCallback onFieldInteraction;
  final TextEditingController controller;
  final FocusNode focusNode;

  const _PremiumField({
    required this.def,
    required this.lang,
    required this.isUrdu,
    required this.isDark,
    required this.onFieldInteraction,
    required this.controller,
    required this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final label = isUrdu ? def.labelUrdu : def.labelEnglish;
    return Column(
      crossAxisAlignment: isUrdu ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          textAlign: isUrdu ? TextAlign.right : TextAlign.left,
          style: isUrdu
              ? lang.urduStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? context.policeTextSecondary : _kLabel,
                  )
              : GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? context.policeTextSecondary : _kLabel,
                  height: 1.3,
                ),
        ),
        const SizedBox(height: 8),
        AnimatedBuilder(
          animation: Listenable.merge([focusNode, controller]),
          builder: (context, _) {
            final focused = focusNode.hasFocus;
            return Container(
              constraints: const BoxConstraints(minHeight: 48),
              alignment: isUrdu ? Alignment.centerRight : Alignment.centerLeft,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: focused ? _kLineFocus : (isDark ? context.policeBorder : _kLineIdle),
                    width: 1.5,
                  ),
                ),
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                onTap: onFieldInteraction,
                minLines: 1,
                maxLines: 1,
                textAlign: isUrdu ? TextAlign.right : TextAlign.left,
                textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
                style: isUrdu
                    ? lang.urduStyle(
                          fontSize: 18,
                          color: isDark ? context.policeTextPrimary : _kFieldText,
                        )
                    : GoogleFonts.inter(
                        fontSize: 18,
                        color: isDark ? context.policeTextPrimary : _kFieldText,
                      ),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                  hintText: '',
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// One ruled “notebook” for circumstances + two tall side columns; no per-row numbers.
class _InvestigationNotebookTable extends StatelessWidget {
  static const double _rowMinHeight = 360;
  static const double _lineHeight = 25;
  static const double _bodyFont = 15;

  final FormFieldDefinition field;
  final bool isUrdu;
  final bool isDark;
  final LanguageService lang;
  final Map<String, TextEditingController> controllers;
  final Map<String, FocusNode> focusNodes;
  final VoidCallback onFirstInteraction;

  const _InvestigationNotebookTable({
    super.key,
    required this.field,
    required this.isUrdu,
    required this.isDark,
    required this.lang,
    required this.controllers,
    required this.focusNodes,
    required this.onFirstInteraction,
  });

  @override
  Widget build(BuildContext context) {
    final cols = field.tableColumns ?? [];
    if (cols.isEmpty) return const SizedBox.shrink();
    final lineColor = isDark ? context.policeBorder : const Color(0xFFE5E7EB);
    final nKey = tableNarrativeKey(field.id);
    final sKey = tableSerialKey(field.id);
    final dKey = tableDatetimeKey(field.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Column(
          crossAxisAlignment: isUrdu ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              isUrdu ? 'حالات تفتیش' : 'Investigation Circumstances',
              style: isUrdu
                  ? lang.urduStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.accent)
                  : GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.accent),
            ),
            const SizedBox(height: 4),
            Container(
              height: 2,
              color: AppColors.accent.withValues(alpha: 0.4),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Table(
            border: TableBorder.all(color: lineColor),
            columnWidths: const {
              0: FlexColumnWidth(2.0),
              1: FlexColumnWidth(1.2),
              2: FlexColumnWidth(1.2),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.top,
            children: [
              TableRow(
                decoration: BoxDecoration(
                  color: isDark ? context.policeIconButtonBg : const Color(0xFFF8F9FA),
                ),
                children: [
                  _thCell(context, cols[0], isUrdu, lang, leftAlign: !isUrdu),
                  _thCell(context, cols[1], isUrdu, lang, center: true),
                  _thCell(context, cols[2], isUrdu, lang, center: true),
                ],
              ),
              TableRow(
                children: [
                  _ruledNarrativeCell(
                    context: context,
                    keyName: nKey,
                    isUrdu: isUrdu,
                    isDark: isDark,
                    lang: lang,
                    lineColor: lineColor,
                    onFirst: onFirstInteraction,
                  ),
                  _sideTallCell(
                    context: context,
                    keyName: sKey,
                    isUrdu: isUrdu,
                    isDark: isDark,
                    lang: lang,
                    center: true,
                    onFirst: onFirstInteraction,
                  ),
                  _sideTallCell(
                    context: context,
                    keyName: dKey,
                    isUrdu: isUrdu,
                    isDark: isDark,
                    lang: lang,
                    center: true,
                    onFirst: onFirstInteraction,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  static Widget _thCell(
    BuildContext context,
    FormTableColumnDef c,
    bool isUrdu,
    LanguageService lang, {
    bool center = false,
    bool leftAlign = false,
  }) {
    final t = isUrdu ? c.labelUrdu : c.labelEnglish;
    final align = center
        ? TextAlign.center
        : (isUrdu
            ? TextAlign.right
            : (leftAlign ? TextAlign.left : TextAlign.left));
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
      child: Text(
        t,
        textAlign: align,
        maxLines: 4,
        softWrap: true,
        style: isUrdu
            ? lang
                .urduStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: context.isPoliceDark ? context.policeTextPrimary : const Color(0xFF374151),
                )
                .copyWith(height: 1.25)
            : GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: context.isPoliceDark ? context.policeTextPrimary : const Color(0xFF374151),
                height: 1.2,
              ),
      ),
    );
  }

  Widget _ruledNarrativeCell({
    required BuildContext context,
    required String keyName,
    required bool isUrdu,
    required bool isDark,
    required LanguageService lang,
    required Color lineColor,
    required VoidCallback onFirst,
  }) {
    return SizedBox(
      height: _rowMinHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _RuledPaperPainter(
              lineColor: lineColor,
              lineHeight: _lineHeight,
            ),
          ),
          TextField(
            controller: controllers[keyName],
            focusNode: focusNodes[keyName],
            onTap: onFirst,
            maxLines: null,
            expands: true,
            textAlign: isUrdu ? TextAlign.right : TextAlign.left,
            textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            style: isUrdu
                ? lang
                    .urduStyle(
                      fontSize: _bodyFont,
                      color: isDark ? context.policeTextPrimary : _kFieldText,
                    )
                    .copyWith(height: _lineHeight / _bodyFont)
                : GoogleFonts.inter(
                    fontSize: _bodyFont,
                    height: _lineHeight / _bodyFont,
                    color: isDark ? context.policeTextPrimary : _kFieldText,
                  ),
            cursorColor: _kLineFocus,
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              filled: true,
              fillColor: isDark ? Colors.transparent : Colors.transparent,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sideTallCell({
    required BuildContext context,
    required String keyName,
    required bool isUrdu,
    required bool isDark,
    required LanguageService lang,
    required bool center,
    required VoidCallback onFirst,
  }) {
    return SizedBox(
      height: _rowMinHeight,
      child: TextField(
        controller: controllers[keyName],
        focusNode: focusNodes[keyName],
        onTap: onFirst,
        maxLines: null,
        expands: true,
        textAlign: center ? TextAlign.center : (isUrdu ? TextAlign.right : TextAlign.left),
        textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        style: isUrdu
            ? lang
                .urduStyle(
                  fontSize: 14,
                  color: isDark ? context.policeTextPrimary : _kFieldText,
                )
                .copyWith(height: 1.45)
            : GoogleFonts.inter(
                fontSize: 14,
                height: 1.45,
                color: isDark ? context.policeTextPrimary : _kFieldText,
              ),
        cursorColor: _kLineFocus,
        decoration: const InputDecoration(
          border: InputBorder.none,
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        ),
      ),
    );
  }
}

class _RuledPaperPainter extends CustomPainter {
  final Color lineColor;
  final double lineHeight;

  _RuledPaperPainter({required this.lineColor, required this.lineHeight});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = lineColor
      ..strokeWidth = 1
      ..isAntiAlias = true;
    for (var y = lineHeight; y < size.height; y += lineHeight) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant _RuledPaperPainter oldDelegate) {
    return oldDelegate.lineColor != lineColor || oldDelegate.lineHeight != lineHeight;
  }
}
