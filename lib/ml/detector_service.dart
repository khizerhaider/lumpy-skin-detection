import 'dart:math';

import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// Represents a single detection bounding box in image pixel coordinates.
class DetectionBox {
  DetectionBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.score,
    required this.classIndex,
  });

  final double x;
  final double y;
  final double width;
  final double height;
  final double score;
  final int classIndex;

  bool get isValid => width > 1 && height > 1 && score > 0;
}


/// - Loads `models/detector/yolo26n_float32.tflite` once.
/// - Expects 640x640x3 float32 input, normalized to 0–1.
/// - Uses Ultralytics end-to-end export which returns pre-NMS detections.
class DetectorService {
  DetectorService._internal();

  static final DetectorService instance = DetectorService._internal();

  static const _modelAssetPath = 'models/detector/yolo26n_float32.tflite';
  static const _inputSize = 640;
  /// Match Python pipeline: CONF_THRESH = 0.25
  static const _confThreshold = 0.25;
  /// Low-confidence fallback used when nothing passes [_confThreshold].
  static const _fallbackThreshold = 0.05;

  Interpreter? _interpreter;
  bool _isInitialized = false;

  Future<void> _loadModel() async {
    if (_isInitialized) return;

    final options = InterpreterOptions()
      ..threads = 2;

    _interpreter = await Interpreter.fromAsset(_modelAssetPath, options: options);
    _isInitialized = true;
  }

  /// Runs detection on the given image and returns the *largest* box, if any.
  ///
  /// Takes all detections above [_confThreshold] (no class filter, see
  /// DOCUMENTATION.md "Decision 2") and picks the largest by area. If none
  /// pass, falls back to the best area x score above [_fallbackThreshold]. [original] is the original image. The box coordinates
  /// are returned in the original image pixel space.
  Future<DetectionBox?> detectLargestCow(img.Image original) async {
    await _loadModel();
    final interpreter = _interpreter;
    if (interpreter == null) {
      throw StateError('Detector interpreter not initialized');
    }

    // Preprocess image to 640x640 float32 in 0–1 range.
    final inputTensor = _buildInputTensor(original);

    // Prepare output buffer.
    final outputTensor = interpreter.getOutputTensor(0);
    final outputShape = outputTensor.shape;

    // IMPORTANT: `Interpreter.run()` requires the output object to match
    // the output tensor shape (e.g. [1, 300, 6]), not a flat 1D buffer.
    final dynamic output = _allocateOutput(outputShape);
    interpreter.run(inputTensor, output);

    final List<double> flat = _flattenOutput(output);
    if (flat.isEmpty) {
      return null;
    }

    final int valuesPerDet = 6;
    if (flat.length % valuesPerDet != 0) {
      // Fallback: cannot parse
      return null;
    }

    final DetectionBox? best = _findLargestCow(
      flat,
      originalWidth: original.width,
      originalHeight: original.height,
    );

    return best?.isValid == true ? best : null;
  }

  /// Builds a float32 input tensor for YOLOv8 from the original image.
  ///
  /// The tensor has shape [1, 640, 640, 3] and values in 0–1.
  List<List<List<List<double>>>> _buildInputTensor(img.Image original) {
    final img.Image resized = img.copyResize(
      original,
      width: _inputSize,
      height: _inputSize,
      interpolation: img.Interpolation.cubic,
    );

    // Convert to float32 and normalize to 0-1 range manually
    final List<List<List<List<double>>>> input =
        List.generate(1, (_) {
      return List.generate(_inputSize, (y) {
        return List.generate(_inputSize, (x) {
          final pixel = resized.getPixel(x, y);
          // Extract RGB from Pixel object
          final r = pixel.r;
          final g = pixel.g;
          final b = pixel.b;
          
          // Normalize to 0-1 range
          return <double>[
            r / 255.0,
            g / 255.0,
            b / 255.0,
          ];
        });
      });
    });

    return input;
  }

  /// Allocates an output object matching [shape], filled with 0.0.
  dynamic _allocateOutput(List<int> shape) {
    dynamic alloc(int dim) {
      if (dim == shape.length - 1) {
        return List<double>.filled(shape[dim], 0.0);
      }
      return List.generate(shape[dim], (_) => alloc(dim + 1));
    }

    if (shape.isEmpty) {
      return <double>[];
    }
    return alloc(0);
  }

  /// Flattens output tensors (List nested) into a 1D list.
  List<double> _flattenOutput(dynamic output) {
    final List<double> flat = <double>[];

    void visit(dynamic node) {
      if (node is double) {
        flat.add(node);
      } else if (node is int) {
        flat.add(node.toDouble());
      } else if (node is List) {
        for (final v in node) {
          visit(v);
        }
      }
    }

    visit(output);
    return flat;
  }

  /// Decodes the Ultralytics end-to-end output.
  ///
  /// Each row is `[x1, y1, x2, y2, score, classId]` with coordinates
  /// normalized to 0–1 (verified against the exported model metadata:
  /// `end2end: true`). Class is intentionally not filtered because local
  /// cattle breeds are often labelled horse/elephant/person by the COCO model.
  DetectionBox? _findLargestCow(
    List<double> flat, {
    required int originalWidth,
    required int originalHeight,
  }) {
    return _selectBox(flat, originalWidth, originalHeight,
            minScore: _confThreshold, weightByScore: false) ??
        _selectBox(flat, originalWidth, originalHeight,
            minScore: _fallbackThreshold, weightByScore: true);
  }

  DetectionBox? _selectBox(
    List<double> flat,
    int originalWidth,
    int originalHeight, {
    required double minScore,
    required bool weightByScore,
  }) {
    final int n = flat.length ~/ 6;
    final double size = _inputSize.toDouble();
    final double scaleX = originalWidth / _inputSize;
    final double scaleY = originalHeight / _inputSize;

    DetectionBox? best;
    double bestArea = 0;

    for (int i = 0; i < n; i++) {
      final int o = i * 6;
      final double score = flat[o + 4];
      final int classId = flat[o + 5].round();
      if (!score.isFinite || score < minScore) continue;

      double x1 = flat[o + 0];
      double y1 = flat[o + 1];
      double x2 = flat[o + 2];
      double y2 = flat[o + 3];

      // Coordinates are normalized; scale to model input space.
      final double coordMax =
          max(max(x1.abs(), y1.abs()), max(x2.abs(), y2.abs()));
      if (coordMax <= 2.0) {
        x1 *= size;
        y1 *= size;
        x2 *= size;
        y2 *= size;
      }

      final double left = min(x1, x2).clamp(0.0, size);
      final double top = min(y1, y2).clamp(0.0, size);
      final double right = max(x1, x2).clamp(0.0, size);
      final double bottom = max(y1, y2).clamp(0.0, size);
      final double w = right - left;
      final double h = bottom - top;
      if (w <= 2 || h <= 2) continue;

      // Map back to original image size (input was stretch-resized).
      final double area =
          (w * scaleX) * (h * scaleY) * (weightByScore ? score : 1.0);
      if (area > bestArea) {
        bestArea = area;
        best = DetectionBox(
          x: left * scaleX,
          y: top * scaleY,
          width: w * scaleX,
          height: h * scaleY,
          score: score,
          classIndex: classId,
        );
      }
    }

    return best;
  }
}
