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
  /// Matches Python pipeline: take all detections, pick largest by area
  /// (no class filter). [original] is the original image. The box coordinates
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

    final DetectionBox? best =
        _findBestBoxRobust(flat, originalWidth: original.width, originalHeight: original.height);

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

  DetectionBox? _findBestBoxRobust(
    List<double> flat, {
    required int originalWidth,
    required int originalHeight,
  }) {
    final int n = flat.length ~/ 6;

    // Try common Ultralytics/TFLite layouts:
    // A) xyxy + score + class
    // B) xyxy + class + score
    // C) xywh(center) + score + class
    // D) xywh(center) + class + score
    final List<_Layout> layouts = const [
      _Layout.xyxyScoreClass,
      _Layout.xyxyClassScore,
      _Layout.xywhScoreClass,
      _Layout.xywhClassScore,
    ];

    DetectionBox? best;
    double bestArea = 0;

    // For debug visibility: show max score seen per layout.
    assert(() {
      final Map<_Layout, double> maxScore = {};
      for (final layout in layouts) {
        maxScore[layout] = 0;
      }
      for (int i = 0; i < n; i++) {
        final int o = i * 6;
        final a = flat[o + 0];
        final b = flat[o + 1];
        final c = flat[o + 2];
        final d = flat[o + 3];
        final e = flat[o + 4];
        final f = flat[o + 5];
        for (final layout in layouts) {
          final _DecodedRow row = _decodeRow(a, b, c, d, e, f, layout);
          if (row.score.isFinite) {
            maxScore[layout] = max(maxScore[layout]!, row.score);
          }
        }
      }
      // ignore: avoid_print
      print('[Detector] output rows=$n maxScore='
          '${maxScore.map((k, v) => MapEntry(k.name, v.toStringAsFixed(3)))}');
      return true;
    }());

    for (final layout in layouts) {
      DetectionBox? localBest;
      double localBestArea = 0;

      for (int i = 0; i < n; i++) {
        final int o = i * 6;
        final a = flat[o + 0];
        final b = flat[o + 1];
        final c = flat[o + 2];
        final d = flat[o + 3];
        final e = flat[o + 4];
        final f = flat[o + 5];

        final _DecodedRow row = _decodeRow(a, b, c, d, e, f, layout);
        if (!row.score.isFinite || row.score <= 0) continue;
        if (row.score < _confThreshold) continue;

        // Determine if coords are normalized (0..1) or already in 0..640 space.
        final double coordMax = max(max(row.x1.abs(), row.y1.abs()), max(row.x2.abs(), row.y2.abs()));
        final bool normalized = coordMax <= 2.0; // tolerant threshold

        double x1 = row.x1;
        double y1 = row.y1;
        double x2 = row.x2;
        double y2 = row.y2;

        if (normalized) {
          x1 *= _inputSize;
          y1 *= _inputSize;
          x2 *= _inputSize;
          y2 *= _inputSize;
        }

        // Fix ordering
        final double left = min(x1, x2).clamp(0.0, _inputSize.toDouble());
        final double top = min(y1, y2).clamp(0.0, _inputSize.toDouble());
        final double right = max(x1, x2).clamp(0.0, _inputSize.toDouble());
        final double bottom = max(y1, y2).clamp(0.0, _inputSize.toDouble());

        final double w = right - left;
        final double h = bottom - top;
        if (w <= 2 || h <= 2) continue;

        // Map back to original image size (we used stretch-resize to 640x640).
        final double scaleX = originalWidth / _inputSize;
        final double scaleY = originalHeight / _inputSize;

        final double mappedX = left * scaleX;
        final double mappedY = top * scaleY;
        final double mappedW = w * scaleX;
        final double mappedH = h * scaleY;

        final double area = mappedW * mappedH;
        if (area > localBestArea) {
          localBestArea = area;
          localBest = DetectionBox(
            x: mappedX,
            y: mappedY,
            width: mappedW,
            height: mappedH,
            score: row.score,
            classIndex: row.classIndex,
          );
        }
      }

      // If this layout produced a candidate, prefer it (largest area).
      if (localBest != null && localBestArea > bestArea) {
        bestArea = localBestArea;
        best = localBest;
      }
    }

    // If nothing found at 0.25, try a soft fallback (helps when model scores are low).
    best ??= _fallbackBestAny(flat, originalWidth: originalWidth, originalHeight: originalHeight);

    return best;
  }

  DetectionBox? _fallbackBestAny(
    List<double> flat, {
    required int originalWidth,
    required int originalHeight,
  }) {
    const double minScore = 0.05;
    final int n = flat.length ~/ 6;
    DetectionBox? best;
    double bestWeighted = 0;

    for (final layout in const [
      _Layout.xyxyScoreClass,
      _Layout.xywhScoreClass,
      _Layout.xyxyClassScore,
      _Layout.xywhClassScore,
    ]) {
      for (int i = 0; i < n; i++) {
        final int o = i * 6;
        final row = _decodeRow(
          flat[o + 0],
          flat[o + 1],
          flat[o + 2],
          flat[o + 3],
          flat[o + 4],
          flat[o + 5],
          layout,
        );
        if (!row.score.isFinite || row.score < minScore) continue;

        final double coordMax = max(max(row.x1.abs(), row.y1.abs()), max(row.x2.abs(), row.y2.abs()));
        final bool normalized = coordMax <= 2.0;
        double x1 = row.x1, y1 = row.y1, x2 = row.x2, y2 = row.y2;
        if (normalized) {
          x1 *= _inputSize;
          y1 *= _inputSize;
          x2 *= _inputSize;
          y2 *= _inputSize;
        }

        final double left = min(x1, x2).clamp(0.0, _inputSize.toDouble());
        final double top = min(y1, y2).clamp(0.0, _inputSize.toDouble());
        final double right = max(x1, x2).clamp(0.0, _inputSize.toDouble());
        final double bottom = max(y1, y2).clamp(0.0, _inputSize.toDouble());

        final double w = right - left;
        final double h = bottom - top;
        if (w <= 2 || h <= 2) continue;

        final double scaleX = originalWidth / _inputSize;
        final double scaleY = originalHeight / _inputSize;

        final double mappedX = left * scaleX;
        final double mappedY = top * scaleY;
        final double mappedW = w * scaleX;
        final double mappedH = h * scaleY;

        final double weighted = (mappedW * mappedH) * row.score;
        if (weighted > bestWeighted) {
          bestWeighted = weighted;
          best = DetectionBox(
            x: mappedX,
            y: mappedY,
            width: mappedW,
            height: mappedH,
            score: row.score,
            classIndex: row.classIndex,
          );
        }
      }
    }
    return best;
  }
}

