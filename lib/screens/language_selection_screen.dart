import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';

class LanguageSelectionScreen extends StatelessWidget {
  const LanguageSelectionScreen({
    super.key,
    required this.onSelected,
  });

  final ValueChanged<AppLanguage> onSelected;

  @override
  Widget build(BuildContext context) {
    // Use English strings for the initial prompt so both users can understand.
    const englishStrings = AppStrings(AppLanguage.english);

    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.translate_rounded,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 24),
                // Text(
                //   englishStrings.languageSelectionTitle,
                //   textAlign: TextAlign.center,
                //   style: theme.textTheme.headlineSmall?.copyWith(
                //     fontWeight: FontWeight.w700,
                //   ),
                // ),
                // const SizedBox(height: 12),
                // Text(
                //   englishStrings.languageSelectionSubtitle,
                //   textAlign: TextAlign.center,
                //   style: theme.textTheme.bodyMedium?.copyWith(
                //     color: theme.colorScheme.onSurface
                //         .withAlpha((0.7 * 255).round()),
                //   ),
                // ),
                Column(
  children: [
    Text(
      "Choose Your Language",
      textAlign: TextAlign.center,
      style: theme.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    ),
    const SizedBox(height: 6),
    Text(
      "اپنی زبان منتخب کریں",
      textAlign: TextAlign.center,
      style: theme.textTheme.titleMedium,
    ),
  ],
),
const SizedBox(height: 12),
Column(
  children: [
    Text(
      "Select your preferred language to continue",
      textAlign: TextAlign.center,
      style: theme.textTheme.bodyMedium,
    ),
    const SizedBox(height: 4),
    Text(
      "جاری رکھنے کے لیے اپنی پسندیدہ زبان منتخب کریں",
      textAlign: TextAlign.center,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurface
            .withAlpha((0.7 * 255).round()),
      ),
    ),
  ],
),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () => onSelected(AppLanguage.english),
                        child: Text(
                          englishStrings.englishLabel,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => onSelected(AppLanguage.urdu),
                        child: Text(
                          englishStrings.urduLabel,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

