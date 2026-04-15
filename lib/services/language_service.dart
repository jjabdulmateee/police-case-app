import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

class LanguageService extends ChangeNotifier {
  LanguageService._internal();
  static final LanguageService instance = LanguageService._internal();
  factory LanguageService() => instance;

  static const _key = 'app_language';
  bool _isUrdu = false;
  bool _initialized = false;

  bool get isUrdu => _isUrdu;
  String get code => _isUrdu ? 'ur' : 'en';
  String get locale => _isUrdu ? 'ur_PK' : 'en_US';
  TextDirection get textDirection =>
      _isUrdu ? TextDirection.rtl : TextDirection.ltr;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    final prefs = await SharedPreferences.getInstance();
    _isUrdu = prefs.getString(_key) == 'ur';
    notifyListeners();
  }

  Future<void> toggle() async {
    _isUrdu = !_isUrdu;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _isUrdu ? 'ur' : 'en');
    notifyListeners();
  }

  // UI label helpers
  String get caseHeadingLabel => _isUrdu ? 'مقدمے کا عنوان' : 'Case Heading';
  String get caseDetailsLabel => _isUrdu ? 'مقدمے کی تفصیل' : 'Case Details';
  String get confirmLabel => _isUrdu ? 'مکمل کریں' : 'Confirm & Save';
  String get voiceInputLabel => _isUrdu ? 'آواز سے ان پٹ' : 'Voice Input';
  String get listeningText => _isUrdu ? 'سن رہا ہے... رکنے کے لیے ٹیپ کریں' : 'Listening... Tap to stop';
  String get tapMicText => _isUrdu ? 'ریکارڈنگ شروع کرنے کے لیے مائیک دبائیں' : 'Tap the mic to start recording';
  String get selectFieldText => _isUrdu ? 'پہلے نیچے فیلڈ منتخب کریں' : 'Select a field below, then tap the mic';
  String get initializingText => _isUrdu ? 'آواز کا انجن شروع ہو رہا ہے...' : 'Initializing speech engine...';
  String get headingHint => _isUrdu ? 'مقدمے کا عنوان درج کریں...' : 'Enter case heading...';
  String get detailsHint => _isUrdu ? 'مقدمے کی تفصیلات، مشاہدات، شواہد...' : 'Describe the case details, observations, evidence...';
  String get recordingText => _isUrdu ? 'ریکارڈنگ' : 'Recording';
  String get readyText => _isUrdu ? 'تیار' : 'Ready';
  String get unavailableText => _isUrdu ? 'دستیاب نہیں' : 'Unavailable';
  String targetText(String field) => _isUrdu ? 'ہدف: $field' : 'Target: $field';
  String get noTargetText => _isUrdu ? 'کوئی نہیں — پہلے فیلڈ منتخب کریں' : 'None — tap a field first';
  String get completeDialogTitle => _isUrdu ? 'کیا آپ مقدمہ مکمل کرنا چاہتے ہیں؟' : 'Complete This Case?';
  String get completeDialogBody => _isUrdu
      ? 'کیا آپ واقعی اس مقدمے کو مکمل کرنا چاہتے ہیں؟ یہ آپ کے آلے پر محفوظ ہو جائے گا۔'
      : 'Are you sure you want to complete this case? It will be saved to your device.';
  String get cancelText => _isUrdu ? 'منسوخ' : 'Cancel';
  String get completeText => _isUrdu ? 'مکمل' : 'Complete';
  String get caseSavedTitle => _isUrdu ? 'مقدمہ کامیابی سے محفوظ ہو گیا' : 'Case Saved Successfully';
  String get whatNextText => _isUrdu ? 'آگے کیا کرنا چاہیں گے؟' : 'What would you like to do next?';
  String get exportPdfText => _isUrdu ? 'PDF میں ایکسپورٹ' : 'Export as PDF';
  String get printText => _isUrdu ? 'پرنٹ' : 'Print';
  String get skipText => _isUrdu ? 'ابھی چھوڑیں' : 'Skip for now';
  String get editCaseTitle => _isUrdu ? 'مقدمہ ترمیم کریں' : 'Edit Case';
  String get saveChangesLabel => _isUrdu ? 'تبدیلیاں محفوظ کریں' : 'Save Changes';
  String get saveChangesDialogTitle => _isUrdu ? 'اس مقدمے میں تبدیلیاں محفوظ کریں؟' : 'Save changes to this case?';
  String get saveChangesDialogBody => _isUrdu
      ? 'آپ کی تبدیلیاں موجودہ مقدمے کو اپ ڈیٹ کر دیں گی۔'
      : 'Your changes will update the existing case record.';
  String get saveText => _isUrdu ? 'محفوظ کریں' : 'Save';
  String get caseUpdatedText => _isUrdu ? 'مقدمہ کامیابی سے اپ ڈیٹ ہو گیا' : 'Case updated successfully';
  String editedTimesText(int count) => _isUrdu ? 'ترمیم شدہ ×$count' : 'Edited ×$count';
  String get discardChangesTitle => _isUrdu ? 'تبدیلیاں رد کریں؟' : 'Discard changes?';
  String get discardChangesBody => _isUrdu
      ? 'آپ نے غیر محفوظ تبدیلیاں کی ہیں۔ کیا آپ واقعی واپس جانا چاہتے ہیں؟'
      : 'You have unsaved changes. Are you sure you want to go back?';
  String get keepEditingText => _isUrdu ? 'ترمیم جاری رکھیں' : 'Keep Editing';
  String get discardText => _isUrdu ? 'رد کریں' : 'Discard';
  String get micPermissionText => _isUrdu
      ? 'مائیکروفون تک رسائی ضروری ہے۔ ترتیبات کھولنے کے لیے یہاں ٹیپ کریں۔'
      : 'Microphone access is required. Tap here to open settings.';
  String get settingsLabel => _isUrdu ? 'ترتیبات' : 'Settings';
  String get languageLabel => _isUrdu ? 'زبان' : 'Language';
  String get dataLabel => _isUrdu ? 'ڈیٹا' : 'Data';
  String get aboutLabel => _isUrdu ? 'ایپ کے بارے میں' : 'About';
  String get clearAllCasesLabel => _isUrdu ? 'تمام مقدمات حذف کریں' : 'Clear All Cases';
  String get clearAllCasesBody => _isUrdu
      ? 'کیا آپ واقعی تمام محفوظ مقدمات مستقل طور پر حذف کرنا چاہتے ہیں؟ یہ عمل واپس نہیں ہو سکتا۔'
      : 'Are you sure you want to permanently delete all saved cases? This action cannot be undone.';
  String get deleteText => _isUrdu ? 'حذف کریں' : 'Delete';
  String get allCasesClearedText => _isUrdu ? 'تمام مقدمات حذف ہو گئے' : 'All cases deleted';
  String totalCasesText(int count) => _isUrdu ? 'کل مقدمات: $count' : '$count case${count == 1 ? '' : 's'} saved';

  TextStyle urduStyle({double fontSize = 16, FontWeight fontWeight = FontWeight.w400, Color? color}) {
    return GoogleFonts.notoNastaliqUrdu(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }
}
