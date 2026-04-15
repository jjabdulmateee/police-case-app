import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import '../core/theme/app_colors.dart';
import '../models/case_record.dart';
import '../services/language_service.dart';
import '../main.dart';
import '../widgets/pulse_mic_button.dart';
import '../widgets/confirm_button.dart';
import '../widgets/section_label.dart';
import '../widgets/glass_card.dart';
import '../widgets/font_picker_button.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/export_bottom_sheet.dart';
import '../widgets/language_toggle.dart';

enum _ActiveField { heading, paragraph }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final _headingController = TextEditingController();
  final _paragraphController = TextEditingController();
  final _headingFocus = FocusNode();
  final _paragraphFocus = FocusNode();

  final SpeechToText _speech = SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;
  bool _wantListening = false;

  _ActiveField? _activeField;
  String _textBeforeListening = '';
  _ActiveField? _lockedField;

  int _headingFontIndex = 0;
  int _paragraphFontIndex = 0;

  final LanguageService _lang = LanguageService();

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
    _fadeController.dispose();
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
        // Commit current text, then restart
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
    if (!_speechAvailable) {
      _showSnack('Speech recognition is not available on this device.', AppColors.error);
      return;
    }
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

  // ── Confirm → Save ───────────────────────────────────────
  Future<void> _onConfirm() async {
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

    final record = CaseRecord(
      heading: heading,
      details: paragraph,
      headingFont: availableFonts[_headingFontIndex].displayName,
      detailsFont: availableFonts[_paragraphFontIndex].displayName,
      savedAt: DateTime.now(),
      caseLanguage: _lang.code,
    );

    final box = Hive.box<CaseRecord>('cases');
    await box.add(record);
    final caseNumber = box.length;

    _headingController.clear();
    _paragraphController.clear();
    setState(() {
      _isListening = false;
      _wantListening = false;
      _lockedField = null;
      _activeField = null;
    });

    if (!mounted) return;

    await showExportSheet(context, record: record, caseNumber: caseNumber, lang: _lang);
    if (!mounted) return;
    AppShell.switchToTab(context, 1);
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

  // ── Build ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildHeader()),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildVoiceSection(),
                      const SizedBox(height: 28),
                      _buildHeadingSection(),
                      const SizedBox(height: 28),
                      _buildParagraphSection(),
                      const SizedBox(height: 36),
                      _buildConfirmSection(),
                      const SizedBox(height: 40),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                  children: [
                    Text('Case Documentation', style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 2),
                    Text('Record and document case details', style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
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

  Widget _buildLanguageToggle() {
    return LanguageToggle(lang: _lang);
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
            _buildMicPermissionBanner(),
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
                    ? _lang.urduStyle(fontSize: 12, color: AppColors.textSecondary)
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

  Widget _buildConfirmSection() {
    return ConfirmButton(onPressed: _onConfirm, enabled: true, label: _lang.confirmLabel);
  }
}
