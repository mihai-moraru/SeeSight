import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fastvlm_flutter/services/app_state.dart';

void main() {
  group('AppState', () {
    test('creates with default values', () {
      const state = AppState();

      expect(state.cameraMode, CameraMode.continuous);
      expect(state.capturedImageBytes, isNull);
      expect(state.prompt.isNotEmpty, true);
      expect(state.promptSuffix.isNotEmpty, true);
      expect(state.isInitialized, false);
    });

    test('fullPrompt combines prompt and suffix', () {
      const state = AppState(
        prompt: 'Hello',
        promptSuffix: 'World',
      );

      expect(state.fullPrompt, 'Hello World');
    });

    test('copyWith preserves values when not specified', () {
      const state = AppState(
        cameraMode: CameraMode.singleFrame,
        prompt: 'test',
        isInitialized: true,
      );

      final copied = state.copyWith();

      expect(copied.cameraMode, CameraMode.singleFrame);
      expect(copied.prompt, 'test');
      expect(copied.isInitialized, true);
    });

    test('copyWith updates specified values', () {
      const state = AppState();

      final updated = state.copyWith(
        cameraMode: CameraMode.singleFrame,
        prompt: 'new prompt',
      );

      expect(updated.cameraMode, CameraMode.singleFrame);
      expect(updated.prompt, 'new prompt');
    });

    test('copyWith can clear captured image', () {
      final state = AppState(
        capturedImageBytes: Uint8List.fromList([1, 2, 3]),
      );

      final cleared = state.copyWith(clearCapturedImage: true);

      expect(cleared.capturedImageBytes, isNull);
    });
  });

  group('AppStateNotifier with ProviderContainer', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('sets camera mode', () {
      container
          .read(appStateProvider.notifier)
          .setCameraMode(CameraMode.singleFrame);

      expect(
          container.read(appStateProvider).cameraMode, CameraMode.singleFrame);
    });

    test('sets camera mode clears captured image', () {
      container
          .read(appStateProvider.notifier)
          .setCapturedImage(Uint8List.fromList([1, 2, 3]));
      container
          .read(appStateProvider.notifier)
          .setCameraMode(CameraMode.continuous);

      expect(container.read(appStateProvider).capturedImageBytes, isNull);
    });

    test('sets captured image', () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      container.read(appStateProvider.notifier).setCapturedImage(bytes);

      expect(container.read(appStateProvider).capturedImageBytes, bytes);
    });

    test('clears captured image', () {
      container
          .read(appStateProvider.notifier)
          .setCapturedImage(Uint8List.fromList([1, 2, 3]));
      container.read(appStateProvider.notifier).clearCapturedImage();

      expect(container.read(appStateProvider).capturedImageBytes, isNull);
    });

    test('sets prompt and suffix', () {
      container
          .read(appStateProvider.notifier)
          .setPrompt('new prompt', 'new suffix');

      expect(container.read(appStateProvider).prompt, 'new prompt');
      expect(container.read(appStateProvider).promptSuffix, 'new suffix');
    });

    test('sets initialized', () {
      container.read(appStateProvider.notifier).setInitialized(true);

      expect(container.read(appStateProvider).isInitialized, true);
    });
  });

  group('CameraMode', () {
    test('has expected values', () {
      expect(CameraMode.values.length, 2);
      expect(CameraMode.values.contains(CameraMode.continuous), true);
      expect(CameraMode.values.contains(CameraMode.singleFrame), true);
    });
  });

  group('AppError', () {
    test('creates with required values', () {
      const error = AppError(
        source: ErrorSource.camera,
        title: 'Test Error',
        message: 'Test message',
        canRetry: true,
      );

      expect(error.source, ErrorSource.camera);
      expect(error.title, 'Test Error');
      expect(error.message, 'Test message');
      expect(error.canRetry, true);
    });
  });

  group('ErrorSource', () {
    test('has expected values', () {
      expect(ErrorSource.values.length, 2);
      expect(ErrorSource.values.contains(ErrorSource.camera), true);
      expect(ErrorSource.values.contains(ErrorSource.vlm), true);
    });
  });
}
