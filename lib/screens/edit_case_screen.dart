import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import '../core/constants.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/theme_context.dart';
import '../models/case_record.dart';
import '../services/language_service.dart';
import '../widgets/confirm_button.dart';
import '../widgets/section_label.dart';
import '../widgets/glass_card.dart';
import '../widgets/font_picker_button.dart';
import '../widgets/case_media_section.dart';
import '../widgets/language_toggle.dart';
enum _ActiveField { reference, heading, paragraph }

class EditCaseScreen extends StatefulWidget {
  final CaseRecord record;
  final int caseNumber;

  const EditCaseScreen({super.key, required this.record, required this.caseNumber});

  @override
  State<EditCaseScreen> createState() => _EditCaseScreenState();
}

class _EditCaseScreenState extends State<EditCaseScreen> with TickerProviderStateMixin {
  late TextEditingController _referenceController;
  late TextEditingController _headingController;
  late TextEditingController _paragraphController;
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

  late int _headingFontIndex;
  late int _paragraphFontIndex;

  final LanguageService _lang = LanguageService();

  late final String _originalHeading;
  late final String _originalDetails;
  late final String _originalReference;

  bool get _hasUnsavedChanges =>
      _referenceController.text != _originalReference ||
      _headingController.text != _originalHeading ||
      _paragraphController.text != _originalDetails;

  @override
  void initState() {
    super.initState();
    _originalHeading = widget.record.heading;
    _originalDetails = widget.record.details;
    _originalReference = widget.record.caseReferenceNo;

    _referenceController = TextEditingController(text: _originalReference);
    _headingController = TextEditingController(text: _originalHeading);
    _paragraphController = TextEditingController(text: _originalDetails);

    _headingFontIndex = availableFonts.indexWhere((f) => f.displayName == widget.record.headingFont);
    if (_headingFontIndex < 0) _headingFontIndex = 0;
    _paragraphFontIndex = availableFonts.indexWhere((f) => f.displayName == widget.record.detailsFont);
    if (_paragraphFontIndex < 0) _paragraphFontIndex = 0;

    _lang.addListener(_onLangChanged);
    _lang.init();
    _initSpeech();
  }

  @override
  void dispose() {
    _referenceController.dispose();
    _headingController.dispose();
    _paragraphController.dispose();
    _referenceFocus.dispose();
    _headingFocus.dispose();
    _paragraphFocus.dispose();
    _lang.removeListener(_onLangChanged);
    _speech.stop();
    super.dispose();
  }

  void _onLangChanged() => setState(() {});

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

  Future<void> _onSave() async {
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

    final confirmed = await _showSaveConfirmDialog();
    if (!confirmed) return;

    widget.record.caseReferenceNo = _referenceController.text.trim();
    widget.record.heading = heading;
    widget.record.details = paragraph;
    widget.record.headingFont = availableFonts[_headingFontIndex].displayName;
    widget.record.detailsFont = availableFonts[_paragraphFontIndex].displayName;
    widget.record.caseLanguage = _lang.code;
    widget.record.editCount += 1;
    widget.record.lastEditedAt = DateTime.now();
    await widget.record.save();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(_lang.caseUpdatedText),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: AppColors.success,
    ));

    Navigator.of(context).pop();
  }

  Future<bool> _showSaveConfirmDialog() async {
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
              child: FadeTransition(
                opacity: anim,
                child: _SaveDialogContent(lang: _lang),
              ),
            );
          },
        ) ??
        false;
  }

  Future<bool> _showDiscardDialog() async {
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
              child: FadeTransition(
                opacity: anim,
                child: _DiscardDialogContent(lang: _lang),
              ),
            );
          },
        ) ??
        false;
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (!_hasUnsavedChanges) {
          nav.pop();
          return;
        }
        final discard = await _showDiscardDialog();
        if (discard && mounted) {
          nav.pop();
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          const SizedBox(height: 16),
                          if (!_speechAvailable) ...[
                            _MicPermissionBanner(lang: _lang),
                            const SizedBox(height: 20),
                          ],
                          _buildReferenceSection(),
                          const SizedBox(height: 28),
                          _buildHeadingSection(),
                          const SizedBox(height: 28),
                          _buildParagraphSection(),
                          if (kMediaEnabled && widget.record.key != null) ...[
                            const SizedBox(height: 20),
                            CaseMediaSection(
                              caseId: widget.record.key.toString(),
                              isEditable: true,
                            ),
                          ],
                          const SizedBox(height: 36),
                          ConfirmButton(
                            onPressed: _onSave,
                            enabled: true,
                            label: _lang.saveChangesLabel,
                          ),
                          const SizedBox(height: 40),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              if (!_hasUnsavedChanges) {
                Navigator.of(context).pop();
                return;
              }
              _showDiscardDialog().then((discard) {
                if (discard && mounted) Navigator.of(context).pop();
              });
            },
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.policeIconButtonBg,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Icon(Icons.arrow_back_rounded, size: 20, color: context.policeTextPrimary),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _lang.editCaseTitle,
              style: _lang.isUrdu
                  ? _lang.urduStyle(fontSize: 18, fontWeight: FontWeight.w700, color: context.policeTextPrimary)
                  : GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: context.policeTextPrimary),
              textDirection: _lang.textDirection,
            ),
          ),
          LanguageToggle(lang: _lang),
        ],
      ),
    );
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
            if (!_lang.isUrdu) FontPickerButton(selectedIndex: _headingFontIndex, onChanged: (i) => setState(() => _headingFontIndex = i)),
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
            if (!_lang.isUrdu) FontPickerButton(selectedIndex: _paragraphFontIndex, onChanged: (i) => setState(() => _paragraphFontIndex = i)),
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
}

