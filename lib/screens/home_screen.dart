import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_gallery_saver/flutter_image_gallery_saver.dart';

import '../l10n/app_strings.dart';
import '../ml/pipeline_service.dart';
import '../widgets/image_preview.dart';
import '../widgets/result_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ImagePicker _picker = ImagePicker();

  Uint8List? _displayImageBytes;
  String? _label;
  double? _confidence;
  String? _statusText;
  bool _noDetection = false;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _saveToGallery() async {
    final strings = AppStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final bytes = _displayImageBytes;

    if (bytes == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(strings.downloadNoImage)),
      );
      return;
    }

    try {
      final saver = ImageGallerySaver();
      await saver.saveImage(bytes);

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            strings.downloadSuccess,
          ),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(strings.downloadFailure)),
      );
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
      );

      if (picked == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      final Uint8List bytes = await picked.readAsBytes();

      if (!mounted) return;

      setState(() {
        _displayImageBytes = bytes;
        _label = null;
        _confidence = null;
        _statusText = null;
        _noDetection = false;
      });

      final PipelineService pipeline = PipelineService.instance;
      final CowHealthPrediction prediction =
          await pipeline.analyzeImage(bytes);

      if (!mounted) return;

      setState(() {
        _displayImageBytes = prediction.processedImageBytes;
        _label = prediction.label;
        _confidence = prediction.confidence;
        _statusText = prediction.statusText;
        _noDetection = prediction.noDetection;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to analyze image. ${e.toString()}';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('An error occurred while running inference.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppStrings.of(context);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              title: Text(
                strings.appTitle,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              centerTitle: true,
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.tagline,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withAlpha((0.7 * 255).round()),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            onPressed:
                                _isLoading ? null : () => _pickImage(ImageSource.camera),
                            icon: const Icon(Icons.photo_camera_rounded),
                          label: Text(strings.cameraButton),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            onPressed:
                                _isLoading ? null : () => _pickImage(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_rounded),
                          label: Text(strings.galleryButton),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: ImagePreview(
                  imageBytes: _displayImageBytes,
                  isLoading: _isLoading,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: FilledButton.icon(
                  onPressed: _isLoading ? null : _saveToGallery,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: const Icon(Icons.download_rounded),
                  label: Text(AppStrings.of(context).downloadButton),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: ResultCard(
                  label: _label,
                  confidence: _confidence,
                  statusText: _statusText,
                  noDetection: _noDetection,
                  errorMessage: _errorMessage,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  strings.guidelinesTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      strings.guidelinesBody,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.4,
                        color: theme.colorScheme.onSurface
                            .withAlpha((0.8 * 255).round()),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],
        ),
      ),
    );
  }
}

