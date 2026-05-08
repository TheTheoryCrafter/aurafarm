import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:aurafarm/core/theme/app_colors.dart';
import 'package:aurafarm/core/theme/app_text_styles.dart';
import 'package:aurafarm/features/camera/providers/camera_provider.dart';
import 'package:aurafarm/features/camera/providers/recognition_provider.dart';
import 'package:aurafarm/features/camera/presentation/widgets/face_overlay_painter.dart';
import 'package:aurafarm/features/camera/presentation/widgets/recognition_badge_sheet.dart';
import 'package:aurafarm/features/people/providers/people_provider.dart';
import 'package:aurafarm/shared/services/face_recognition_service.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> with WidgetsBindingObserver {
  final _faceDetector = FaceDetector(options: FaceDetectorOptions(
    enableTracking: true,
    minFaceSize: 0.15,
    performanceMode: FaceDetectorMode.fast,
  ));

  List<Face> _faces = [];
  int _frameCount = 0;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(cameraProvider.notifier).initialize();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cam = ref.read(cameraProvider);
    if (cam.controller == null || !cam.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      cam.controller!.stopImageStream();
    } else if (state == AppLifecycleState.resumed) {
      _startStream(cam.controller!);
    }
  }

  void _startStream(CameraController controller) {
    if (controller.value.isStreamingImages) return;
    controller.startImageStream(_onFrame);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _faceDetector.close();
    super.dispose();
  }

  InputImageRotation _sensorToInputRotation(int sensorOrientation) {
    switch (sensorOrientation) {
      case 0:   return InputImageRotation.rotation0deg;
      case 90:  return InputImageRotation.rotation90deg;
      case 180: return InputImageRotation.rotation180deg;
      case 270: return InputImageRotation.rotation270deg;
      default:  return InputImageRotation.rotation90deg;
    }
  }

  void _onFrame(CameraImage image) {
    if (_isProcessing) return;
    _frameCount++;
    if (_frameCount % 10 != 0) return;
    _processFrame(image);
  }

  // Converts YUV_420_888 CameraImage to NV21 bytes that ML Kit accepts.
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

  Future<void> _processFrame(CameraImage image) async {
    if (_isProcessing) return;
    _isProcessing = true;
    try {
      final sensorOrientation = ref.read(cameraProvider).controller?.description.sensorOrientation ?? 90;
      final rotation = _sensorToInputRotation(sensorOrientation);
      final inputImage = InputImage.fromBytes(
        bytes: _toNv21(image),
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.width,
        ),
      );

      final faces = await _faceDetector.processImage(inputImage);
      if (mounted) setState(() => _faces = faces);

      if (faces.isEmpty) return;

      // Try to recognize the first face
      final people = ref.read(peopleProvider).valueOrNull ?? [];
      if (people.isEmpty || !FaceRecognitionService.instance.isModelLoaded) return;

      final embedding = await FaceRecognitionService.instance.generateEmbedding(
        image, faces.first.boundingBox, sensorRotation: sensorOrientation,
      );
      if (embedding != null) {
        final match = FaceRecognitionService.instance.findBestMatch(embedding, people);
        if (match != null) {
          ref.read(recognitionProvider.notifier).onPersonRecognized(match);
        }
      }
    } finally {
      _isProcessing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final camState = ref.watch(cameraProvider);
    final recState = ref.watch(recognitionProvider);

    // Start stream once camera is ready
    ref.listen(cameraProvider, (_, next) {
      if (next.isInitialized && next.controller != null) {
        _startStream(next.controller!);
      }
    });

    if (!camState.hasPermission) return _PermissionDenied();
    if (camState.error != null && !camState.isInitialized) return _ErrorView(message: camState.error!);
    if (!camState.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: AppColors.orange)),
      );
    }

    final controller = camState.controller!;
    final isFront = controller.description.lensDirection == CameraLensDirection.front;
    final imageSize = Size(
      controller.value.previewSize!.height,
      controller.value.previewSize!.width,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview
          CameraPreview(controller),
          // Face overlay
          CustomPaint(
            painter: FaceOverlayPainter(
              faces: _faces,
              imageSize: imageSize,
              isFrontCamera: isFront,
              recognizedName: recState.person?.name,
            ),
          ),
          // Recognition badge — sits above the bottom controls
          if (recState.person != null)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 72,
              left: 0, right: 0,
              child: RecognitionBadgeSheet(person: recState.person!),
            ),
          // Top bar: label only
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            child: Text('AURA FARM', style: AppTextStyles.orangeLabel),
          ),
          // Recognised name — large, centered, easy to read while debugging
          if (recState.person != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 48,
              left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    recState.person!.name,
                    style: AppTextStyles.displayMedium.copyWith(
                      color: AppColors.orange,
                      fontSize: 32,
                    ),
                  ),
                ),
              ),
            ),
          // Bottom controls: stop (left) + flip camera (right)
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 16,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Stop button — only visible while a snippet is active
                if (recState.person != null)
                  _CamButton(
                    icon: Icons.stop_rounded,
                    onTap: () => ref.read(recognitionProvider.notifier).stop(),
                  )
                else
                  const SizedBox(width: 48),
                // Flip camera button
                if (camState.canSwitch)
                  _CamButton(
                    icon: Icons.flip_camera_ios,
                    onTap: () => ref.read(cameraProvider.notifier).switchCamera(),
                  )
                else
                  const SizedBox(width: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CamButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CamButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}

class _PermissionDenied extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography_outlined, color: AppColors.grayLight, size: 64),
              const SizedBox(height: 20),
              Text('Camera access required', style: AppTextStyles.titleMedium),
              const SizedBox(height: 8),
              Text(
                'Grant camera permission in Settings to use Aura Farm.',
                style: AppTextStyles.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 48),
              const SizedBox(height: 16),
              Text('Camera error', style: AppTextStyles.titleMedium),
              const SizedBox(height: 8),
              Text(message, style: AppTextStyles.bodySmall, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
