import 'package:flutter_test/flutter_test.dart';
import 'package:fastvlm_flutter/services/vlm_service.dart';

void main() {
  group('VLMState', () {
    test('creates with default values', () {
      const state = VLMState();

      expect(state.isModelLoaded, false);
      expect(state.isProcessing, false);
      expect(state.evaluationState, EvaluationState.idle);
      expect(state.response, '');
      expect(state.ttft, '');
      expect(state.error, isNull);
    });

    test('copyWith preserves values when not specified', () {
      const state = VLMState(
        isModelLoaded: true,
        isProcessing: true,
        response: 'test',
      );

      final copied = state.copyWith();

      expect(copied.isModelLoaded, true);
      expect(copied.isProcessing, true);
      expect(copied.response, 'test');
    });

    test('copyWith updates specified values', () {
      const state = VLMState();

      final updated = state.copyWith(
        isModelLoaded: true,
        response: 'response',
      );

      expect(updated.isModelLoaded, true);
      expect(updated.response, 'response');
      expect(updated.isProcessing, false);
    });

    test('copyWith can clear error', () {
      const state = VLMState(
        error: VLMError(
          type: VLMErrorType.loadFailed,
          message: 'error',
        ),
      );

      final cleared = state.copyWith(clearError: true);

      expect(cleared.error, isNull);
    });
  });

  group('VLMError', () {
    test('creates with required values', () {
      const error = VLMError(
        type: VLMErrorType.loadFailed,
        message: 'Failed to load',
      );

      expect(error.type, VLMErrorType.loadFailed);
      expect(error.message, 'Failed to load');
      expect(error.originalError, isNull);
    });

    test('can include original error', () {
      final original = Exception('original');
      final error = VLMError(
        type: VLMErrorType.processingFailed,
        message: 'Processing error',
        originalError: original,
      );

      expect(error.originalError, original);
    });
  });

  group('VLMResult', () {
    test('creates from map', () {
      final result = VLMResult.fromMap({
        'response': 'test response',
        'ttft': '100ms',
        'tokenCount': 5,
      });

      expect(result.response, 'test response');
      expect(result.ttft, '100ms');
      expect(result.tokenCount, 5);
    });

    test('handles null map', () {
      final result = VLMResult.fromMap(null);

      expect(result.response, '');
      expect(result.ttft, '');
      expect(result.tokenCount, 0);
    });

    test('handles partial map', () {
      final result = VLMResult.fromMap({
        'response': 'partial',
      });

      expect(result.response, 'partial');
      expect(result.ttft, '');
      expect(result.tokenCount, 0);
    });
  });

  group('FastVLMException', () {
    test('creates with message', () {
      final exception = FastVLMException('test error');

      expect(exception.message, 'test error');
      expect(exception.toString(), 'FastVLMException: test error');
    });
  });

  group('StreamEvent types', () {
    test('TokenEvent holds text and count', () {
      final event = TokenEvent(text: 'hello', tokenCount: 1);

      expect(event.text, 'hello');
      expect(event.tokenCount, 1);
    });

    test('TTFTEvent holds ttft', () {
      final event = TTFTEvent(ttft: '100ms');

      expect(event.ttft, '100ms');
    });

    test('StateChangeEvent holds state', () {
      final event = StateChangeEvent(state: EvaluationState.processingPrompt);

      expect(event.state, EvaluationState.processingPrompt);
    });

    test('CompleteEvent holds token count', () {
      final event = CompleteEvent(tokenCount: 10);

      expect(event.tokenCount, 10);
    });
  });

  group('EvaluationState', () {
    test('has all expected values', () {
      expect(EvaluationState.values.length, 3);
      expect(EvaluationState.values.contains(EvaluationState.idle), true);
      expect(EvaluationState.values.contains(EvaluationState.processingPrompt),
          true);
      expect(
          EvaluationState.values.contains(EvaluationState.generatingResponse),
          true);
    });
  });
}
