import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import '../core/theme/app_colors.dart';
import '../models/case_record.dart';
import '../services/language_service.dart';
import '../widgets/pulse_mic_button.dart';
import '../widgets/confirm_button.dart';
import '../widgets/section_label.dart';
import '../widgets/glass_card.dart';
import '../widgets/font_picker_button.dart';
import '../widgets/language_toggle.dart';

enum _ActiveField { heading, paragraph }

class EditCaseScreen extends StatefulWidget {
  final CaseRecord record;
  final int caseNumber;

  const EditCaseScreen({super.key, required this.record, required this.caseNumber});

  @override
  State<EditCaseScreen> createState() => _EditCaseScreenState();
}

class _EditCaseScreenState extends State<EditCaseScreen> with TickerProviderStateMixin {
  late TextEditingController _headingController;
  late TextEditingController _paragraphController;
  final _headingFocus = FocusNode();
  final _paragraphFocus = FocusNode();

  final SpeechToText _speech = SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;
  bool _wantListening = false;

  _ActiveField? _activeField;
  String _textBeforeListening = '';
  _ActiveField? _lockedField;

  late int _headingFontIndex;
  late int _paragraphFontIndex;

  final LanguageService _lang = LanguageService();

  late final String _originalHeading;
  late final String _originalDetails;

  bool get _hasUnsavedChanges =>
      _headingController.text != _originalHeading ||
      _paragraphController.text != _originalDetails;

  @override
  void initState() {
    super.initState();
    _originalHeading = widget.record.heading;
    _originalDetails = widget.record.details;

    _headingController = TextEditingController(text: _originalHeading);
    _paragraphController = TextEditingController(text: _originalDetails);

    _headingFontIndex = availableFonts.indexWhere((f) => f.displayName == widget.record.headingFont);
    if (_headingFontIndex < 0) _headingFontIndex = 0;
    _paragraphFontIndex = availableFonts.indexWhere((f) => f.displayName == widget.record.detailsFont);
    if (_paragraphFontIndex < 0) _paragraphFontIndex = 0;

    _headingFocus.addListener(_onFocusChanged);
    _paragraphFocus.addListener(_onFocusChanged);

    _lang.addListener(_onLangChanged);
    _lang.init();
    _initSpeech();
  }

  @override
  void dispose() {
    _headingController.dispose();
    _paragraphController.dispose();
    _headingFocus.dispose();
    _paragraphFocus.dispose();
    _lang.removeListener(_onLangChanged);
    _speech.stop();
    super.dispose();
  }

  void _onLangChanged() => setState(() {});

  void _onFocusChanged() {
    if (_headingFocus.hasFocus) {
      _selectField(_ActiveField.heading);
    } else if (_paragraphFocus.hasFocus) {
      _selectField(_ActiveField.paragraph);
    }
  }

