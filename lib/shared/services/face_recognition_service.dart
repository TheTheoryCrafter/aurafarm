import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:aurafarm/core/constants/app_constants.dart';
import 'package:aurafarm/shared/models/person_model.dart';

class FaceRecognitionService {
  static final instance = FaceRecognitionService._();
  FaceRecognitionService._();

  Interpreter? _interpreter;
  bool get isModelLoaded => _interpreter != null;

  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/models/facenet.tflite');
      debugPrint('FaceNet model loaded');
    } catch (e) {
      debugPrint('FaceNet model not found — recognition disabled. Place facenet.tflite in assets/models/');
    }
  }

  /// Generate embedding from a live camera frame.
  /// ML Kit returns bounding boxes in the original (pre-rotation) image space,
  /// so we crop first using those coordinates, then rotate only the face crop.
  Future<List<double>?> generateEmbedding(
    CameraImage cameraImage,
    Rect faceBoundingBox, {
    int sensorRotation = 0,
  }) async {
    if (_interpreter == null) return null;
    try {
      final rgbImage = _yuv420ToRgb(cameraImage);
      // Crop face in original coordinate space with 25% padding on each side
      final padX = faceBoundingBox.width * 0.25;
      final padY = faceBoundingBox.height * 0.25;
      final l = (faceBoundingBox.left - padX).clamp(0.0, rgbImage.width - 1.0).toInt();
      final t = (faceBoundingBox.top - padY).clamp(0.0, rgbImage.height - 1.0).toInt();
      final r = (faceBoundingBox.right + padX).clamp(1.0, rgbImage.width.toDouble()).toInt();
      final b = (faceBoundingBox.bottom + padY).clamp(1.0, rgbImage.height.toDouble()).toInt();
      var face = img.copyCrop(rgbImage, x: l, y: t, width: r - l, height: b - t);
      // Rotate the face crop to upright so FaceNet sees it the same way as registration photos
      if (sensorRotation == 90) {
        face = img.copyRotate(face, angle: 90);
      } else if (sensorRotation == 270) {
        face = img.copyRotate(face, angle: -90);
      } else if (sensorRotation == 180) {
        face = img.copyRotate(face, angle: 180);
      }
      return _runInferenceOnImage(face);
    } catch (e) {
      debugPrint('Embedding error: $e');
      return null;
    }
  }

  /// Generate embedding from an already-decoded and cropped face image.
  Future<List<double>?> generateEmbeddingFromImage(img.Image faceImage) async {
    if (_interpreter == null) return null;
    try {
      return _runInferenceOnImage(faceImage);
    } catch (e) {
      debugPrint('Embedding error: $e');
      return null;
    }
  }

  /// Fallback: generate embedding from raw JPEG bytes (no face crop).
  Future<List<double>?> generateEmbeddingFromJpeg(Uint8List jpegBytes) async {
    if (_interpreter == null) return null;
    try {
      final decoded = img.decodeImage(jpegBytes);
      if (decoded == null) return null;
      return _runInferenceOnImage(decoded);
    } catch (e) {
      debugPrint('Embedding from jpeg error: $e');
      return null;
    }
  }

  Person? findBestMatch(List<double> embedding, List<Person> people) {
    double bestScore = 0;
    Person? bestMatch;
    for (final person in people) {
      if (person.faceEmbeddings.isEmpty) continue;
      for (final stored in person.faceEmbeddings) {
        final score = _cosineSimilarity(embedding, stored);
        if (score > bestScore) {
          bestScore = score;
          bestMatch = person;
        }
      }
    }
    if (bestScore > 0.4) debugPrint('Recognition: ${bestMatch?.name} score=${bestScore.toStringAsFixed(3)} threshold=${AppConstants.recognitionThreshold}');
    return bestScore >= AppConstants.recognitionThreshold ? bestMatch : null;
  }

  List<double> averageEmbeddings(List<List<double>> embeddings) {
    if (embeddings.isEmpty) return [];
    final result = List.filled(embeddings[0].length, 0.0);
    for (final e in embeddings) {
      for (int i = 0; i < e.length; i++) { result[i] += e[i]; }
    }
    for (int i = 0; i < result.length; i++) { result[i] /= embeddings.length; }
    return result;
  }

  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length || a.isEmpty) return 0;
    double dot = 0, normA = 0, normB = 0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    final denom = sqrt(normA) * sqrt(normB);
    return denom == 0 ? 0 : dot / denom;
  }

  img.Image _yuv420ToRgb(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final result = img.Image(width: width, height: height);

    final yBuffer = image.planes[0].bytes;
    final uBuffer = image.planes[1].bytes;
    final vBuffer = image.planes[2].bytes;

    final yRowStride = image.planes[0].bytesPerRow;
    final uvRowStride = image.planes[1].bytesPerRow;
    final uvPixelStride = image.planes[1].bytesPerPixel ?? 1;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final yIdx = y * yRowStride + x;
        final uvIdx = (y ~/ 2) * uvRowStride + (x ~/ 2) * uvPixelStride;

        if (yIdx >= yBuffer.length || uvIdx >= uBuffer.length || uvIdx >= vBuffer.length) continue;

        final yVal = yBuffer[yIdx].toDouble();
        final uVal = uBuffer[uvIdx].toDouble() - 128;
        final vVal = vBuffer[uvIdx].toDouble() - 128;

        result.setPixelRgb(x, y,
          (yVal + 1.402 * vVal).round().clamp(0, 255),
          (yVal - 0.344136 * uVal - 0.714136 * vVal).round().clamp(0, 255),
          (yVal + 1.772 * uVal).round().clamp(0, 255),
        );
      }
    }
    return result;
  }

  List<double>? _runInferenceOnImage(img.Image faceImage) {
    final resized = img.copyResize(faceImage, width: 160, height: 160);
    final input = List.generate(1, (_) =>
      List.generate(160, (y) =>
        List.generate(160, (x) =>
          List.generate(3, (c) {
            final pixel = resized.getPixel(x, y);
            final vals = [pixel.r.toDouble(), pixel.g.toDouble(), pixel.b.toDouble()];
            return vals[c] / 127.5 - 1.0;
          }))));
    final output = List.generate(1, (_) => List.filled(512, 0.0));
    _interpreter!.run(input, output);
    return List<double>.from(output[0]);
  }
}
