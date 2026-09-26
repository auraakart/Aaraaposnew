import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppStrings {
  AppStrings(this.locale);

  final Locale locale;

  static const supportedLocales = [
    Locale('en'),
    Locale('hi'),
    Locale('ta'),
  ];

  static const plannedLocaleCodes = {
    'te',
    'ml',
    'kn',
    'mr',
    'bn',
    'gu',
    'pa',
  };

  static const LocalizationsDelegate<AppStrings> delegate =
      _AppStringsDelegate();

  static AppStrings of(BuildContext context) {
    final strings = Localizations.of<AppStrings>(context, AppStrings);
    assert(strings != null, 'AppStrings not found in context');
    return strings!;
  }

  static bool isSupportedCode(String? code) =>
      supportedLocales.any((locale) => locale.languageCode == code);

  String _value(String key) {
    final language = locale.languageCode;
    return _translations[language]?[key] ??
        _translations['en']![key] ??
        key;
  }

  String get appTitle => _value('appTitle');
  String get home => _value('home');
  String get sell => _value('sell');
  String get stock => _value('stock');
  String get customers => _value('customers');
  String get more => _value('more');
  String get businessToday => _value('businessToday');
  String get searchOrScan => _value('searchOrScan');
  String get scanBarcode => _value('scanBarcode');
  String get addProduct => _value('addProduct');
  String get guestCustomer => _value('guestCustomer');
  String get hold => _value('hold');
  String get resume => _value('resume');
  String get applyOffer => _value('applyOffer');
  String get usePoints => _value('usePoints');
  String get pay => _value('pay');
  String get languageAccessibility => _value('languageAccessibility');
  String get chooseLanguage => _value('chooseLanguage');
  String get followsTextSize => _value('followsTextSize');
  String get translationPending => _value('translationPending');
  String get localStorageError => _value('localStorageError');
  String get english => _value('english');
  String get hindi => _value('hindi');
  String get tamil => _value('tamil');
  String get systemDefault => _value('systemDefault');
  String get accessibilityDetail => _value('accessibilityDetail');
  String get preparedLanguagesDetail => _value('preparedLanguagesDetail');
  String get addItemsToBill => _value('addItemsToBill');

  static const _translations = <String, Map<String, String>>{
    'en': {
      'appTitle': 'AaraaPOS',
      'home': 'Home',
      'sell': 'Sell',
      'stock': 'Stock',
      'customers': 'Customers',
      'more': 'More',
      'businessToday': 'Business Today',
      'searchOrScan': 'Search name or scan barcode',
      'scanBarcode': 'Scan barcode',
      'addProduct': 'Add product',
      'guestCustomer': 'Guest customer',
      'hold': 'Hold',
      'resume': 'Resume',
      'applyOffer': 'Apply offer',
      'usePoints': 'Use points',
      'pay': 'Pay',
      'languageAccessibility': 'Language & Accessibility',
      'chooseLanguage': 'Choose language',
      'followsTextSize':
          'AaraaPOS follows your device text-size setting and uses large touch targets.',
      'translationPending': 'Translation pending',
      'localStorageError':
          'AaraaPOS could not open local storage. Restart the app and try again.',
      'english': 'English',
      'hindi': 'Hindi',
      'tamil': 'Tamil',
      'systemDefault': 'System default',
      'accessibilityDetail':
          'Text scaling follows Android/iOS accessibility settings. Primary actions keep large touch targets and visible labels.',
      'preparedLanguagesDetail':
          'Prepared languages are not marked supported until translated and reviewed.',
      'addItemsToBill': 'Add items to bill',
    },
    'hi': {
      'appTitle': 'AaraaPOS',
      'home': 'होम',
      'sell': 'बिक्री',
      'stock': 'स्टॉक',
      'customers': 'ग्राहक',
      'more': 'और',
      'businessToday': 'आज का कारोबार',
      'searchOrScan': 'नाम खोजें या बारकोड स्कैन करें',
      'scanBarcode': 'बारकोड स्कैन करें',
      'addProduct': 'उत्पाद जोड़ें',
      'guestCustomer': 'बिना नाम ग्राहक',
      'hold': 'रोकें',
      'resume': 'फिर खोलें',
      'applyOffer': 'ऑफर लगाएँ',
      'usePoints': 'पॉइंट इस्तेमाल करें',
      'pay': 'भुगतान करें',
      'languageAccessibility': 'भाषा और पहुँच',
      'chooseLanguage': 'भाषा चुनें',
      'followsTextSize':
          'AaraaPOS आपके फ़ोन के टेक्स्ट आकार का उपयोग करता है और बड़े टच बटन देता है।',
      'translationPending': 'अनुवाद बाकी है',
      'localStorageError':
          'AaraaPOS स्थानीय डेटा नहीं खोल सका। ऐप दोबारा शुरू करके फिर कोशिश करें।',
      'english': 'अंग्रेज़ी',
      'hindi': 'हिन्दी',
      'tamil': 'तमिल',
      'systemDefault': 'सिस्टम की भाषा',
      'accessibilityDetail':
          'टेक्स्ट आकार Android/iOS की पहुँच सेटिंग का पालन करता है। मुख्य बटन बड़े और स्पष्ट रहते हैं।',
      'preparedLanguagesDetail':
          'तैयार भाषाओं को अनुवाद और समीक्षा पूरी होने तक समर्थित नहीं माना जाता।',
      'addItemsToBill': 'बिल में सामान जोड़ें',
    },
    'ta': {
      'appTitle': 'AaraaPOS',
      'home': 'முகப்பு',
      'sell': 'விற்பனை',
      'stock': 'இருப்பு',
      'customers': 'வாடிக்கையாளர்கள்',
      'more': 'மேலும்',
      'businessToday': 'இன்றைய வணிகம்',
      'searchOrScan': 'பெயரைத் தேடுங்கள் அல்லது பார்கோடை ஸ்கேன் செய்யுங்கள்',
      'scanBarcode': 'பார்கோடு ஸ்கேன்',
      'addProduct': 'பொருள் சேர்க்க',
      'guestCustomer': 'விருந்தினர் வாடிக்கையாளர்',
      'hold': 'நிறுத்தி வை',
      'resume': 'தொடரவும்',
      'applyOffer': 'சலுகையைப் பயன்படுத்து',
      'usePoints': 'புள்ளிகளைப் பயன்படுத்து',
      'pay': 'பணம் செலுத்து',
      'languageAccessibility': 'மொழி மற்றும் அணுகல்தன்மை',
      'chooseLanguage': 'மொழியைத் தேர்வு செய்க',
      'followsTextSize':
          'AaraaPOS உங்கள் சாதனத்தின் எழுத்து அளவைப் பின்பற்றி பெரிய தொடு பகுதிகளைப் பயன்படுத்துகிறது.',
      'translationPending': 'மொழிபெயர்ப்பு நிலுவையில் உள்ளது',
      'localStorageError':
          'AaraaPOS உள்ளூர் தரவைத் திறக்க முடியவில்லை. செயலியை மீண்டும் தொடங்கி முயற்சிக்கவும்.',
      'english': 'ஆங்கிலம்',
      'hindi': 'இந்தி',
      'tamil': 'தமிழ்',
      'systemDefault': 'சாதன இயல்புநிலை',
      'accessibilityDetail':
          'எழுத்து அளவு Android/iOS அணுகல் அமைப்பைப் பின்பற்றுகிறது. முக்கிய செயல்கள் பெரிய தொடு பகுதிகளும் தெளிவான பெயர்களும் கொண்டுள்ளன.',
      'preparedLanguagesDetail':
          'மொழிபெயர்ப்பு மற்றும் மதிப்பாய்வு முடியும் வரை தயாராக உள்ள மொழிகள் ஆதரிக்கப்படுவதாகக் குறிக்கப்படாது.',
      'addItemsToBill': 'பில்லில் பொருட்களைச் சேர்க்கவும்',
    },
  };
}

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppStrings.isSupportedCode(locale.languageCode);

  @override
  Future<AppStrings> load(Locale locale) =>
      SynchronousFuture(AppStrings(locale));

  @override
  bool shouldReload(_AppStringsDelegate old) => false;
}

class AppLocaleController extends ChangeNotifier {
  Locale? _locale;

  Locale? get locale => _locale;

  void useSystemLocale() {
    if (_locale == null) return;
    _locale = null;
    notifyListeners();
  }

  void setLocale(Locale locale) {
    if (!AppStrings.isSupportedCode(locale.languageCode)) {
      throw ArgumentError('Unsupported locale: ${locale.languageCode}');
    }
    if (_locale?.languageCode == locale.languageCode) return;
    _locale = Locale(locale.languageCode);
    notifyListeners();
  }

  void loadPreferredCode(String? code) {
    if (code == null || !AppStrings.isSupportedCode(code)) return;
    setLocale(Locale(code));
  }
}

class AppLocaleScope extends InheritedNotifier<AppLocaleController> {
  const AppLocaleScope({
    required AppLocaleController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static AppLocaleController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppLocaleScope>();
    assert(scope?.notifier != null, 'AppLocaleScope not found');
    return scope!.notifier!;
  }
}