  void _selectField(_ActiveField field) {
    if (_isListening && _lockedField != field) {
      _stopListening();
    }
    setState(() => _activeField = field);
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onError: _onSpeechError,
      onStatus: _onSpeechStatus,
    );
    setState(() {});
  }

  void _onSpeechError(SpeechRecognitionError error) {
    debugPrint('Speech error: ${error.errorMsg}');
    if (_wantListening && error.errorMsg != 'error_busy') {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_wantListening && mounted) _startListenSession();
      });
    } else {
      _stopListening();
    }
  }

  void _onSpeechStatus(String status) {
    if (status == 'notListening' || status == 'done') {
      if (_wantListening && mounted) {
        _textBeforeListening = _activeController?.text ?? _textBeforeListening;
        Future.delayed(const Duration(milliseconds: 200), () {
          if (_wantListening && mounted) _startListenSession();
        });
      } else {
        setState(() => _isListening = false);
      }
    }
  }

  TextEditingController? get _activeController {
    if (_lockedField == _ActiveField.heading) return _headingController;
    if (_lockedField == _ActiveField.paragraph) return _paragraphController;
    return null;
  }

  void _toggleListening() {
    if (!_speechAvailable) return;
    if (_wantListening) {
      _stopListening();
      return;
    }
    if (_activeField == null) {
      _showSnack(
        _lang.isUrdu ? 'پہلے عنوان یا تفصیل فیلڈ منتخب کریں' : 'Tap the Heading or Details field first.',
        AppColors.primaryLight,
      );
      return;
    }
    _lockedField = _activeField;
    _textBeforeListening = _activeController?.text ?? '';
    setState(() {
      _wantListening = true;
      _isListening = true;
    });
    _startListenSession();
  }

  void _startListenSession() {
    _speech.listen(
      onResult: _onSpeechResult,
      localeId: _lang.isUrdu ? 'ur_PK' : 'en_US',
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 5),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        listenMode: ListenMode.dictation,
      ),
    );
  }

  void _stopListening() {
    _wantListening = false;
    _speech.stop();
    setState(() {
      _isListening = false;
      _lockedField = null;
    });
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    final recognised = result.recognizedWords;
    if (recognised.isEmpty || _lockedField == null) return;

    final controller = _activeController!;

    if (_lockedField == _ActiveField.heading) {
      final firstLine = recognised.split(RegExp(r'[.\n]')).first.trim();
      final sep = _textBeforeListening.isEmpty ? '' : ' ';
      controller.text = _textBeforeListening + sep + firstLine;
    } else {
      final sep = _textBeforeListening.isEmpty ? '' : ' ';
      controller.text = _textBeforeListening + sep + recognised;
    }

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

  TextStyle _headingTextStyle() {
    if (_lang.isUrdu) {
      return _lang.urduStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary);
    }
    return availableFonts[_headingFontIndex].builder(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary);
  }

  TextStyle _paragraphTextStyle() {
    if (_lang.isUrdu) {
      return _lang.urduStyle(fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.textPrimary).copyWith(height: 2.0);
    }
    return availableFonts[_paragraphFontIndex].builder(fontSize: 15, fontWeight: FontWeight.w400, color: AppColors.textPrimary).copyWith(height: 1.7);
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
        backgroundColor: AppColors.surface,
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
                          _buildVoiceSection(),
                          const SizedBox(height: 28),
                          _buildHeadingSection(),
                          const SizedBox(height: 28),
                          _buildParagraphSection(),
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: const Icon(Icons.arrow_back_rounded, size: 20, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _lang.editCaseTitle,
              style: _lang.isUrdu
                  ? _lang.urduStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)
                  : GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              textDirection: _lang.textDirection,
            ),
          ),
          LanguageToggle(lang: _lang),
        ],
      ),
    );
  }

  Widget _buildVoiceSection() {
    final hasTarget = _activeField != null;
    final targetLabel = _activeField == _ActiveField.heading
        ? _lang.caseHeadingLabel
        : _activeField == _ActiveField.paragraph
            ? _lang.caseDetailsLabel
            : _lang.noTargetText;

    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      child: Column(
        children: [
          SectionLabel(text: _lang.voiceInputLabel, icon: Icons.record_voice_over_rounded),
          const SizedBox(height: 8),
          Text(
            _isListening
                ? _lang.listeningText
                : _speechAvailable
                    ? hasTarget ? _lang.tapMicText : _lang.selectFieldText
                    : _lang.initializingText,
            style: Theme.of(context).textTheme.bodyMedium,
            textDirection: _lang.textDirection,
          ),
          const SizedBox(height: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
              _lang.targetText(targetLabel),
              key: ValueKey(targetLabel),
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: hasTarget ? AppColors.accent : AppColors.textHint),
            ),
          ),
          const SizedBox(height: 24),
          PulseMicButton(
            isListening: _isListening,
            isAvailable: _speechAvailable && hasTarget,
            onTap: _toggleListening,
          ),
          if (!_speechAvailable) ...[
            const SizedBox(height: 16),
            _MicPermissionBanner(lang: _lang),
          ],
          const SizedBox(height: 20),
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _isListening
                  ? AppColors.error.withValues(alpha: 0.08)
                  : _speechAvailable ? AppColors.accent.withValues(alpha: 0.06) : Colors.grey.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isListening ? AppColors.error : _speechAvailable ? AppColors.accent : AppColors.textHint,
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
                  style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: _isListening ? AppColors.error : _speechAvailable ? AppColors.accent : AppColors.textHint,
                  ),
                  child: Text(_isListening ? _lang.recordingText : _speechAvailable ? _lang.readyText : _lang.unavailableText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeadingSection() {
    final isTarget = _activeField == _ActiveField.heading;
    final isLive = _isListening && _lockedField == _ActiveField.heading;
    final dir = _lang.textDirection;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SectionLabel(text: _lang.caseHeadingLabel, icon: Icons.title_rounded),
            const SizedBox(width: 8),
            if (!_lang.isUrdu) FontPickerButton(selectedIndex: _headingFontIndex, onChanged: (i) => setState(() => _headingFontIndex = i)),
            const Spacer(),
            if (isLive) _buildListeningBadge(),
          ],
        ),
        const SizedBox(height: 4),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: isTarget ? Border.all(color: isLive ? AppColors.error : AppColors.accent, width: 2) : null,
          ),
          child: GlassCard(
            padding: EdgeInsets.zero,
            child: TextField(
              controller: _headingController,
              focusNode: _headingFocus,
              maxLines: 1,
              textDirection: dir,
              textAlign: _lang.isUrdu ? TextAlign.right : TextAlign.left,
              style: _headingTextStyle(),
              decoration: InputDecoration(
                hintText: _lang.headingHint,
                hintTextDirection: dir,
                hintStyle: _headingTextStyle().copyWith(color: AppColors.textHint.withValues(alpha: 0.5)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              ),
              textInputAction: TextInputAction.next,
              onTap: () => _selectField(_ActiveField.heading),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildParagraphSection() {
    final isTarget = _activeField == _ActiveField.paragraph;
    final isLive = _isListening && _lockedField == _ActiveField.paragraph;
    final dir = _lang.textDirection;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SectionLabel(text: _lang.caseDetailsLabel, icon: Icons.notes_rounded),
            const SizedBox(width: 8),
            if (!_lang.isUrdu) FontPickerButton(selectedIndex: _paragraphFontIndex, onChanged: (i) => setState(() => _paragraphFontIndex = i)),
            const Spacer(),
            if (isLive) _buildListeningBadge(),
          ],
        ),
        const SizedBox(height: 4),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: isTarget ? Border.all(color: isLive ? AppColors.error : AppColors.accent, width: 2) : null,
          ),
          child: GlassCard(
            padding: EdgeInsets.zero,
            child: TextField(
              controller: _paragraphController,
              focusNode: _paragraphFocus,
              maxLines: 6,
              textDirection: dir,
              textAlign: _lang.isUrdu ? TextAlign.right : TextAlign.left,
              style: _paragraphTextStyle(),
              decoration: InputDecoration(
                hintText: _lang.detailsHint,
                hintTextDirection: dir,
                hintStyle: _paragraphTextStyle().copyWith(color: AppColors.textHint.withValues(alpha: 0.5)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(20),
              ),
              onTap: () => _selectField(_ActiveField.paragraph),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListeningBadge() {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.error)),
          const SizedBox(width: 6),
          Text('LIVE', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.error, letterSpacing: 1)),
        ],
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
                    ? lang.urduStyle(fontSize: 12, color: AppColors.textSecondary)
                    : GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary, height: 1.4),
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
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: AppColors.shadowMedium, blurRadius: 40, offset: const Offset(0, 12))],
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
                    ? lang.urduStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)
                    : GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                lang.discardChangesBody,
                textAlign: TextAlign.center,
                textDirection: lang.textDirection,
                style: lang.isUrdu
                    ? lang.urduStyle(fontSize: 14, color: AppColors.textSecondary)
                    : GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textSecondary, height: 1.5),
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
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: AppColors.shadowMedium, blurRadius: 40, offset: const Offset(0, 12))],
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
                    ? lang.urduStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)
                    : GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                lang.saveChangesDialogBody,
                textAlign: TextAlign.center,
                textDirection: lang.textDirection,
                style: lang.isUrdu
                    ? lang.urduStyle(fontSize: 14, color: AppColors.textSecondary)
                    : GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textSecondary, height: 1.5),
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
        : widget.isPrimary ? Colors.white : AppColors.textSecondary;

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
              color: widget.isDestructive ? AppColors.error.withValues(alpha: 0.4) : Colors.grey.shade300,
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
