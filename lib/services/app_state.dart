// Copyright (c) 2025-2026 Mihai Moraru. MIT License. See LICENSE file.

import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'camera_service.dart';
import 'vlm_service.dart';

/// Camera mode enum
enum CameraMode {
  continuous,
  singleFrame,
}

/// App state for the home screen
class AppState {
  final CameraMode cameraMode;
  final Uint8List? capturedImageBytes;
  final String prompt;
  final String promptSuffix;
  final bool isInitialized;

  const AppState({
    this.cameraMode = CameraMode.continuous,
    this.capturedImageBytes,
    this.prompt =
        'If this is a shipping container image, analyze it for any damages.',
    this.promptSuffix =
        'Output should be displayed in a list. output should be brief, 3 words or less per damage.',
    this.isInitialized = false,
  });

  AppState copyWith({
    CameraMode? cameraMode,
    Uint8List? capturedImageBytes,
    String? prompt,
    String? promptSuffix,
    bool? isInitialized,
    bool clearCapturedImage = false,
  }) {
    return AppState(
      cameraMode: cameraMode ?? this.cameraMode,
      capturedImageBytes: clearCapturedImage
          ? null
          : (capturedImageBytes ?? this.capturedImageBytes),
      prompt: prompt ?? this.prompt,
      promptSuffix: promptSuffix ?? this.promptSuffix,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }

  String get fullPrompt => '$prompt $promptSuffix';
}

/// App state notifier - Riverpod 3.x Notifier API
class AppStateNotifier extends Notifier<AppState> {
  @override
  AppState build() => const AppState();

  void setCameraMode(CameraMode mode) {
    state = state.copyWith(cameraMode: mode, clearCapturedImage: true);
  }

  void setCapturedImage(Uint8List? bytes) {
    state = state.copyWith(capturedImageBytes: bytes);
  }

  void clearCapturedImage() {
    state = state.copyWith(clearCapturedImage: true);
  }

  void setPrompt(String prompt, String suffix) {
    state = state.copyWith(prompt: prompt, promptSuffix: suffix);
  }

  void setInitialized(bool initialized) {
    state = state.copyWith(isInitialized: initialized);
  }
}

/// Provider for app state
final appStateProvider =
    NotifierProvider<AppStateNotifier, AppState>(AppStateNotifier.new);

/// Combined provider for checking if app is ready (camera + model loaded)
final isAppReadyProvider = Provider<bool>((ref) {
  final cameraState = ref.watch(cameraServiceProvider);
  final vlmState = ref.watch(vlmServiceProvider);
  return cameraState.isInitialized && vlmState.isModelLoaded;
});

/// Provider for combined errors (from camera or VLM)
final combinedErrorProvider = Provider<AppError?>((ref) {
  final cameraState = ref.watch(cameraServiceProvider);
  final vlmState = ref.watch(vlmServiceProvider);

  if (cameraState.error != null) {
    return AppError(
      source: ErrorSource.camera,
      title: _getCameraErrorTitle(cameraState.error!.type),
      message: cameraState.error!.message,
      canRetry: _canRetryCameraError(cameraState.error!.type),
    );
  }

  if (vlmState.error != null) {
    return AppError(
      source: ErrorSource.vlm,
      title: _getVLMErrorTitle(vlmState.error!.type),
      message: vlmState.error!.message,
      canRetry: _canRetryVLMError(vlmState.error!.type),
    );
  }

  return null;
});

/// App error wrapper
class AppError {
  final ErrorSource source;
  final String title;
  final String message;
  final bool canRetry;

  const AppError({
    required this.source,
    required this.title,
    required this.message,
    required this.canRetry,
  });
}

enum ErrorSource {
  camera,
  vlm,
}

String _getCameraErrorTitle(CameraErrorType type) {
  switch (type) {
    case CameraErrorType.permissionDenied:
      return 'Camera Permission Denied';
    case CameraErrorType.initializationFailed:
      return 'Camera Initialization Failed';
    case CameraErrorType.switchFailed:
      return 'Camera Switch Failed';
    case CameraErrorType.captureFailed:
      return 'Image Capture Failed';
    case CameraErrorType.streamFailed:
      return 'Camera Stream Failed';
  }
}

bool _canRetryCameraError(CameraErrorType type) {
  switch (type) {
    case CameraErrorType.permissionDenied:
      return false; // Need to go to settings
    case CameraErrorType.initializationFailed:
    case CameraErrorType.switchFailed:
    case CameraErrorType.captureFailed:
    case CameraErrorType.streamFailed:
      return true;
  }
}

String _getVLMErrorTitle(VLMErrorType type) {
  switch (type) {
    case VLMErrorType.loadFailed:
      return 'Model Loading Failed';
    case VLMErrorType.processingFailed:
      return 'Image Processing Failed';
    case VLMErrorType.cancelled:
      return 'Processing Cancelled';
  }
}

bool _canRetryVLMError(VLMErrorType type) {
  switch (type) {
    case VLMErrorType.loadFailed:
    case VLMErrorType.processingFailed:
      return true;
    case VLMErrorType.cancelled:
      return false;
  }
}
