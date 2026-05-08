import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:aurafarm/core/theme/app_colors.dart';
import 'package:aurafarm/core/theme/app_text_styles.dart';
import 'package:aurafarm/features/add_person/presentation/widgets/capture_guide_overlay.dart';
import 'package:aurafarm/shared/services/face_recognition_service.dart';
import 'package:aurafarm/shared/services/storage_service.dart';

class FaceCaptureResult {
  final String imagePath;
  final List<List<double>> embeddings;
  const FaceCaptureResult({required this.imagePath, required this.embeddings});
}

class FaceCaptureScreen extends StatefulWidget {
  const FaceCaptureScreen({super.key});

  @override
  State<FaceCaptureScreen> createState() => _FaceCaptureScreenState();
}

class _FaceCaptureScreenState extends State<FaceCaptureScreen> {
  CameraController? _controller;
  int _sensorOrientation = 270;

  final _faceDetector = FaceDetector(options: FaceDetectorOptions(
    enableTracking: true,
    minFaceSize: 0.15,
    performanceMode: FaceDetectorMode.accurate,
  ));

  int _captureStep = 0;
  bool _faceInPosition = false;
  bool _isCapturing = false;
  bool _isProcessing = false;

  // Auto-capture
  Timer? _autoCaptureTimer;
  double _autoCaptureProgress = 0.0;
  static const _autoCaptureDurationMs = 1500;
  static const _timerIntervalMs = 50;

  final List<List<double>> _embeddings = [];
  String? _savedImagePath;
  int _frameCount = 0;

  static const _guides = [
    'Look straight ahead',
    'Turn your head to one side',
    'Turn your head to the other side',
  ];

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;
    final front = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
    _sensorOrientation = front.sensorOrientation;
    _controller = CameraController(
      front, ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    await _controller!.initialize();
    if (!mounted) return;
    setState(() {});
    _controller!.startImageStream(_onFrame);
  }

  InputImageRotation _sensorToInputRotation(int orientation) {
    switch (orientation) {
      case 0:   return InputImageRotation.rotation0deg;
      case 90:  return InputImageRotation.rotation90deg;
      case 180: return InputImageRotation.rotation180deg;
      case 270: return InputImageRotation.rotation270deg;
      default:  return InputImageRotation.rotation90deg;
    }
  }

  void _onFrame(CameraImage image) {
    if (_isProcessing || _isCapturing || _captureStep >= 3) return;
    _frameCount++;
    if (_frameCount % 8 != 0) return;
    _detectAndEvaluate(image);
  }

  static Uint8List _toNv21(CameraImage img) {
    final w = img.width, h = img.height;
    final out = Uint8List(w * h + w * h ~/ 2);
    var i = 0;
    final yBytes = img.planes[0].bytes;
    final yStride = img.planes[0].bytesPerRow;
    for (int r = 0; r < h; r++) {
      for (int c = 0; c < w; c++) { out[i++] = yBytes[r * yStride + c]; }
    }
    final uBytes = img.planes[1].bytes;
    final vBytes = img.planes[2].bytes;
    final uvStride = img.planes[1].bytesPerRow;
    final uvPx = img.planes[1].bytesPerPixel ?? 1;
    for (int r = 0; r < h ~/ 2; r++) {
      for (int c = 0; c < w ~/ 2; c++) {
        final o = r * uvStride + c * uvPx;
        out[i++] = vBytes[o];
        out[i++] = uBytes[o];
      }
    }
    return out;
  }

