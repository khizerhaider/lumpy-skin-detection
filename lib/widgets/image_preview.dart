import 'dart:typed_data';

import 'package:flutter/material.dart';

class ImagePreview extends StatelessWidget {
  const ImagePreview({
    super.key,
    required this.imageBytes,
    required this.isLoading,
  });

  final Uint8List? imageBytes;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary.withAlpha((0.05 * 255).round()),
              theme.colorScheme.surface,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: Stack(
            children: [
              if (imageBytes != null)
                Positioned.fill(
                  child: AnimatedOpacity(
                    opacity: isLoading ? 0.6 : 1,
                    duration: const Duration(milliseconds: 250),
                    child: Image.memory(
                      imageBytes!,
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              else
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.health_and_safety_rounded,
                        size: 64,
                        color: theme.colorScheme.primary
                            .withAlpha((0.6 * 255).round()),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No image selected',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withAlpha((0.7 * 255).round()),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Use Camera or Gallery to start a scan.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withAlpha((0.6 * 255).round()),
                        ),
                      ),
                    ],
                  ),
                ),
              if (isLoading)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withAlpha((0.24 * 255).round()),
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

