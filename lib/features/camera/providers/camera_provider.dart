import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraState {
  final CameraController? controller;
  final List<CameraDescription> availableCams;
  final bool isInitialized;
  final bool hasPermission;
  final String? error;

  const CameraState({
    this.controller,
    this.availableCams = const [],
    this.isInitialized = false,
    this.hasPermission = true,
    this.error,
  });

  CameraState copyWith({
    CameraController? controller,
    List<CameraDescription>? availableCams,
    bool? isInitialized,
    bool? hasPermission,
    String? error,
  }) => CameraState(
    controller: controller ?? this.controller,
    availableCams: availableCams ?? this.availableCams,
    isInitialized: isInitialized ?? this.isInitialized,
    hasPermission: hasPermission ?? this.hasPermission,
    error: error,
  );

  bool get canSwitch => availableCams.length > 1;
}

class CameraNotifier extends StateNotifier<CameraState> {
  CameraNotifier() : super(const CameraState());

  Future<void> initialize() async {
    final status = await Permission.camera.request();
    if (status != PermissionStatus.granted) {
      state = state.copyWith(hasPermission: false, error: 'Camera permission denied');
      return;
    }
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        state = state.copyWith(error: 'No cameras available');
        return;
      }
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      await _initController(camera, cameras);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      debugPrint('Camera init error: $e');
    }
  }

  Future<void> switchCamera() async {
    if (!state.canSwitch || !state.isInitialized) return;
    final current = state.controller?.description;
    final next = state.availableCams.firstWhere(
      (c) => c.lensDirection != current?.lensDirection,
      orElse: () => state.availableCams.first,
    );
    try {
      final oldController = state.controller;
      // Signal switching (clears isInitialized so stream listener reacts)
      state = state.copyWith(isInitialized: false, controller: null);
      if (oldController != null) {
        if (oldController.value.isStreamingImages) await oldController.stopImageStream();
        await oldController.dispose();
      }
      await _initController(next, state.availableCams);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      debugPrint('Camera switch error: $e');
    }
  }

  Future<void> _initController(CameraDescription camera, List<CameraDescription> allCams) async {
    final controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    await controller.initialize();
    state = CameraState(
      controller: controller,
      availableCams: allCams,
      isInitialized: true,
      hasPermission: true,
    );
  }

  @override
  void dispose() {
    state.controller?.dispose();
    super.dispose();
  }
}

final cameraProvider = StateNotifierProvider.autoDispose<CameraNotifier, CameraState>(
  (_) => CameraNotifier(),
);
