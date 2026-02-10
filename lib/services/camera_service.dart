// Copyright (c) 2025-2026 Mihai Moraru. MIT License. See LICENSE file.

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Adaptive frame rate controller that adjusts frame skipping based on processing performance
class AdaptiveFrameRateController {
  /// Configuration
  static const int _minFramesToSkip = 0;
  static const int _maxFramesToSkip = 10;
  static const int _targetProcessingTimeMs =
      200; // Target processing time in ms
  static const int _historySize = 5; // Number of samples to average
  static const double _adjustmentFactor = 0.5; // How aggressively to adjust

  int _framesToSkip;
  int _frameCounter = 0;
  final List<int> _processingTimeHistory = [];
  DateTime? _lastFrameTime;

  AdaptiveFrameRateController({int initialFramesToSkip = 2})
      : _framesToSkip =
            initialFramesToSkip.clamp(_minFramesToSkip, _maxFramesToSkip);

  /// Current frames to skip setting
  int get framesToSkip => _framesToSkip;

  /// Check if this frame should be processed
  bool shouldProcessFrame() {
    _frameCounter++;
    if (_frameCounter <= _framesToSkip) {
      return false;
    }
    _frameCounter = 0;
    _lastFrameTime = DateTime.now();
    return true;
  }

  /// Report that processing has completed - call this after VLM processing finishes
  void reportProcessingComplete() {
    if (_lastFrameTime == null) return;

    final processingTime =
        DateTime.now().difference(_lastFrameTime!).inMilliseconds;
    _updateFrameRate(processingTime);
    _lastFrameTime = null;
  }

  /// Update frame rate based on processing time
  void _updateFrameRate(int processingTimeMs) {
    // Add to history
    _processingTimeHistory.add(processingTimeMs);
    if (_processingTimeHistory.length > _historySize) {
      _processingTimeHistory.removeAt(0);
    }

    // Calculate average processing time
    final avgProcessingTime = _processingTimeHistory.reduce((a, b) => a + b) /
        _processingTimeHistory.length;

    // Adjust frames to skip based on performance
    if (avgProcessingTime > _targetProcessingTimeMs * 1.5) {
      // Processing is too slow, skip more frames
      final increase = ((avgProcessingTime - _targetProcessingTimeMs) /
              _targetProcessingTimeMs *
              _adjustmentFactor)
          .ceil();
      _framesToSkip =
          (_framesToSkip + increase).clamp(_minFramesToSkip, _maxFramesToSkip);
    } else if (avgProcessingTime < _targetProcessingTimeMs * 0.7 &&
        _processingTimeHistory.length >= _historySize) {
      // Processing is fast enough, try skipping fewer frames
      _framesToSkip =
          (_framesToSkip - 1).clamp(_minFramesToSkip, _maxFramesToSkip);
    }
  }

  /// Reset the controller state
  void reset() {
    _frameCounter = 0;
    _processingTimeHistory.clear();
    _lastFrameTime = null;
  }

  /// Get current performance stats for debugging
  Map<String, dynamic> get stats => {
        'framesToSkip': _framesToSkip,
        'avgProcessingTime': _processingTimeHistory.isEmpty
            ? 0
            : _processingTimeHistory.reduce((a, b) => a + b) /
                _processingTimeHistory.length,
        'sampleCount': _processingTimeHistory.length,
      };
}

/// Camera service state
class CameraState {
  final CameraController? controller;
  final List<CameraDescription> cameras;
  final int currentCameraIndex;
  final bool isInitialized;
  final CameraError? error;
  final AdaptiveFrameRateController frameRateController;

  CameraState({
    this.controller,
    this.cameras = const [],
    this.currentCameraIndex = 0,
    this.isInitialized = false,
    this.error,
    AdaptiveFrameRateController? frameRateController,
  }) : frameRateController =
            frameRateController ?? AdaptiveFrameRateController();

  CameraState copyWith({
    CameraController? controller,
    List<CameraDescription>? cameras,
    int? currentCameraIndex,
    bool? isInitialized,
    CameraError? error,
    bool clearError = false,
    AdaptiveFrameRateController? frameRateController,
  }) {
    return CameraState(
      controller: controller ?? this.controller,
      cameras: cameras ?? this.cameras,
      currentCameraIndex: currentCameraIndex ?? this.currentCameraIndex,
      isInitialized: isInitialized ?? this.isInitialized,
      error: clearError ? null : (error ?? this.error),
      frameRateController: frameRateController ?? this.frameRateController,
    );
  }

  bool get canSwitchCamera => cameras.length > 1;
}

/// Camera error types
class CameraError {
  final CameraErrorType type;
  final String message;
  final Object? originalError;

