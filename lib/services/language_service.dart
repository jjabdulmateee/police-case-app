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
  String get caseReferenceLabel => _isUrdu ? 'مقدمہ نمبر' : 'Case Reference No.';
  String get caseHeadingLabel => _isUrdu ? 'مقدمے کا عنوان' : 'Case Heading';
  String get caseDetailsLabel => _isUrdu ? 'مقدمے کی تفصیل' : 'Case Details';
  String get confirmLabel => _isUrdu ? 'مکمل کریں' : 'Confirm & Save';
  String get voiceInputLabel => _isUrdu ? 'آواز سے ان پٹ' : 'Voice Input';
  String get listeningText => _isUrdu ? 'سن رہا ہے... رکنے کے لیے ٹیپ کریں' : 'Listening... Tap to stop';
  String get tapMicText => _isUrdu ? 'ریکارڈنگ شروع کرنے کے لیے مائیک دبائیں' : 'Tap the mic to start recording';
  String get selectFieldText => _isUrdu ? 'پہلے نیچے فیلڈ منتخب کریں' : 'Select a field below, then tap the mic';
  String get initializingText => _isUrdu ? 'آواز کا انجن شروع ہو رہا ہے...' : 'Initializing speech engine...';
  String get caseReferenceHint => _isUrdu ? 'اختیاری — خالی چھوڑیں برائے خودکار نمبر' : 'Optional — leave blank for auto KPK/2026/001';
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
  String get appearanceLabel => _isUrdu ? 'روپ' : 'Appearance';
  String get documentFormatsSectionLabel => _isUrdu ? 'PDF کے فارمیٹ' : 'PDF document formats';
  String get documentFormatsTileTitle => _isUrdu ? 'دستاویز کا لو آؤٹ' : 'Layout & paper scan';
  String get documentFormatsTileSubtitle =>
      _isUrdu ? 'کاغذ کی تصویر یا اندرونی عنوان ـ برآمد پر لاگو' : 'Scan a letterhead or build headers in the app for exports';
  String get selectFormatTitle => _isUrdu ? 'فارمیٹ منتخب کریں' : 'Select Format';
  String get noFormatOption => _isUrdu ? 'کوئی فارمیٹ نہیں' : 'No Format';
  String get recentlyUsedSection => _isUrdu ? 'حالیہ استعمال' : 'Recently used';
  String get allFormatsSection => _isUrdu ? 'تمام فارمیٹ' : 'All Formats';
  String get formatBadgePrebuilt => _isUrdu ? 'بنیادی' : 'Pre-built';
  String get formatBadgeCustom => _isUrdu ? 'کسٹم' : 'Custom';
  String get formatBadgeScanned => _isUrdu ? 'اسکین' : 'Scanned';
  String get newCaseStartTitle => _isUrdu ? 'نیا مقدمہ' : 'New case';
  String get newCaseStartSubtitle =>
      _isUrdu ? 'فارمیٹ منتخب کریں — پھر لکھیں' : 'Choose a document format, then add details';
  String get newCaseButton => _isUrdu ? 'فارمیٹ منتخب کریں' : 'Select format to start';
  String get changeFormatAction => _isUrdu ? 'فارمیٹ تبدیل کریں' : 'Change format';
  String get currentFormatBadge => _isUrdu ? 'فارمیٹ' : 'Format';
  String get quickAddScanTitle => _isUrdu ? 'کاغذ اسکین' : 'Scan paper';
  String get quickAddBuildTitle => _isUrdu ? 'دستی ترتیب' : 'Build manually';
  String get quickAddAddFormat => _isUrdu ? 'نیا فارمیٹ' : 'Add format';
  String get quickAddChoosePath => _isUrdu ? 'طریقہ' : 'How would you like to add it?';
  String get scanPaperOption => _isUrdu ? 'کاغذ اسکین' : 'Scan paper';
  String get scanPaperSubtitle => _isUrdu ? 'فوٹو لیں، پھر نام' : 'Take a photo, then name the format';
  String get buildManuallyOption => _isUrdu ? 'دستی سے بنائیں' : 'Build manually';
  String get buildManuallySubtitle => _isUrdu ? 'عنوان اور رنگ' : 'Header line and accent in the app';
  String get formatNameDialogTitle => _isUrdu ? 'فارمیٹ کا نام' : 'Name this format';
  String get formatNameDialogHint => _isUrdu ? 'مثال: یونٹ ہیڈر' : 'e.g. Unit letterhead';
  String get newCaseNavButton => _isUrdu ? 'نیا مقدمہ' : 'New case';
  String get draftRestoredMessage => _isUrdu ? 'ڈرافٹ بحال' : 'Draft restored';
  String get clearActiveFormatA11y => _isUrdu ? 'فارمیٹ ہٹائیں' : 'Clear format';
  String get sessionBadgeNoFormat => _isUrdu ? 'سادہ دستاویز' : 'No format';
  String get darkModeLabel => _isUrdu ? 'تاریک موڈ' : 'Dark mode';
  String get lightModeLabel => _isUrdu ? 'روشن موڈ' : 'Light mode';
  String get dataLabel => _isUrdu ? 'ڈیٹا' : 'Data';
  String get aboutLabel => _isUrdu ? 'ایپ کے بارے میں' : 'About';
  String get clearAllCasesLabel => _isUrdu ? 'تمام مقدمات حذف کریں' : 'Clear All Cases';
  String get clearAllCasesBody => _isUrdu
      ? 'کیا آپ واقعی تمام محفوظ مقدمات مستقل طور پر حذف کرنا چاہتے ہیں؟ یہ عمل واپس نہیں ہو سکتا۔'
      : 'Are you sure you want to permanently delete all saved cases? This action cannot be undone.';
  String get deleteText => _isUrdu ? 'حذف کریں' : 'Delete';
  String get allCasesClearedText => _isUrdu ? 'تمام مقدمات حذف ہو گئے' : 'All cases deleted';
  String totalCasesText(int count) => _isUrdu ? 'کل مقدمات: $count' : '$count case${count == 1 ? '' : 's'} saved';

  String get deleteFormatDialogTitle => _isUrdu ? 'فارمیٹ حذف کریں؟' : 'Delete Format?';
  String get deleteFormatDialogBody => _isUrdu
      ? 'کیا آپ واقعی اس فارمیٹ کو حذف کرنا چاہتے ہیں؟ یہ واپس نہیں ہو سکتا۔'
      : 'Are you sure you want to delete this format? This cannot be undone.';
  String get activeFormatDeletedSnackbar =>
      _isUrdu ? 'فعال فارمیٹ حذف کر دیا گیا۔ اب کوئی فارمیٹ منتخب نہیں۔' : 'Active format was deleted. No format is now selected.';

  String get scannedEditorTapHint =>
      _isUrdu ? 'فارم پر جہاں فیلڈ چاہیں وہاں ٹیپ کریں' : 'Tap anywhere on the form to add a text field';
  String get scannedEditorFillTitle => _isUrdu ? 'فارم بھریں' : 'Fill the form';
  String get scannedEditorContinue => _isUrdu ? 'جاری رکھیں' : 'Continue';
  String get scannedEditorSaveLayout => _isUrdu ? 'محفوظ' : 'Save';

  String get printerSectionTitle => _isUrdu ? 'پرنٹر' : 'Printer';
  String get printerTileSubtitle => _isUrdu ? 'بلوٹوتھ، USB، Wi-Fi' : 'Bluetooth, USB & Wi-Fi';
  String get printerStatusNone => _isUrdu ? 'کوئی پرنٹر جڑا نہیں' : 'No printer connected';
  String get printerStatusLast => _isUrdu ? 'آخری جڑا ہوا:' : 'Last connected:';
  String get printerSettingsTitle => _isUrdu ? 'پرنٹر کی ترتیبات' : 'Printer settings';
  String get printerWifiTitle => _isUrdu ? 'Wi-Fi / نیٹ ورک' : 'WiFi / network';
  String get printerWifiUseSystem => _isUrdu ? 'سسٹم پرنٹ استعمال کریں' : 'Use system print dialog';
  String get printerWifiHelp =>
      _isUrdu ? 'کسی بھی Wi-Fi پرنٹر کے ساتھ کام کرتا ہے — فون کے بلٹ اِن پرنٹ سسٹم استعمال ہوتا ہے۔'
      : 'Works with any WiFi printer. Uses your phone’s built-in print system.';
  String get printerBluetoothTitle => _isUrdu ? 'بلیوٹوتھ' : 'Bluetooth';
  String get printerScanCta => _isUrdu ? 'پرنٹر تلاش کریں' : 'Scan for printers';
  String get printerConnectCta => _isUrdu ? 'جڑیں' : 'Connect';
  String get printerDisconnectCta => _isUrdu ? 'منقطع' : 'Disconnect';
  String get printerUsbTitle => _isUrdu ? 'USB' : 'USB';
  String get printerUsbCta => _isUrdu ? 'USB تار سے جڑیں' : 'Connect via USB cable';
  String get printerUsbHelp =>
      _isUrdu ? 'APK کو USB-C OTG تار کے ذریعے پرنٹر سے جوڑیں۔' : 'Connect your printer to your phone using a USB-C OTG cable.';
  String get printerUsbDetected => _isUrdu ? 'پرنٹر ملا' : 'Printer detected';
  String get printerUsbNone => _isUrdu ? 'کوئی USB پرنٹر نہیں' : 'No USB printer detected';
  String get printerTestPrint => _isUrdu ? 'ٹیسٹ پرنٹ' : 'Test print';
  String get printDirectFailedFallback =>
      _isUrdu ? 'براہ راست پرنٹ ناکام۔ سسٹم کا پرنٹ ڈائیلاگ کھول رہے ہیں۔' : 'Direct printing failed. Opening system print dialog.';

  String get attachmentsSectionLabel => _isUrdu ? 'منسلکات' : 'Attachments';
  String get storageSectionLabel => _isUrdu ? 'سٹوریج' : 'Storage';
  String get storageMediaCaseFilesLabel => _isUrdu ? 'مقدمے کی فائلیں' : 'Case attachment files on device';
  String get clearAllMediaLabel => _isUrdu ? 'سارا میڈیا مٹائیں' : 'Clear all media';
  String get clearAllMediaDialogTitle => _isUrdu ? 'سارا میڈیا حذف؟' : 'Delete all case media?';
  String get clearAllMediaDialogBody =>
      _isUrdu
          ? 'منسلک فائلیں حذف ہو جائیں گی — مقدمات کے متن پر اثر نہیں۔'
          : 'This removes all attachment files. Your case text and case list stay intact.';
  String get mediaComingSoon => _isUrdu ? 'جلد' : 'Coming soon';

  TextStyle urduStyle({double fontSize = 16, FontWeight fontWeight = FontWeight.w400, Color? color}) {
    return GoogleFonts.notoNastaliqUrdu(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }
}
