import 'dart:async';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'classifier_service.dart';
import 'detector_service.dart';

/// Final prediction result returned to the UI.
class CowHealthPrediction {
  CowHealthPrediction({
    required this.processedImageBytes,
    required this.label,
    required this.confidence,
    required this.statusText,
    required this.noDetection,
  });

  /// Image bytes (PNG) with red bounding box and label overlay.
  final Uint8List processedImageBytes;

  /// "Lumpy" or "Normal".
  final String label;

  /// Confidence in range 0–1.
  final double confidence;

  /// Status string for the UI (e.g. "Infected", "Healthy").
  final String statusText;

  /// True when no cow was detected in the image.
  final bool noDetection;
}

/// Pipeline:
/// image bytes → detect cow → crop → classify → draw box & label → bytes.
class PipelineService {
  PipelineService._internal();

  static final PipelineService instance = PipelineService._internal();

  /// Entry point for the UI.
  ///
  /// This method does not block the UI thread for heavy image operations; it
  /// offloads drawing to an isolate and uses async/await for the rest.
  Future<CowHealthPrediction> analyzeImage(Uint8List imageBytes) async {
    // Decode in the main isolate (fast enough; keeps interpreter usage simple).
    final img.Image? decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      throw const FormatException('Unable to decode image');
    }

    final DetectorService detector = DetectorService.instance;
    final ClassifierService classifier = ClassifierService.instance;

    // Step 1: Detect largest cow.
    final DetectionBox? box = await detector.detectLargestCow(decoded);
    if (box == null) {
      // No detection: still return the original image and a flag.
      final Uint8List pngBytes = await _encodePngInIsolate(decoded);
      return CowHealthPrediction(
        processedImageBytes: pngBytes,
        label: 'No cow detected',
        confidence: 0,
        statusText: 'No detection',
        noDetection: true,
      );
    }

    // Step 2: Crop cow region for classification.
    final img.Image crop = _cropToBox(decoded, box);

    // Step 3: Classify crop as Normal / Lumpy.
    final ClassificationResult classification =
        await classifier.classify(crop);

    final String status = classification.label == 'Lumpy'
        ? 'Infected'
        : 'Normal';

    // Step 4: Draw bounding box and label on original image in an isolate.
    final String overlayText =
        '${classification.label} ${(classification.confidence * 100).toStringAsFixed(1)}%';

    final Uint8List processedBytes = await _drawOverlayInIsolate(
      decoded,
      box,
      overlayText,
    );

    return CowHealthPrediction(
      processedImageBytes: processedBytes,
      label: classification.label,
      confidence: classification.confidence,
      statusText: status,
      noDetection: false,
    );
  }

  img.Image _cropToBox(img.Image source, DetectionBox box) {
    final int x = box.x.clamp(0, source.width - 1).toInt();
    final int y = box.y.clamp(0, source.height - 1).toInt();
    final int w = box.width.clamp(1, source.width - x).toInt();
    final int h = box.height.clamp(1, source.height - y).toInt();
    return img.copyCrop(source, x: x, y: y, width: w, height: h);
  }

  Future<Uint8List> _encodePngInIsolate(img.Image image) async {
    return Isolate.run(() {
      final bytes = img.encodePng(image);
      return Uint8List.fromList(bytes);
    });
  }

  Future<Uint8List> _drawOverlayInIsolate(
    img.Image original,
    DetectionBox box,
    String text,
  ) async {
    // Convert image to bytes for isolate
    final bytes = Uint8List.fromList(img.encodePng(original));

    final Map<String, dynamic> payload = {
      'bytes': bytes,
      'x': box.x,
      'y': box.y,
      'w': box.width,
      'h': box.height,
      'text': text,
    };

    return Isolate.run(() {
      final Uint8List raw = payload['bytes'] as Uint8List;
      final double x = payload['x'] as double;
      final double y = payload['y'] as double;
      final double w = payload['w'] as double;
      final double h = payload['h'] as double;
      final String text = payload['text'] as String;

      // Decode image from PNG bytes
      final img.Image imgOriginal = img.decodeImage(raw)!;

      final int width = imgOriginal.width;
      final int height = imgOriginal.height;

      final int left = x.clamp(0, width - 1).toInt();
      final int top = y.clamp(0, height - 1).toInt();
      final int right = (x + w).clamp(0, width - 1).toInt();
      final int bottom = (y + h).clamp(0, height - 1).toInt();

      // Draw red bounding box.
      final img.Color red = img.ColorRgb8(255, 59, 48); // iOS-style red
      img.drawRect(
        imgOriginal,
        x1: left,
        y1: top,
        x2: right,
        y2: bottom,
        color: red,
        thickness: 4,
      );

      // Draw label background.
      final img.Color bgColor = img.ColorRgba8(255, 255, 255, 204); // semi-transparent white
      final img.Color textColor = img.ColorRgb8(30, 142, 90); // medical green

      final int padding = 8;
      final int labelHeight = 32;
      final int bgLeft = left;
      final int bgTop = max(0, top - labelHeight - 4);
      final int bgRight = min(width - 1, left + 220);
      final int bgBottom = bgTop + labelHeight;

      img.fillRect(
        imgOriginal,
        x1: bgLeft,
        y1: bgTop,
        x2: bgRight,
        y2: bgBottom,
        color: bgColor,
      );

      // Draw text.
      img.drawString(
        imgOriginal,
        text,
        font: img.arial24,
        x: bgLeft + padding,
        y: bgTop + 4,
        color: textColor,
      );

      final List<int> encoded = img.encodePng(imgOriginal);
      return Uint8List.fromList(encoded);
    });
  }
}
