import 'dart:math';

import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// Result of the lumpy vs normal classifier.
class ClassificationResult {
  ClassificationResult({
    required this.label,
    required this.confidence,
  });

  /// Human readable label ("Lumpy" or "Normal").
  final String label;

  /// Confidence in range 0–1.
  final double confidence;
}

/// Lumpy skin disease classifier service.
///
/// Uses `models/best_float32.tflite` (Ultralytics YOLOv8-cls, 224x224).
class ClassifierService {
  ClassifierService._internal();

  static final ClassifierService instance = ClassifierService._internal();

  static const _modelAssetPath = 'models/best_float32.tflite';
  static const _inputSize = 224;

  Interpreter? _interpreter;
  bool _isInitialized = false;

  Future<void> _loadModel() async {
    if (_isInitialized) return;

    final options = InterpreterOptions()
      ..threads = 2;

    _interpreter = await Interpreter.fromAsset(_modelAssetPath, options: options);
    _isInitialized = true;
  }

  /// Classifies the given cropped cow image into Normal / Lumpy.
  ///
  /// Returns [ClassificationResult] with predicted label and confidence.
  Future<ClassificationResult> classify(img.Image crop) async {
    await _loadModel();
    final interpreter = _interpreter;
    if (interpreter == null) {
      throw StateError('Classifier interpreter not initialized');
    }

    // Preprocess to 224x224 float32, normalized to 0–1.
    final input = _buildInputTensor(crop);

    final outputTensor = interpreter.getOutputTensor(0);
    final outputShape = outputTensor.shape;

    // IMPORTANT: output object must match output tensor shape.
    final dynamic output = _allocateOutput(outputShape);
    interpreter.run(input, output);

    final raw = _flattenOutput(output);
    if (raw.isEmpty) {
      throw StateError('Classifier output is empty');
    }

    // Ultralytics YOLOv8-cls TFLite exports often already include softmax,
    // meaning the model output is already probabilities that sum ~ 1.
    // If we apply softmax again, confidence is artificially reduced
    // (e.g. 0.99 -> ~0.73). So only softmax when the output doesn't
    // look like probabilities.
    final probs = _asProbabilities(raw);

    // Metadata: index 0 = lumpy, 1 = normal.
    int bestIdx = 0;
    double bestVal = probs[0];
    for (int i = 1; i < probs.length; i++) {
      if (probs[i] > bestVal) {
        bestVal = probs[i];
        bestIdx = i;
      }
    }

    final String label = switch (bestIdx) {
      0 => 'Lumpy',
      1 => 'Normal',
      _ => 'Unknown',
    };

    return ClassificationResult(
      label: label,
      confidence: bestVal.clamp(0.0, 1.0),
    );
  }

  /// Builds a float32 input tensor for the classifier from the cropped image.
  ///
  /// The tensor has shape [1, 224, 224, 3] and values in 0–1.
  ///
  /// IMPORTANT:
  /// - Use square center crop to avoid aspect ratio distortion.
  /// - Matches Ultralytics letterbox-style behavior more closely than stretch.
  List<List<List<List<double>>>> _buildInputTensor(img.Image crop) {
    // Avoid stretch-resize; instead, take a centered square crop resized
    // to the expected classifier input size.
    final img.Image resized =
        img.copyResizeCropSquare(crop, size: _inputSize);

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

  /// Numerically stable softmax over logits.
  List<double> _softmax(List<double> logits) {
    final double maxLogit = logits.reduce(max);
    final List<double> exps = logits.map((v) => exp(v - maxLogit)).toList();
    final double sum = exps.fold(0.0, (a, b) => a + b);
    return exps.map((v) => v / (sum == 0 ? 1.0 : sum)).toList();
  }

  List<double> _asProbabilities(List<double> raw) {
    if (raw.isEmpty) return raw;
    if (raw.length == 1) return raw;

    double minV = raw[0];
    double maxV = raw[0];
    double sum = 0.0;
    for (final v in raw) {
      if (v < minV) minV = v;
      if (v > maxV) maxV = v;
      sum += v;
    }

    // Heuristic: treat as probs if values are in [0,1] and sum ~ 1.
    const eps = 1e-3;
    final looksLikeProbs = minV >= -eps && maxV <= 1.0 + eps && (sum - 1.0).abs() <= 1e-2;
    if (looksLikeProbs) {
      // Clamp tiny numeric drift.
      return raw.map((v) => v.clamp(0.0, 1.0)).toList();
    }

    return _softmax(raw);
  }

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
}