  Future<void> _detectAndEvaluate(CameraImage image) async {
    if (_isProcessing) return;
    _isProcessing = true;
    try {
      final inputImage = InputImage.fromBytes(
        bytes: _toNv21(image),
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: _sensorToInputRotation(_sensorOrientation),
          format: InputImageFormat.nv21,
          bytesPerRow: image.width,
        ),
      );

      final faces = await _faceDetector.processImage(inputImage);
      if (!mounted) return;

      if (faces.isEmpty) {
        _onFaceGone();
        return;
      }

      final face = faces.first;
      final inPos = _checkFaceInPosition(face, image.width.toDouble(), image.height.toDouble());

      if (inPos != _faceInPosition) {
        setState(() => _faceInPosition = inPos);
      }

      if (inPos) {
        _startAutoCapture();
      } else {
        _cancelAutoCapture();
      }
    } finally {
      _isProcessing = false;
    }
  }

  bool _checkFaceInPosition(Face face, double imgW, double imgH) {
    final box = face.boundingBox;

    // Camera delivers landscape frames; the face width maps to the shorter side
    final shortSide = imgW < imgH ? imgW : imgH;
    if (box.width < shortSide * 0.18 || box.width > shortSide * 0.85) return false;

    // Loose center check — just reject extreme off-center detections
    final cx = box.center.dx / imgW;
    final cy = box.center.dy / imgH;
    if ((cx - 0.5).abs() > 0.38 || (cy - 0.5).abs() > 0.38) return false;

    final yaw = face.headEulerAngleY ?? 0;
    switch (_captureStep) {
      case 0: return yaw.abs() < 20;       // looking roughly forward
      case 1: return yaw.abs() > 12;       // turned to either side
      case 2: return yaw.abs() > 12;       // turned to either side again
      default: return false;
    }
  }

  void _onFaceGone() {
    _cancelAutoCapture();
    if (_faceInPosition && mounted) setState(() => _faceInPosition = false);
  }

  void _startAutoCapture() {
    if (_autoCaptureTimer != null && _autoCaptureTimer!.isActive) return;
    _autoCaptureTimer = Timer.periodic(
      const Duration(milliseconds: _timerIntervalMs),
      (timer) {
        if (!mounted) { timer.cancel(); return; }
        final next = _autoCaptureProgress + (_timerIntervalMs / _autoCaptureDurationMs);
        if (next >= 1.0) {
          timer.cancel();
          setState(() => _autoCaptureProgress = 1.0);
          _capture();
        } else {
          setState(() => _autoCaptureProgress = next);
        }
      },
    );
  }

  void _cancelAutoCapture() {
    _autoCaptureTimer?.cancel();
    _autoCaptureTimer = null;
    if (_autoCaptureProgress != 0 && mounted) {
      setState(() => _autoCaptureProgress = 0);
    }
  }

  Future<void> _capture() async {
    if (_isCapturing) return;
    _cancelAutoCapture();
    setState(() { _isCapturing = true; _autoCaptureProgress = 0; });

    try {
      final xp = await _controller!.takePicture();
      final bytes = await xp.readAsBytes();

      // Detect the face in the JPEG so registration embeds a face crop —
      // the same input format that live recognition uses.
      List<double> embedding = [];
      final photoFaces = await _faceDetector.processImage(
        InputImage.fromFilePath(xp.path),
      );
      if (photoFaces.isNotEmpty) {
        final decoded = img.decodeImage(bytes);
        if (decoded != null) {
          final box = photoFaces.first.boundingBox;
          final padX = box.width * 0.25;
          final padY = box.height * 0.25;
          final l = (box.left - padX).clamp(0.0, decoded.width - 1.0).toInt();
          final t = (box.top - padY).clamp(0.0, decoded.height - 1.0).toInt();
          final r = (box.right + padX).clamp(1.0, decoded.width.toDouble()).toInt();
          final b = (box.bottom + padY).clamp(1.0, decoded.height.toDouble()).toInt();
          final face = img.copyCrop(decoded, x: l, y: t, width: r - l, height: b - t);
          embedding = await FaceRecognitionService.instance.generateEmbeddingFromImage(face) ?? [];
        }
      }
      // Fallback to full photo if face detection failed
      if (embedding.isEmpty) {
        embedding = await FaceRecognitionService.instance.generateEmbeddingFromJpeg(bytes) ?? [];
      }
      _embeddings.add(embedding);

      if (_captureStep == 0) {
        _savedImagePath = await StorageService.instance.saveFaceImage(bytes);
      }

      setState(() {
        _captureStep++;
        _isCapturing = false;
        _faceInPosition = false;
      });

      if (_captureStep >= 3) {
        await _controller!.stopImageStream();
        _finish();
      }
    } catch (_) {
      setState(() => _isCapturing = false);
    }
  }

  void _finish() {
    final valid = _embeddings.where((e) => e.isNotEmpty).toList();
    Navigator.pop(context, FaceCaptureResult(
      imagePath: _savedImagePath ?? '',
      embeddings: valid,
    ));
  }

  @override
  void dispose() {
    _autoCaptureTimer?.cancel();
    _controller?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: AppColors.orange)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_controller!),

          CaptureGuideOverlay(
            faceDetected: _faceInPosition,
            captureStep: _captureStep,
            guideText: _captureStep < 3 ? _guides[_captureStep] : 'Done!',
          ),

          // Progress dots (top)
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 0, right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: i == _captureStep ? 24 : 10,
                height: 10,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  color: i < _captureStep
                      ? AppColors.orange
                      : i == _captureStep
                          ? AppColors.white
                          : AppColors.grayMid,
                ),
              )),
            ),
          ),

          // Bottom capture area — respects safe area
          if (_captureStep < 3)
            Positioned(
              bottom: bottomPadding + 32,
              left: 0, right: 0,
              child: Column(
                children: [
                  // Status text
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      key: ValueKey(_faceInPosition),
                      _faceInPosition
                          ? 'Hold still…'
                          : _guides[_captureStep],
                      style: AppTextStyles.bodySmall.copyWith(
                        color: _faceInPosition ? AppColors.orange : Colors.white,
                        fontWeight: _faceInPosition ? FontWeight.w600 : FontWeight.w400,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Capture button with auto-capture ring
                  GestureDetector(
                    onTap: _isCapturing ? null : _capture,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Auto-capture progress ring
                        SizedBox(
                          width: 80, height: 80,
                          child: CircularProgressIndicator(
                            value: _autoCaptureProgress,
                            strokeWidth: 4,
                            color: AppColors.orange,
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        // Inner button
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 64, height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _faceInPosition ? AppColors.orange : Colors.white.withValues(alpha: 0.3),
                            boxShadow: _faceInPosition
                                ? [const BoxShadow(color: AppColors.orangeGlow, blurRadius: 20, spreadRadius: 4)]
                                : [],
                          ),
                          child: _isCapturing
                              ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                              : const Icon(Icons.camera_alt, color: Colors.white, size: 28),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Auto-captures when ready • tap to force',
                    style: AppTextStyles.labelSmall.copyWith(color: Colors.white.withValues(alpha: 0.5)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
