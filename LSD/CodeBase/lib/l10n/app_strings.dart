import 'package:flutter/material.dart';

/// Supported languages in the app.
enum AppLanguage { english, urdu }

/// Provides all user-facing strings for a given language.
class AppStrings {
  const AppStrings(this.language);

  final AppLanguage language;

  bool get isEnglish => language == AppLanguage.english;
  bool get isUrdu => language == AppLanguage.urdu;

  static AppStrings of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppStringsScope>();
    assert(scope != null, 'AppStringsScope not found in widget tree');
    return scope!.strings;
  }

  // General
  String get appTitle =>
      isEnglish ? 'Cow Health Scanner' : 'گائے کی صحت اسکینر';

  String get tagline => isEnglish
      ? 'AI-powered lumpy skin disease detection'
      : 'لَمپی سکن بیماری کی AI پر مبنی تشخیص';

  // Home actions
  String get cameraButton =>
      isEnglish ? 'Camera' : 'کیمرہ';

  String get galleryButton =>
      isEnglish ? 'Gallery' : 'گیلری';

  String get noImageTitle =>
      isEnglish ? 'No image selected' : 'کوئی تصویر منتخب نہیں ہوئی';

  String get noImageSubtitle => isEnglish
      ? 'Use Camera or Gallery to start a scan.'
      : 'اسکین شروع کرنے کے لیے کیمرہ یا گیلری استعمال کریں۔';

  // Result card
  String get awaitingTitle =>
      isEnglish ? 'Awaiting scan' : 'اسکین کا انتظار ہے';

  String get awaitingSubtitle => isEnglish
      ? 'Capture or pick an image to analyze cow health.'
      : 'گائے کی صحت جانچنے کے لیے تصویر لیں یا منتخب کریں۔';

  String get errorTitle => isEnglish ? 'Error' : 'خرابی';

  String get noCowDetectedTitle =>
      isEnglish ? 'No cow detected' : 'گائے شناخت نہیں ہوئی';

  String get noCowDetectedSubtitle => isEnglish
      ? 'Please try again with a clearer view of the cow.'
      : 'براہِ کرم گائے کی واضح تصویر کے ساتھ دوبارہ کوشش کریں۔';

  String predictionTitle(String label) => isEnglish
      ? 'Prediction: $label'
      : 'نتیجہ: $label';

  String predictionSubtitle({
    required String statusText,
    required double confidence,
  }) {
    final String percent = (confidence * 100).toStringAsFixed(1);
    if (isEnglish) {
      return 'Status: $statusText\nConfidence: $percent%';
    }
    return 'حالت: $statusText\nاعتماد: %$percent';
  }

  // Download button
  String get downloadButton =>
      isEnglish ? 'Download image to gallery' : 'تصویر کو گیلری میں محفوظ کریں';

  String get downloadSuccess => isEnglish
      ? 'Image saved to gallery.'
      : 'تصویر گیلری میں محفوظ ہو گئی ہے۔';

  String get downloadFailure => isEnglish
      ? 'Could not save image to gallery.'
      : 'تصویر گیلری میں محفوظ نہیں ہو سکی۔';

  String get downloadNoImage => isEnglish
      ? 'No image to save yet.'
      : 'محفوظ کرنے کے لیے ابھی کوئی تصویر موجود نہیں ہے۔';

  // Guidelines
  String get guidelinesTitle => isEnglish
      ? 'How to take a good photo'
      : 'بہترین نتیجے کے لیے تصویر لینے کے طریقے';

  String get guidelinesBody => isEnglish
      ? '''
• The cow should be clearly visible and the largest object in the image, with no obstacle between the camera and the cow.
• Only upload images of cattle (cow, bull, or the same species). If you upload other animals or scenery, the prediction will not be valid.
• Take the photo in good lighting. In dark or dull environments, the prediction may not be fully accurate.
• It is recommended to have only one cow or cattle in the image. Multiple animals can confuse the model and lead to an incorrect result.
• Make sure the input image is really of cattle/cow; the app does not check the species and will simply run the prediction on whatever image you upload.
'''
      : '''
• تصویر میں گائے واضح طور پر اور سب سے نمایاں چیز ہونی چاہیے، کیمرہ اور گائے کے درمیان کوئی رکاوٹ نہ ہو۔
• صرف گائے، بیل یا اسی نسل کے مویشیوں کی تصویر اپ لوڈ کریں؛ کسی اور جانور یا منظر کی تصویر پر نتیجہ قابلِ اعتماد نہیں ہوگا۔
• اچھی روشنی میں تصویر لیں؛ مدھم یا اندھیرے ماحول میں پیش گوئی کی درستگی کم ہو سکتی ہے۔
• بہترین درستگی کے لیے تصویر میں صرف ایک ہی گائے یا مویشی رکھیں؛ اگر کئی مویشی ہوں تو ماڈل غلط جانور پر توجہ دے کر غلط نتیجہ دے سکتا ہے۔
• یہ یقینی بنائیں کہ آپ جو تصویر اپ لوڈ کر رہے ہیں وہ واقعی گائے/مویشی کی ہے؛ ایپ خود سے یہ نہیں جانچتی کہ تصویر میں گائے ہے یا کچھ اور، یہ بس دی گئی تصویر پر پیش گوئی چلاتی ہے۔
''';

  // Language selection
  String get languageSelectionTitle => isEnglish
      ? 'Choose your language'
      : 'اپنی زبان منتخب کریں';

  String get languageSelectionSubtitle => isEnglish
      ? 'You can use the app in English or Urdu.'
      : 'آپ ایپ کو اردو یا انگریزی میں استعمال کر سکتے ہیں۔';

  String get englishLabel => 'English';

  String get urduLabel => 'اردو';
}

/// Inherited widget that exposes [AppStrings] to the tree.
class AppStringsScope extends InheritedWidget {
  const AppStringsScope({
    super.key,
    required this.strings,
    required super.child,
  });

  final AppStrings strings;

  static AppStringsScope of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppStringsScope>();
    assert(scope != null, 'AppStringsScope not found in widget tree');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppStringsScope oldWidget) =>
      oldWidget.strings.language != strings.language;
}