class _MicPermissionBanner extends StatelessWidget {
  final LanguageService lang;
  const _MicPermissionBanner({required this.lang});

  @override
  Widget build(BuildContext context) {
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
                lang.micPermissionText,
                textDirection: lang.textDirection,
                style: lang.isUrdu
                    ? lang.urduStyle(fontSize: 12, color: context.policeTextSecondary)
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
}

class _DiscardDialogContent extends StatelessWidget {
  final LanguageService lang;
  const _DiscardDialogContent({required this.lang});

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
                decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.08), shape: BoxShape.circle),
                child: const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 40),
              ),
              const SizedBox(height: 20),
              Text(
                lang.discardChangesTitle,
                textAlign: TextAlign.center,
                textDirection: lang.textDirection,
                style: lang.isUrdu
                    ? lang.urduStyle(fontSize: 20, fontWeight: FontWeight.w700, color: context.policeTextPrimary)
                    : GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: context.policeTextPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                lang.discardChangesBody,
                textAlign: TextAlign.center,
                textDirection: lang.textDirection,
                style: lang.isUrdu
                    ? lang.urduStyle(fontSize: 14, color: context.policeTextSecondary)
                    : GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, color: context.policeTextSecondary, height: 1.5),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(child: _DialogBtn(label: lang.keepEditingText, onTap: () => Navigator.of(context).pop(false), isPrimary: true, isUrdu: lang.isUrdu)),
                  const SizedBox(width: 12),
                  Expanded(child: _DialogBtn(label: lang.discardText, onTap: () => Navigator.of(context).pop(true), isPrimary: false, isUrdu: lang.isUrdu, isDestructive: true)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SaveDialogContent extends StatelessWidget {
  final LanguageService lang;
  const _SaveDialogContent({required this.lang});

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
                child: const Icon(Icons.edit_note_rounded, color: AppColors.accent, size: 40),
              ),
              const SizedBox(height: 20),
              Text(
                lang.saveChangesDialogTitle,
                textAlign: TextAlign.center,
                textDirection: lang.textDirection,
                style: lang.isUrdu
                    ? lang.urduStyle(fontSize: 20, fontWeight: FontWeight.w700, color: context.policeTextPrimary)
                    : GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: context.policeTextPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                lang.saveChangesDialogBody,
                textAlign: TextAlign.center,
                textDirection: lang.textDirection,
                style: lang.isUrdu
                    ? lang.urduStyle(fontSize: 14, color: context.policeTextSecondary)
                    : GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, color: context.policeTextSecondary, height: 1.5),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(child: _DialogBtn(label: lang.cancelText, onTap: () => Navigator.of(context).pop(false), isPrimary: false, isUrdu: lang.isUrdu)),
                  const SizedBox(width: 12),
                  Expanded(child: _DialogBtn(label: lang.saveText, onTap: () => Navigator.of(context).pop(true), isPrimary: true, isUrdu: lang.isUrdu)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;
  final bool isUrdu;
  final bool isDestructive;
  const _DialogBtn({required this.label, required this.onTap, required this.isPrimary, this.isUrdu = false, this.isDestructive = false});
  @override
  State<_DialogBtn> createState() => _DialogBtnState();
}

class _DialogBtnState extends State<_DialogBtn> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween(begin: 1.0, end: 0.95).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isDestructive
        ? AppColors.error
        : widget.isPrimary ? Colors.white : context.policeTextSecondary;
    final borderNeutral = context.isPoliceDark ? AppColors.darkBorder : Colors.grey.shade300;

    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) { _ctrl.reverse(); widget.onTap(); },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: widget.isPrimary ? const LinearGradient(colors: AppColors.confirmGradient) : null,
            color: widget.isPrimary ? null : Colors.transparent,
            border: widget.isPrimary ? null : Border.all(
              color: widget.isDestructive ? AppColors.error.withValues(alpha: 0.4) : borderNeutral,
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: widget.isUrdu
                ? GoogleFonts.notoNastaliqUrdu(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)
                : GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: textColor),
          ),
        ),
      ),
    );
  }
}
