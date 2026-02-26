import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';

class ResultCard extends StatelessWidget {
  const ResultCard({
    super.key,
    required this.label,
    required this.confidence,
    required this.statusText,
    required this.noDetection,
    required this.errorMessage,
  });

  final String? label;
  final double? confidence;
  final String? statusText;
  final bool noDetection;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppStrings.of(context);

    Color statusColor = theme.colorScheme.outline;
    IconData statusIcon = Icons.help_outline_rounded;
    String title = strings.awaitingTitle;
    String subtitle = strings.awaitingSubtitle;

    if (errorMessage != null) {
      statusColor = theme.colorScheme.error;
      statusIcon = Icons.error_outline_rounded;
      title = strings.errorTitle;
      subtitle = errorMessage!;
    } else if (noDetection) {
      statusColor = theme.colorScheme.secondary;
      statusIcon = Icons.search_off_rounded;
      title = strings.noCowDetectedTitle;
      subtitle = strings.noCowDetectedSubtitle;
    } else if (label != null && confidence != null && statusText != null) {
      final bool isLumpy = label!.toLowerCase().contains('lumpy');
      statusColor = isLumpy ? Colors.redAccent : Colors.green;
      statusIcon =
          isLumpy ? Icons.sick_rounded : Icons.check_circle_rounded;

      title = strings.predictionTitle(label!);
      subtitle = strings.predictionSubtitle(
        statusText: statusText!,
        confidence: confidence!,
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: statusColor.withAlpha((0.12 * 255).round()),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                statusIcon,
                color: statusColor,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface
                          .withAlpha((0.7 * 255).round()),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

