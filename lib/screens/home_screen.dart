import 'dart:async';
import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/theme_context.dart';
import '../models/case_record.dart';
import '../services/language_service.dart';
import '../main.dart';
import '../widgets/confirm_button.dart';
import '../widgets/section_label.dart';
import '../widgets/glass_card.dart';
import '../widgets/font_picker_button.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/export_bottom_sheet.dart';
import '../widgets/format_picker_bottom_sheet.dart';
import '../widgets/language_toggle.dart';
import '../models/case_reference.dart';
import '../services/document_format_service.dart';
import '../services/home_draft_service.dart';
import 'document_format_studio_screen.dart';
import 'scanned_format_editor_screen.dart';
import 'builtin_form_screen.dart';

enum _ActiveField { reference, heading, paragraph }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final _referenceController = TextEditingController();
  final _headingController = TextEditingController();
  final _paragraphController = TextEditingController();
  final _referenceFocus = FocusNode();
  final _headingFocus = FocusNode();
  final _paragraphFocus = FocusNode();

  final SpeechToText _speech = SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;
  bool _wantListening = false;
  _ActiveField? _recordingField;
  String _textBeforeListening = '';
  int _listenGeneration = 0;

  int _headingFontIndex = 0;
  int _paragraphFontIndex = 0;

  final LanguageService _lang = LanguageService();

  /// `null` = user has not chosen a format for this draft yet. `''` = explicit "no format". Else = format id.
  String? _sessionFormatId;

  /// Filled text for current session when using a scanned format with [DocumentFormatTemplate.scannedFields].
  final Map<String, String> _sessionScannedFieldValues = {};

  /// First visit (no saved draft): show format picker once.
  bool _initialFormatPromptDone = false;

  Timer? _draftSaveTimer;
  bool _restoringDraft = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic));
    _fadeController.forward();

    _lang.addListener(_onLangChanged);
    _lang.init();
    _initSpeech();
    _referenceController.addListener(_onDraftFieldsChanged);
    _headingController.addListener(_onDraftFieldsChanged);
    _paragraphController.addListener(_onDraftFieldsChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapDraftAndPicker());
  }

  @override
  void dispose() {
    _draftSaveTimer?.cancel();
    _referenceController.removeListener(_onDraftFieldsChanged);
    _headingController.removeListener(_onDraftFieldsChanged);
    _paragraphController.removeListener(_onDraftFieldsChanged);
    _referenceController.dispose();
    _headingController.dispose();
    _paragraphController.dispose();
    _referenceFocus.dispose();
    _headingFocus.dispose();
    _paragraphFocus.dispose();
    _fadeController.dispose();
    _lang.removeListener(_onLangChanged);
    _speech.stop();
    super.dispose();
  }

  void _onLangChanged() => setState(() {});

  int _fontIndexByName(String name) {
    final i = availableFonts.indexWhere((f) => f.displayName == name);
    return i < 0 ? 0 : i;
  }

  void _onDraftFieldsChanged() {
    if (_restoringDraft) return;
    _draftSaveTimer?.cancel();
    _draftSaveTimer = Timer(const Duration(milliseconds: 650), _persistDraft);
  }

  Future<void> _persistDraft() {
    return HomeDraftService.save(
      reference: _referenceController.text,
      heading: _headingController.text,
      details: _paragraphController.text,
      headingFontName: availableFonts[_headingFontIndex].displayName,
      paragraphFontName: availableFonts[_paragraphFontIndex].displayName,
      sessionFormatId: _sessionFormatId,
      sessionScannedFieldValuesJson: _sessionScannedFieldValues.isEmpty
          ? null
          : jsonEncode(_sessionScannedFieldValues),
    );
  }

  /// Restore a saved draft or show the format picker the first time (no draft).
  Future<void> _bootstrapDraftAndPicker() async {
    if (!mounted) return;
    if (_initialFormatPromptDone) return;
    final snap = await HomeDraftService.load();
    if (!mounted) return;
    if (snap != null && snap.hasWork) {
      _restoringDraft = true;
      _referenceController.text = snap.reference;
      _headingController.text = snap.heading;
      _paragraphController.text = snap.details;
      _headingFontIndex = _fontIndexByName(snap.headingFontName);
      _paragraphFontIndex = _fontIndexByName(snap.paragraphFontName);
      _sessionScannedFieldValues.clear();
      _decodeSnapshotScanned(snap);
      setState(() {
        _sessionFormatId = snap.sessionFormatId;
        _restoringDraft = false;
        _initialFormatPromptDone = true;
      });
      if (mounted) {
        _showSnack(_lang.draftRestoredMessage, AppColors.accent);
      }
      return;
    }
    _initialFormatPromptDone = true;
    if (!mounted) return;
    _openFormatPicker();
  }

  // ── Speech ───────────────────────────────────────────────
  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onError: _onSpeechError,
      onStatus: _onSpeechStatus,
    );
    setState(() {});
  }

  void _onSpeechError(SpeechRecognitionError error) {
    debugPrint('Speech error: ${error.errorMsg}');
    if (!_wantListening || _recordingField == null) {
      _stopListening();
      return;
    }

    if (error.errorMsg == 'error_busy') {
      _scheduleRestart(delayMs: 300);
      return;
    }

    if (error.errorMsg == 'error_speech_timeout' || error.errorMsg == 'error_no_match') {
      _scheduleRestart();
      return;
    }

    _scheduleRestart();
  }

  void _onSpeechStatus(String status) {
    if (!mounted) return;
    if (status == 'listening' && _isListening == false) {
      setState(() => _isListening = true);
      return;
    }

    if (status == 'notListening' || status == 'done') {
      setState(() => _isListening = false);
      if (_wantListening && _recordingField != null) {
        _scheduleRestart(delayMs: 150);
      }
    }
  }

  TextEditingController _controllerFor(_ActiveField field) {
    switch (field) {
      case _ActiveField.reference:
        return _referenceController;
      case _ActiveField.heading:
        return _headingController;
      case _ActiveField.paragraph:
        return _paragraphController;
    }
  }

  void _toggleListeningForField(_ActiveField field) {
    if (!_speechAvailable) {
      _showSnack('Speech recognition is not available on this device.', AppColors.error);
      return;
    }

    if (_wantListening && _recordingField == field) {
      _stopListening();
      return;
    }

    if (_wantListening && _recordingField != field) {
      _stopListening();
    }

    _recordingField = field;
    _textBeforeListening = _controllerFor(field).text;
    setState(() {
      _wantListening = true;
      _isListening = true;
    });
    _listenGeneration += 1;
    _startListenSession(generation: _listenGeneration);
  }

  void _startListenSession({required int generation}) {
    if (!_wantListening || _recordingField == null || generation != _listenGeneration) return;
    _speech.listen(
      onResult: _onSpeechResult,
      localeId: _lang.isUrdu ? 'ur_PK' : 'en_US',
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 8),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        listenMode: ListenMode.dictation,
      ),
    );
  }

  void _scheduleRestart({int delayMs = 150}) {
    final generation = _listenGeneration;
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (!mounted) return;
      if (!_wantListening || _recordingField == null) return;
      if (generation != _listenGeneration) return;
      _textBeforeListening = _controllerFor(_recordingField!).text;
      _startListenSession(generation: generation);
    });
  }

  void _stopListening() {
    _wantListening = false;
    _listenGeneration += 1;
    _speech.stop();
    setState(() {
      _isListening = false;
      _recordingField = null;
    });
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    final recognised = result.recognizedWords;
    final activeField = _recordingField;
    if (recognised.isEmpty || activeField == null) return;

    final controller = _controllerFor(activeField);
    final cleaned = (activeField == _ActiveField.heading || activeField == _ActiveField.reference)
        ? recognised.replaceAll('\n', ' ').trim()
        : recognised.trim();
    final sep = _textBeforeListening.isEmpty ? '' : ' ';
    controller.text = _textBeforeListening + sep + cleaned;

    controller.selection = TextSelection.fromPosition(
      TextPosition(offset: controller.text.length),
    );

    if (result.finalResult) {
      _textBeforeListening = controller.text;
    }
  }

  // ── Confirm → Save ───────────────────────────────────────
  Future<void> _onConfirm() async {
    if (_sessionFormatId == null) {
      _showSnack(
        _lang.isUrdu ? 'پہلے فارمیٹ منتخب کریں' : 'Choose a format first (or No format).',
        AppColors.primaryLight,
      );
      return;
    }

    final heading = _headingController.text.trim();
    final paragraph = _paragraphController.text.trim();

    if (heading.isEmpty && paragraph.isEmpty) {
      _showSnack(
        _lang.isUrdu ? 'پہلے عنوان یا تفصیلات شامل کریں' : 'Please add a heading or details first.',
        AppColors.primaryLight,
      );
      return;
    }

    if (_wantListening) _stopListening();

    final confirmed = await showConfirmDialog(context, lang: _lang);
    if (!confirmed) return;

    final box = Hive.box<CaseRecord>('cases');
    final customRef = _referenceController.text.trim();
    final year = DateTime.now().year;
    final refStored = customRef.isNotEmpty
        ? customRef
        : CaseReference.formatAuto(box.length + 1, year);

    final sid = _sessionFormatId ?? '';
    final fmtName = sid.isEmpty ? '' : (DocumentFormatService().getById(sid)?.name ?? sid);

    final record = CaseRecord(
      heading: heading,
      details: paragraph,
      headingFont: availableFonts[_headingFontIndex].displayName,
      detailsFont: availableFonts[_paragraphFontIndex].displayName,
      savedAt: DateTime.now(),
      caseLanguage: _lang.code,
      caseReferenceNo: refStored,
      caseFormatId: sid,
      caseFormatName: fmtName,
      scannedFieldValues: Map<String, String>.from(_sessionScannedFieldValues),
    );

    await box.add(record);
    if (sid.isNotEmpty) {
      await DocumentFormatService().recordFormatUsedInSavedCase(sid);
    }
    final caseNumber = box.length;
    await HomeDraftService.clear();
    if (mounted) {
      HapticFeedback.mediumImpact();
    }

    _referenceController.clear();
    _headingController.clear();
    _paragraphController.clear();
    _sessionScannedFieldValues.clear();
    setState(() {
      _sessionFormatId = null;
      _isListening = false;
      _wantListening = false;
      _recordingField = null;
    });

    if (!mounted) return;

    await showExportSheet(context, record: record, caseNumber: caseNumber, lang: _lang);
    if (!mounted) return;
    AppShell.switchToTab(context, 1);
  }

  Future<void> _openFormatPicker() async {
    final id = await showFormatPickerBottomSheet(context: context, lang: _lang);
    if (!mounted || id == null) return;
    _sessionScannedFieldValues.clear();
    if (id.isNotEmpty) {
      final fmt = DocumentFormatService().getById(id);
      if (fmt != null && fmt.hasBuiltinFormFields) {
        await Navigator.of(context).push<void>(
          PageRouteBuilder<void>(
            pageBuilder: (_, __, ___) => BuiltinFormScreen(format: fmt),
            transitionDuration: const Duration(milliseconds: 380),
            reverseTransitionDuration: const Duration(milliseconds: 300),
            transitionsBuilder: (_, anim, __, child) {
              return FadeTransition(
                opacity: CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
                child: child,
              );
            },
            opaque: true,
            fullscreenDialog: true,
          ),
        );
        return;
      }
    }
    setState(() => _sessionFormatId = id);
    if (id.isNotEmpty) {
      final fmt = DocumentFormatService().getById(id);
      if (fmt != null && fmt.isScan && fmt.scannedFields.isNotEmpty) {
        final values = await Navigator.of(context).push<Map<String, String>?>(
          PageRouteBuilder<Map<String, String>?>(
            pageBuilder: (_, __, ___) => ScannedFormatEditorScreen(
              formatId: id,
              mode: ScannedFormatEditorMode.fillCase,
              initialScannedFieldValues: const {},
            ),
            transitionDuration: const Duration(milliseconds: 380),
            reverseTransitionDuration: const Duration(milliseconds: 300),
            transitionsBuilder: (_, anim, __, child) {
              return FadeTransition(
                opacity: CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
                child: child,
              );
            },
            opaque: true,
            fullscreenDialog: true,
          ),
        );
        if (!mounted) return;
        if (values == null) {
          setState(() {
            _sessionFormatId = null;
            _sessionScannedFieldValues.clear();
          });
          _onDraftFieldsChanged();
          return;
        }
        _sessionScannedFieldValues
          ..clear()
          ..addAll(values);
      }
    }
    _onDraftFieldsChanged();
  }

  void _startNewCase() {
    unawaited(HomeDraftService.clear());
    _referenceController.clear();
    _headingController.clear();
    _paragraphController.clear();
    if (_wantListening) _stopListening();
    _sessionScannedFieldValues.clear();
    setState(() => _sessionFormatId = null);
    _openFormatPicker();
  }

  void _clearSessionFormat() {
    if (_wantListening) _stopListening();
    _sessionScannedFieldValues.clear();
    setState(() => _sessionFormatId = null);
    _onDraftFieldsChanged();
  }

  void _decodeSnapshotScanned(HomeDraftSnapshot snap) {
    final raw = snap.sessionScannedFieldValuesJson;
    if (raw == null || raw.isEmpty) return;
    try {
      final o = jsonDecode(raw);
      if (o is! Map) return;
      o.forEach((k, v) {
        _sessionScannedFieldValues[k.toString()] = v?.toString() ?? '';
      });
    } catch (_) {}
  }

  void _showSnack(String msg, Color bg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: bg,
      ),
    );
  }

  TextStyle _referenceTextStyle(BuildContext context) {
    final c = context.policeTextPrimary;
    if (_lang.isUrdu) {
      return _lang.urduStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c);
    }
    return GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: c);
  }

  TextStyle _headingTextStyle(BuildContext context) {
    final c = context.policeTextPrimary;
    if (_lang.isUrdu) {
      return _lang.urduStyle(fontSize: 22, fontWeight: FontWeight.w700, color: c);
    }
    return availableFonts[_headingFontIndex].builder(fontSize: 20, fontWeight: FontWeight.w700, color: c);
  }

  TextStyle _paragraphTextStyle(BuildContext context) {
    final c = context.policeTextPrimary;
    if (_lang.isUrdu) {
      return _lang.urduStyle(fontSize: 16, fontWeight: FontWeight.w400, color: c).copyWith(height: 2.0);
    }
    return availableFonts[_paragraphFontIndex].builder(fontSize: 15, fontWeight: FontWeight.w400, color: c).copyWith(height: 1.7);
  }

  // ── Build ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildHeader()),
                if (_sessionFormatId != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: _buildFormatBadgeBar(),
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const SizedBox(height: 8),
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 420),
                        curve: Curves.easeOutCubic,
                        opacity: _sessionFormatId != null ? 1.0 : 0.38,
                        child: IgnorePointer(
                          ignoring: _sessionFormatId == null,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (!_speechAvailable) ...[
                                _buildMicPermissionBanner(),
                                const SizedBox(height: 20),
                              ],
                              _buildReferenceSection(),
                              const SizedBox(height: 28),
                              _buildHeadingSection(),
                              const SizedBox(height: 28),
                              _buildParagraphSection(),
                              const SizedBox(height: 36),
                              _buildConfirmSection(),
                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    // Title row is only icon + text. Actions sit on the next row so Expanded always
    // gets real width (single Row with many trailing controls can leave title width ~0).
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.shield_rounded, color: AppColors.accent, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Case Documentation',
                      maxLines: 2,
                      softWrap: true,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ) ??
                          Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _sessionFormatId == null
                          ? _lang.newCaseStartSubtitle
                          : 'Record and document case details',
                      maxLines: 3,
                      softWrap: true,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _startNewCase,
                child: Text(
                  _lang.newCaseNavButton,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Material(
                color: Colors.transparent,
                child: IconButton(
                  onPressed: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(builder: (_) => const DocumentFormatStudioScreen()),
                    );
                  },
                  tooltip: _lang.isUrdu ? 'دستاویز کے فارمیٹ' : 'Document formats (scan or build header)',
                  icon: Icon(
                    Icons.document_scanner_outlined,
                    size: 22,
                    color: context.policeTextSecondary,
                  ),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              ),
              const SizedBox(width: 2),
              _buildLanguageToggle(),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            height: 3,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: LinearGradient(
                colors: [AppColors.accent, AppColors.accent.withValues(alpha: 0.0)],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Shown under the main title block while a format (or “No format”) is active.
  Widget _buildFormatBadgeBar() {
    final sid = _sessionFormatId;
    if (sid == null) return const SizedBox.shrink();
    final svc = DocumentFormatService();
    final name = sid.isEmpty ? _lang.sessionBadgeNoFormat : (svc.getById(sid)?.name ?? sid);
    return ListenableBuilder(
      listenable: DocumentFormatService(),
      builder: (context, _) {
        return Material(
          color: context.policeCard,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.policeBorder.withValues(alpha: 0.85)),
            ),
            child: Row(
              children: [
                const Icon(Icons.description_outlined, size: 18, color: AppColors.accent),
                const SizedBox(width: 6),
                Expanded(
                  child: InkWell(
                    onTap: _openFormatPicker,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: context.policeTextPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _clearSessionFormat,
                  tooltip: _lang.clearActiveFormatA11y,
                  icon: Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: context.policeTextSecondary,
                  ),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(4),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLanguageToggle() {
    return LanguageToggle(lang: _lang);
  }

  Widget _buildReferenceSection() {
    final isLive = _wantListening && _recordingField == _ActiveField.reference;
    final dir = _lang.textDirection;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SectionLabel(text: _lang.caseReferenceLabel, icon: Icons.tag_rounded),
          ],
        ),
        const SizedBox(height: 4),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: isLive ? Border.all(color: AppColors.accent, width: 2) : null,
            boxShadow: isLive
                ? [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.22),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: GlassCard(
            padding: EdgeInsets.zero,
            child: TextField(
              controller: _referenceController,
              focusNode: _referenceFocus,
              maxLines: 1,
              textDirection: dir,
              textAlign: _lang.isUrdu ? TextAlign.right : TextAlign.left,
              style: _referenceTextStyle(context),
              decoration: InputDecoration(
                hintText: _lang.caseReferenceHint,
                hintTextDirection: dir,
                hintStyle: _referenceTextStyle(context).copyWith(color: context.policeTextHint.withValues(alpha: 0.5)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                suffixIcon: _buildInlineMicButton(_ActiveField.reference),
                suffixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              ),
              textInputAction: TextInputAction.next,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMicPermissionBanner() {
    return GestureDetector(
      onTap: () => AppSettings.openAppSettings(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.2), width: 1),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _lang.micPermissionText,
                textDirection: _lang.textDirection,
                style: _lang.isUrdu
                    ? _lang.urduStyle(fontSize: 12, color: context.policeTextSecondary)
                    : GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: context.policeTextSecondary, height: 1.4),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.open_in_new_rounded, color: AppColors.warning, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildHeadingSection() {
    final isLive = _wantListening && _recordingField == _ActiveField.heading;
    final dir = _lang.textDirection;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SectionLabel(text: _lang.caseHeadingLabel, icon: Icons.title_rounded),
            const SizedBox(width: 8),
            if (!_lang.isUrdu)
              FontPickerButton(
                selectedIndex: _headingFontIndex,
                onChanged: (i) {
                  setState(() => _headingFontIndex = i);
                  _onDraftFieldsChanged();
                },
              ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          margin: const EdgeInsets.only(bottom: 10, left: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(6)),
          child: Text(_lang.isUrdu ? 'عنوان' : 'B', style: _lang.isUrdu
              ? _lang.urduStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)
              : GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: isLive ? Border.all(color: AppColors.accent, width: 2) : null,
            boxShadow: isLive
                ? [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.22),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: GlassCard(
            padding: EdgeInsets.zero,
            child: TextField(
              controller: _headingController,
              focusNode: _headingFocus,
              maxLines: 1,
              textDirection: dir,
              textAlign: _lang.isUrdu ? TextAlign.right : TextAlign.left,
              style: _headingTextStyle(context),
              decoration: InputDecoration(
                hintText: _lang.headingHint,
                hintTextDirection: dir,
                hintStyle: _headingTextStyle(context).copyWith(color: context.policeTextHint.withValues(alpha: 0.5)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                suffixIcon: _buildInlineMicButton(_ActiveField.heading),
                suffixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              ),
              textInputAction: TextInputAction.next,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildParagraphSection() {
    final isLive = _wantListening && _recordingField == _ActiveField.paragraph;
    final dir = _lang.textDirection;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SectionLabel(text: _lang.caseDetailsLabel, icon: Icons.notes_rounded),
            const SizedBox(width: 8),
            if (!_lang.isUrdu)
              FontPickerButton(
                selectedIndex: _paragraphFontIndex,
                onChanged: (i) {
                  setState(() => _paragraphFontIndex = i);
                  _onDraftFieldsChanged();
                },
              ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          margin: const EdgeInsets.only(bottom: 10, left: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(6)),
          child: Text(_lang.isUrdu ? 'تفصیل' : 'Normal', style: _lang.isUrdu
              ? _lang.urduStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary)
              : GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: isLive ? Border.all(color: AppColors.accent, width: 2) : null,
            boxShadow: isLive
                ? [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.22),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: GlassCard(
            padding: EdgeInsets.zero,
            child: TextField(
              controller: _paragraphController,
              focusNode: _paragraphFocus,
              maxLines: 6,
              textDirection: dir,
              textAlign: _lang.isUrdu ? TextAlign.right : TextAlign.left,
              style: _paragraphTextStyle(context),
              decoration: InputDecoration(
                hintText: _lang.detailsHint,
                hintTextDirection: dir,
                hintStyle: _paragraphTextStyle(context).copyWith(color: context.policeTextHint.withValues(alpha: 0.5)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.fromLTRB(20, 20, 8, 20),
                suffixIcon: _buildInlineMicButton(_ActiveField.paragraph),
                suffixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInlineMicButton(_ActiveField field) {
    final isActive = _wantListening && _recordingField == field;
    final iconColor = isActive ? AppColors.error : AppColors.accent;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: () => _toggleListeningForField(field),
        child: SizedBox(
          width: 28,
          height: 28,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Align(
                alignment: Alignment.center,
                child: Icon(Icons.mic_rounded, size: 24, color: iconColor),
              ),
              if (isActive)
                Positioned(
                  right: 1,
                  top: 2,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 220),
                    opacity: _isListening ? 1 : 0.45,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmSection() {
    return ConfirmButton(
      onPressed: _onConfirm,
      enabled: _sessionFormatId != null,
      label: _lang.confirmLabel,
    );
  }
}
