import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../core/theme/app_colors.dart';
import '../models/scanned_field_data.dart';
import '../models/document_format_template.dart';
import '../services/document_format_service.dart';
import '../services/language_service.dart';
import '../widgets/confirm_button.dart';

enum ScannedFormatEditorMode { design, fillCase }

const _kHintPrefKey = 'scanned_format_tap_hint_dismissed_v1';

/// Full-screen editor: place fields (design) or fill values (fillCase) on a scanned form image.
class ScannedFormatEditorScreen extends StatefulWidget {
  final String formatId;
  final ScannedFormatEditorMode mode;
  final Map<String, String> initialScannedFieldValues;

  const ScannedFormatEditorScreen({
    super.key,
    required this.formatId,
    required this.mode,
    this.initialScannedFieldValues = const {},
  });

  @override
  State<ScannedFormatEditorScreen> createState() => _ScannedFormatEditorScreenState();
}

class _ScannedPlaced {
  _ScannedPlaced({
    required this.id,
    required this.x,
    required this.y,
    this.label,
  });
  String id;
  double x;
  double y;
  String? label;
  final TextEditingController text = TextEditingController();
  final FocusNode focus = FocusNode();

  void dispose() {
    text.dispose();
    focus.dispose();
  }
}

class _ScannedFormatEditorScreenState extends State<ScannedFormatEditorScreen> {
  final _svc = DocumentFormatService();
  final _lang = LanguageService();
  final _speech = SpeechToText();
  final _transformController = TransformationController();
  static const _minFieldW = 120.0;

  void _onLangChanged() => setState(() {});

  DocumentFormatTemplate? _template;
  File? _imageFile;
  double? _imgW;
  double? _imgH;
  final List<_ScannedPlaced> _placements = [];
  String? _selectedId;
  bool _showTapHint = true;
  bool _loading = true;
  String? _loadError;
  String? _recordingFieldId;
  bool _isListening = false;
  bool _wantListening = false;
  String _textBeforeListening = '';
  int _listenGeneration = 0;
  bool _speechInited = false;

