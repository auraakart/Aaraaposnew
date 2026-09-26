import 'package:flutter/material.dart';

import '../sell/local_pos_database.dart';
import 'app_strings.dart';

class LanguageAccessibilityScreen extends StatelessWidget {
  const LanguageAccessibilityScreen({
    required this.database,
    super.key,
  });

  final LocalPosDatabase database;

  Future<void> _selectLocale(
    BuildContext context,
    String code,
  ) async {
    final controller = AppLocaleScope.of(context);
    if (code == 'system') {
      controller.useSystemLocale();
      await database.updatePreferredLocaleCode(null);
      return;
    }

    final locale = Locale(code);
    controller.setLocale(locale);
    await database.updatePreferredLocaleCode(code);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final controller = AppLocaleScope.of(context);
    final selected = controller.locale?.languageCode ?? 'system';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.chooseLanguage,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                _LanguageTile(
                  value: 'system',
                  selected: selected,
                  title: strings.systemDefault,
                  onChanged: (value) => _selectLocale(context, value),
                ),
                _LanguageTile(
                  value: 'en',
                  selected: selected,
                  title: strings.english,
                  onChanged: (value) => _selectLocale(context, value),
                ),
                _LanguageTile(
                  value: 'hi',
                  selected: selected,
                  title: strings.hindi,
                  onChanged: (value) => _selectLocale(context, value),
                ),
                _LanguageTile(
                  value: 'ta',
                  selected: selected,
                  title: strings.tamil,
                  onChanged: (value) => _selectLocale(context, value),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.text_fields_outlined),
            title: Text(strings.followsTextSize),
            subtitle: Text(strings.accessibilityDetail),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ExpansionTile(
            leading: const Icon(Icons.translate_outlined),
            title: Text(strings.translationPending),
            subtitle: Text(strings.preparedLanguagesDetail),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            children: const [
              _PendingLanguage('తెలుగు', 'Telugu'),
              _PendingLanguage('മലയാളം', 'Malayalam'),
              _PendingLanguage('ಕನ್ನಡ', 'Kannada'),
              _PendingLanguage('मराठी', 'Marathi'),
              _PendingLanguage('বাংলা', 'Bengali'),
              _PendingLanguage('ગુજરાતી', 'Gujarati'),
              _PendingLanguage('ਪੰਜਾਬੀ', 'Punjabi'),
            ],
          ),
        ),
      ],
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.value,
    required this.selected,
    required this.title,
    required this.onChanged,
  });

  final String value;
  final String selected;
  final String title;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return RadioListTile<String>(
      value: value,
      groupValue: selected,
      title: Text(title),
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
    );
  }
}

class _PendingLanguage extends StatelessWidget {
  const _PendingLanguage(this.nativeName, this.englishName);

  final String nativeName;
  final String englishName;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      enabled: false,
      leading: const Icon(Icons.schedule_outlined),
      title: Text(nativeName),
      subtitle: Text(englishName),
    );
  }
}