  const CameraError({
    required this.type,
    required this.message,
    this.originalError,
  });
}

enum CameraErrorType {
  permissionDenied,
  initializationFailed,
  switchFailed,
  captureFailed,
  streamFailed,
}

/// Camera service notifier - Riverpod 3.x Notifier API
class CameraService extends Notifier<CameraState> {
  @override
  CameraState build() => CameraState();

  /// Initialize camera with the preferred lens direction
  Future<void> initialize({
    CameraLensDirection preferredDirection = CameraLensDirection.front,
  }) async {
    try {
      final allCameras = await availableCameras();

      if (allCameras.isEmpty) {
        state = state.copyWith(
          error: const CameraError(
            type: CameraErrorType.initializationFailed,
            message: 'No camera available',
          ),
        );
        return;
      }

      // Find preferred camera, fall back to first available
      var preferredIndex = allCameras.indexWhere(
        (camera) => camera.lensDirection == preferredDirection,
      );
      if (preferredIndex < 0) preferredIndex = 0;

      state = state.copyWith(
        cameras: allCameras,
        currentCameraIndex: preferredIndex,
      );
      await _initializeController(allCameras[preferredIndex]);
    } catch (e) {
      debugPrint('Error initializing camera: $e');
      state = state.copyWith(
        error: CameraError(
          type: CameraErrorType.initializationFailed,
          message: 'Failed to initialize camera',
          originalError: e,
        ),
      );
    }
  }

  Future<void> _initializeController(CameraDescription camera) async {
    // Dispose existing controller
    await state.controller?.dispose();

    final controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.bgra8888,
    );

    try {
      await controller.initialize();

      // Enable continuous autofocus and auto exposure
      await controller.setFocusMode(FocusMode.auto);
      await controller.setExposureMode(ExposureMode.auto);

      state = state.copyWith(
        controller: controller,
        isInitialized: true,
        clearError: true,
      );
    } catch (e) {
      debugPrint('Error initializing camera controller: $e');
      state = state.copyWith(
        isInitialized: false,
        error: CameraError(
          type: CameraErrorType.initializationFailed,
          message: 'Failed to initialize camera controller',
          originalError: e,
        ),
      );
    }
  }

  /// Switch to next available camera
  Future<void> switchCamera() async {
    if (!state.canSwitchCamera) return;

    try {
      // Stop stream if running
      await stopImageStream();

      state = state.copyWith(isInitialized: false);

      final nextIndex = (state.currentCameraIndex + 1) % state.cameras.length;
      state = state.copyWith(currentCameraIndex: nextIndex);

      await _initializeController(state.cameras[nextIndex]);
    } catch (e) {
      debugPrint('Error switching camera: $e');
      state = state.copyWith(
        error: CameraError(
          type: CameraErrorType.switchFailed,
          message: 'Failed to switch camera',
          originalError: e,
        ),
      );
    }
  }

  /// Start image stream for continuous capture
  void startImageStream(void Function(CameraImage) onImage) {
    final controller = state.controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isStreamingImages) return;

    try {
      controller.startImageStream(onImage);
    } catch (e) {
      debugPrint('Error starting image stream: $e');
      state = state.copyWith(
        error: CameraError(
          type: CameraErrorType.streamFailed,
          message: 'Failed to start camera stream',
          originalError: e,
        ),
      );
    }
  }

  /// Stop image stream
  Future<void> stopImageStream() async {
    final controller = state.controller;
    if (controller != null && controller.value.isStreamingImages) {
      try {
        await controller.stopImageStream();
      } catch (e) {
        debugPrint('Error stopping image stream: $e');
      }
    }
  }

  /// Capture a single image
  Future<Uint8List?> captureImage() async {
    final controller = state.controller;
    if (controller == null || !controller.value.isInitialized) {
      return null;
    }

    try {
      final XFile imageFile = await controller.takePicture();
      return await imageFile.readAsBytes();
    } catch (e) {
      debugPrint('Error capturing image: $e');
      state = state.copyWith(
        error: CameraError(
          type: CameraErrorType.captureFailed,
          message: 'Failed to capture image',
          originalError: e,
        ),
      );
      return null;
    }
  }

  /// Clear current error
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Pause camera (for app lifecycle)
  Future<void> pause() async {
    await stopImageStream();
  }

  /// Resume camera
  Future<void> resume() async {
    if (state.controller != null && !state.isInitialized) {
      await _initializeController(state.cameras[state.currentCameraIndex]);
    }
  }

  /// Dispose camera resources
  void disposeCamera() {
    state.controller?.dispose();
  }
}

/// Provider for camera service
final cameraServiceProvider =
    NotifierProvider<CameraService, CameraState>(CameraService.new);