  @override
  void initState() {
    super.initState();
    _lang.addListener(_onLangChanged);
    _lang.init();
    unawaited(_load());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_ensureSpeech());
    });
  }

  @override
  void dispose() {
    _lang.removeListener(_onLangChanged);
    for (final p in _placements) {
      p.dispose();
    }
    _wantListening = false;
    _speech.stop();
    _transformController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await _svc.init();
    final t = _svc.getById(widget.formatId);
    if (t == null || !t.isScan) {
      setState(() {
        _loading = false;
        _loadError = 'Format not found';
      });
      return;
    }
    final path = t.imageFile(_svc.documentsPath);
    if (path == null || !path.existsSync()) {
      setState(() {
        _loading = false;
        _loadError = 'Image missing';
      });
      return;
    }
    final bytes = await path.readAsBytes();
    final sz = await _imagePixelSize(bytes);
    final prefs = await SharedPreferences.getInstance();
    final hintGone = prefs.getBool(_kHintPrefKey) ?? false;
    if (!mounted) return;

    if (widget.mode == ScannedFormatEditorMode.fillCase) {
      for (final f in t.scannedFields) {
        final p = _ScannedPlaced(
          id: f.id,
          x: f.x,
          y: f.y,
          label: f.label,
        );
        p.text.text = widget.initialScannedFieldValues[f.id] ?? '';
        _placements.add(p);
      }
    } else {
      for (final f in t.scannedFields) {
        _placements.add(_ScannedPlaced(id: f.id, x: f.x, y: f.y, label: f.label));
      }
    }
    if (!mounted) return;
    setState(() {
      _template = t;
      _imageFile = path;
      _imgW = sz.$1;
      _imgH = sz.$2;
      _loadError = null;
      _loading = false;
      _showTapHint = widget.mode == ScannedFormatEditorMode.design &&
          !hintGone &&
          _placements.isEmpty;
    });
  }

  static Future<(double, double)> _imagePixelSize(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final w = frame.image.width.toDouble();
    final h = frame.image.height.toDouble();
    frame.image.dispose();
    return (w, h);
  }

  Future<void> _ensureSpeech() async {
    if (_speechInited) return;
    _speechInited = await _speech.initialize(
      onError: _onSpeechError,
      onStatus: _onSpeechStatus,
    );
    if (mounted) setState(() {});
  }

  void _onSpeechError(SpeechRecognitionError error) {
    if (!_wantListening || _recordingFieldId == null) {
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
    if (status == 'notListening' && _isListening) {
      setState(() => _isListening = false);
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (_recordingFieldId == null) return;
    final w = result.recognizedWords;
    if (w.isEmpty) return;
    _ScannedPlaced? p;
    for (final e in _placements) {
      if (e.id == _recordingFieldId) {
        p = e;
        break;
      }
    }
    if (p == null) return;
    final cleaned = w.trim();
    final sep = _textBeforeListening.isEmpty ? '' : ' ';
    p.text.text = _textBeforeListening + sep + cleaned;
    p.text.selection = TextSelection.fromPosition(TextPosition(offset: p.text.text.length));
    if (result.finalResult) {
      _textBeforeListening = p.text.text;
    }
    setState(() {});
  }

  void _scheduleRestart({int delayMs = 150}) {
    final g = _listenGeneration;
    unawaited(Future<void>.delayed(Duration(milliseconds: delayMs), () {
      if (!mounted) return;
      if (!_wantListening || _recordingFieldId == null) return;
      if (g != _listenGeneration) return;
      for (final p in _placements) {
        if (p.id == _recordingFieldId) {
          _textBeforeListening = p.text.text;
          _startListenSession(generation: g);
          return;
        }
      }
    }));
  }

  void _startListenSession({required int generation}) {
    if (!_speechInited) return;
    if (!_wantListening) return;
    if (generation != _listenGeneration) return;
    if (_recordingFieldId == null) return;
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

  void _stopListening() {
    _wantListening = false;
    _listenGeneration++;
    _speech.stop();
    if (mounted) {
      setState(() {
        _isListening = false;
        _recordingFieldId = null;
      });
    }
  }

  void _toggleMicFor(String fieldId) {
    if (_recordingFieldId == fieldId && _wantListening) {
      _stopListening();
      return;
    }
    if (!_speechInited) {
      unawaited(_ensureSpeech().then((_) {
        if (mounted) _startMicFor(fieldId);
      }));
      return;
    }
    _startMicFor(fieldId);
  }

  void _startMicFor(String fieldId) {
    unawaited(_ensureSpeech().then((_) {
      if (!mounted) return;
      _ScannedPlaced? p;
      for (final e in _placements) {
        if (e.id == fieldId) {
          p = e;
          break;
        }
      }
      if (p == null) return;
      final place = p;
      if (!_speechInited) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _lang.isUrdu ? 'آواز نہیں ملی' : 'Voice input unavailable on this device.',
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      setState(() {
        _wantListening = true;
        _recordingFieldId = fieldId;
        _textBeforeListening = place.text.text;
        _isListening = false;
        _selectedId = fieldId;
      });
      _listenGeneration++;
      _startListenSession(generation: _listenGeneration);
    }));
  }

  Future<void> _dismissHintPermanently() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHintPrefKey, true);
  }

  void _onImageTapInDesign(Offset local, double w, double h) {
    if (widget.mode != ScannedFormatEditorMode.design) return;
    var nx = (local.dx / w).clamp(0.0, 1.0);
    var ny = (local.dy / h).clamp(0.0, 1.0);
    final id = 'sf_${DateTime.now().microsecondsSinceEpoch}';
    final p = _ScannedPlaced(id: id, x: nx, y: ny);
    setState(() {
      _placements.add(p);
      _selectedId = id;
    });
    if (_showTapHint) {
      setState(() => _showTapHint = false);
      unawaited(_dismissHintPermanently());
    }
  }

  void _onPanField(int index, DragUpdateDetails d, double w, double h) {
    if (widget.mode == ScannedFormatEditorMode.fillCase) return;
    setState(() {
      final p = _placements[index];
      p.x = (p.x * w + d.delta.dx) / w;
      p.y = (p.y * h + d.delta.dy) / h;
      p.x = p.x.clamp(0.0, 0.99);
      p.y = p.y.clamp(0.0, 0.99);
    });
  }

  void _removeFieldAt(int i) {
    if (widget.mode == ScannedFormatEditorMode.fillCase) return;
    setState(() {
      _placements[i].dispose();
      _placements.removeAt(i);
      _selectedId = null;
    });
  }

  Map<String, String> _exportValues() {
    return {for (final p in _placements) p.id: p.text.text};
  }

  Future<void> _onDoneDesign() async {
    if (_template == null) return;
    final list = <ScannedFieldData>[
      for (final p in _placements)
        ScannedFieldData(
          id: p.id,
          label: p.label,
          x: p.x,
          y: p.y,
        ),
    ];
    await _svc.setScannedFieldDefinitions(_template!.id, list);
    if (mounted) Navigator.of(context).pop();
  }

  void _onContinueFill() {
    Navigator.of(context).pop<Map<String, String>>(_exportValues());
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Theme(
        data: Theme.of(context).copyWith(scaffoldBackgroundColor: AppColors.primary),
        child: const Scaffold(
          body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
        ),
      );
    }
    if (_loadError != null) {
      return Theme(
        data: Theme.of(context).copyWith(scaffoldBackgroundColor: AppColors.primary),
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: AppColors.primaryLight,
            leading: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, color: AppColors.textOnDark),
            ),
          ),
          body: Center(
            child: Text(
              _loadError!,
              style: const TextStyle(color: AppColors.textOnDark),
            ),
          ),
        ),
      );
    }
    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: AppColors.primary,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primaryLight,
          foregroundColor: AppColors.textOnDark,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.mode == ScannedFormatEditorMode.design
                ? (_lang.isUrdu ? 'فارمیٹ منصوبہ' : 'Layout form fields')
                : _lang.scannedEditorFillTitle,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              color: AppColors.textOnDark,
            ),
          ),
          leading: IconButton(
            onPressed: () {
              if (widget.mode == ScannedFormatEditorMode.fillCase) {
                Navigator.of(context).pop<Map<String, String>?>(null);
              } else {
                Navigator.of(context).pop();
              }
            },
            icon: const Icon(Icons.close_rounded, color: AppColors.textOnDark),
          ),
          actions: [
            if (widget.mode == ScannedFormatEditorMode.design)
              TextButton(
                onPressed: _onDoneDesign,
                child: Text(
                  _lang.scannedEditorSaveLayout,
                  style: GoogleFonts.inter(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        body: Column(
          children: [
            if (_showTapHint && widget.mode == ScannedFormatEditorMode.design)
              AnimatedSize(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                child: _showTapHint
                    ? Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        color: AppColors.accent.withValues(alpha: 0.12),
                        child: Text(
                          _lang.scannedEditorTapHint,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.textOnDark.withValues(alpha: 0.9),
                            height: 1.35,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  if (_imgW == null || _imgH == null || _imageFile == null) {
                    return const SizedBox();
                  }
                  final screenW = MediaQuery.sizeOf(context).width;
                  final tileW = screenW;
                  final tileH = tileW * _imgH! / _imgW!;
                  return InteractiveViewer(
                    transformationController: _transformController,
                    minScale: 0.3,
                    maxScale: 5.0,
                    boundaryMargin: const EdgeInsets.all(80),
                    child: SizedBox(
                      width: tileW,
                      height: tileH,
                      child: Stack(
                        clipBehavior: Clip.hardEdge,
                        children: [
                          Positioned.fill(
                            child: widget.mode == ScannedFormatEditorMode.design
                                ? GestureDetector(
                                    onTapUp: (d) {
                                      _onImageTapInDesign(
                                        d.localPosition,
                                        tileW,
                                        tileH,
                                      );
                                    },
                                    child: Image.file(
                                      _imageFile!,
                                      width: tileW,
                                      height: tileH,
                                      fit: BoxFit.fill,
                                    ),
                                  )
                                : Image.file(
                                    _imageFile!,
                                    width: tileW,
                                    height: tileH,
                                    fit: BoxFit.fill,
                                  ),
                          ),
                          ...List.generate(
                            _placements.length,
                            (i) => _buildPlaced(
                              i,
                              tileW,
                              tileH,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            if (widget.mode == ScannedFormatEditorMode.fillCase) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: SafeArea(
                  top: false,
                  child: ConfirmButton(
                    label: _lang.scannedEditorContinue,
                    onPressed: _onContinueFill,
                  ),
                ),
              ),
            ] else
              const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaced(int i, double w, double h) {
    final p = _placements[i];
    final sel = _selectedId == p.id;
    return Positioned(
      key: ValueKey(p.id),
      left: p.x * w,
      top: p.y * h,
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: () => setState(() => _selectedId = p.id),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (sel)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.mode == ScannedFormatEditorMode.design)
                        _RoundToolButton(
                          icon: Icons.drag_indicator_rounded,
                          color: AppColors.textSecondary,
                          onPanUpdate: (d) => _onPanField(i, d, w, h),
                        )
                      else
                        const SizedBox(width: 4),
                      const SizedBox(width: 4),
                      _micButton(p),
                      const SizedBox(width: 4),
                      if (widget.mode == ScannedFormatEditorMode.design)
                        _RoundToolButton(
                          icon: Icons.close_rounded,
                          color: AppColors.error,
                          onTap: () => _removeFieldAt(i),
                        ),
                    ],
                  ),
                if (sel) const SizedBox(height: 4),
                _fieldBox(p, sel),
              ],
            ),
          ),
        ),
    );
  }

  Widget _micButton(_ScannedPlaced p) {
    final active = _recordingFieldId == p.id && _wantListening;
    return Material(
      color: active ? AppColors.error : AppColors.accent,
      borderRadius: BorderRadius.circular(20),
      elevation: 2,
      child: InkWell(
        onTap: () {
          if (!_speechInited) {
            unawaited(_ensureSpeech().then((_) {
              if (mounted) setState(() {});
              if (_speechInited) _toggleMicFor(p.id);
            }));
          } else {
            _toggleMicFor(p.id);
          }
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(
            Icons.mic_rounded,
            size: 18,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _fieldBox(_ScannedPlaced p, bool sel) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: _minFieldW,
        maxWidth: 280,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(8),
          border: sel ? Border.all(color: AppColors.accent, width: 1.5) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: p.text,
          focusNode: p.focus,
          maxLines: 4,
          minLines: 1,
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary, height: 1.3),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.zero,
            border: InputBorder.none,
            hintText: '',
          ),
        ),
      ),
    );
  }
}

class _RoundToolButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final void Function(DragUpdateDetails d)? onPanUpdate;

  const _RoundToolButton({required this.icon, required this.color, this.onTap, this.onPanUpdate});

  @override
  Widget build(BuildContext context) {
    if (onPanUpdate != null) {
      return GestureDetector(
        onPanUpdate: onPanUpdate,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 4,
              ),
            ],
          ),
          child: Icon(icon, size: 20, color: color),
        ),
      );
    }
    return Material(
      color: AppColors.primaryLight,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }
}