enum _Layout {
  xyxyScoreClass,
  xyxyClassScore,
  xywhScoreClass,
  xywhClassScore;

  String get name => toString().split('.').last;
}

class _DecodedRow {
  const _DecodedRow({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.score,
    required this.classIndex,
  });

  final double x1;
  final double y1;
  final double x2;
  final double y2;
  final double score;
  final int classIndex;
}

_DecodedRow _decodeRow(
  double a,
  double b,
  double c,
  double d,
  double e,
  double f,
  _Layout layout,
) {
  // Heuristics:
  // - score should be in 0..1
  // - classIndex should be around 0..80
  double score;
  double classVal;
  double x1, y1, x2, y2;

  switch (layout) {
    case _Layout.xyxyScoreClass:
      x1 = a;
      y1 = b;
      x2 = c;
      y2 = d;
      score = e;
      classVal = f;
    case _Layout.xyxyClassScore:
      x1 = a;
      y1 = b;
      x2 = c;
      y2 = d;
      score = f;
      classVal = e;
    case _Layout.xywhScoreClass:
      final cx = a;
      final cy = b;
      final w = c;
      final h = d;
      x1 = cx - w / 2.0;
      y1 = cy - h / 2.0;
      x2 = cx + w / 2.0;
      y2 = cy + h / 2.0;
      score = e;
      classVal = f;
    case _Layout.xywhClassScore:
      final cx = a;
      final cy = b;
      final w = c;
      final h = d;
      x1 = cx - w / 2.0;
      y1 = cy - h / 2.0;
      x2 = cx + w / 2.0;
      y2 = cy + h / 2.0;
      score = f;
      classVal = e;
  }

  // Sanity: if score is clearly not a probability, mark as invalid.
  if (!score.isFinite || score < 0 || score > 1.5) {
    score = double.nan;
  }

  // Best effort class index.
  int classIndex = classVal.isFinite ? classVal.round() : -1;
  if (classIndex < 0 || classIndex > 1000) {
    classIndex = -1;
  }

  return _DecodedRow(
    x1: x1,
    y1: y1,
    x2: x2,
    y2: y2,
    score: score,
    classIndex: classIndex,
  );
}

