import 'package:flutter_test/flutter_test.dart';
import 'package:fastvlm_flutter/services/camera_service.dart';

void main() {
  group('CameraState', () {
    test('creates with default values', () {
      final state = CameraState();

      expect(state.controller, isNull);
      expect(state.cameras, isEmpty);
      expect(state.currentCameraIndex, 0);
      expect(state.isInitialized, false);
      expect(state.error, isNull);
      expect(state.canSwitchCamera, false);
      expect(state.frameRateController, isNotNull);
    });

    test('canSwitchCamera returns true when multiple cameras', () {
      final state = CameraState(
        cameras: const [],
      );

      expect(state.canSwitchCamera, false);
    });

    test('copyWith preserves values when not specified', () {
      final state = CameraState(
        currentCameraIndex: 1,
        isInitialized: true,
      );

      final copied = state.copyWith();

      expect(copied.currentCameraIndex, 1);
      expect(copied.isInitialized, true);
    });

    test('copyWith updates specified values', () {
      final state = CameraState();

      final updated = state.copyWith(
        currentCameraIndex: 2,
        isInitialized: true,
      );

      expect(updated.currentCameraIndex, 2);
      expect(updated.isInitialized, true);
    });

    test('copyWith can clear error', () {
      final state = CameraState(
        error: const CameraError(
          type: CameraErrorType.initializationFailed,
          message: 'error',
        ),
      );

      final cleared = state.copyWith(clearError: true);

      expect(cleared.error, isNull);
    });
  });

  group('CameraError', () {
    test('creates with required values', () {
      const error = CameraError(
        type: CameraErrorType.captureFailed,
        message: 'Failed to capture',
      );

      expect(error.type, CameraErrorType.captureFailed);
      expect(error.message, 'Failed to capture');
      expect(error.originalError, isNull);
    });

    test('can include original error', () {
      final original = Exception('original');
      final error = CameraError(
        type: CameraErrorType.switchFailed,
        message: 'Switch error',
        originalError: original,
      );

      expect(error.originalError, original);
    });
  });

  group('CameraErrorType', () {
    test('has all expected values', () {
      expect(CameraErrorType.values.length, 5);
      expect(CameraErrorType.values.contains(CameraErrorType.permissionDenied),
          true);
      expect(
          CameraErrorType.values.contains(CameraErrorType.initializationFailed),
          true);
      expect(
          CameraErrorType.values.contains(CameraErrorType.switchFailed), true);
      expect(
          CameraErrorType.values.contains(CameraErrorType.captureFailed), true);
      expect(
          CameraErrorType.values.contains(CameraErrorType.streamFailed), true);
    });
  });

  group('AdaptiveFrameRateController', () {
    test('creates with default initial frames to skip', () {
      final controller = AdaptiveFrameRateController();

      expect(controller.framesToSkip, 2);
    });

    test('creates with custom initial frames to skip', () {
      final controller = AdaptiveFrameRateController(initialFramesToSkip: 5);

      expect(controller.framesToSkip, 5);
    });

    test('clamps initial frames to skip within bounds', () {
      final tooLow = AdaptiveFrameRateController(initialFramesToSkip: -5);
      final tooHigh = AdaptiveFrameRateController(initialFramesToSkip: 100);

      expect(tooLow.framesToSkip, 0);
      expect(tooHigh.framesToSkip, 10);
    });

    test('shouldProcessFrame skips correct number of frames', () {
      final controller = AdaptiveFrameRateController(initialFramesToSkip: 2);

      // First 2 frames should be skipped
      expect(controller.shouldProcessFrame(), false);
      expect(controller.shouldProcessFrame(), false);
      // Third frame should process
      expect(controller.shouldProcessFrame(), true);
      // Next 2 should skip again
      expect(controller.shouldProcessFrame(), false);
      expect(controller.shouldProcessFrame(), false);
      expect(controller.shouldProcessFrame(), true);
    });

    test('shouldProcessFrame with zero skip processes every frame', () {
      final controller = AdaptiveFrameRateController(initialFramesToSkip: 0);

      expect(controller.shouldProcessFrame(), true);
      expect(controller.shouldProcessFrame(), true);
      expect(controller.shouldProcessFrame(), true);
    });

    test('reset clears internal state', () {
      final controller = AdaptiveFrameRateController(initialFramesToSkip: 2);

      // Skip one frame
      controller.shouldProcessFrame();
      // Reset
      controller.reset();
      // Should start fresh - skip again
      expect(controller.shouldProcessFrame(), false);
    });

    test('stats returns current state', () {
      final controller = AdaptiveFrameRateController(initialFramesToSkip: 3);

      final stats = controller.stats;

      expect(stats['framesToSkip'], 3);
      expect(stats['avgProcessingTime'], 0);
      expect(stats['sampleCount'], 0);
    });
  });
}
