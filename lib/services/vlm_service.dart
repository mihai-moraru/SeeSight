// Copyright (c) 2025-2026 Mihai Moraru. MIT License. See LICENSE file.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// VLM Service state
class VLMState {
  final bool isModelLoaded;
  final bool isProcessing;
  final EvaluationState evaluationState;
  final String response;
  final String ttft;
  final VLMError? error;

  const VLMState({
    this.isModelLoaded = false,
    this.isProcessing = false,
    this.evaluationState = EvaluationState.idle,
    this.response = '',
    this.ttft = '',
    this.error,
  });

  VLMState copyWith({
    bool? isModelLoaded,
    bool? isProcessing,
    EvaluationState? evaluationState,
    String? response,
    String? ttft,
    VLMError? error,
    bool clearError = false,
  }) {
    return VLMState(
      isModelLoaded: isModelLoaded ?? this.isModelLoaded,
      isProcessing: isProcessing ?? this.isProcessing,
      evaluationState: evaluationState ?? this.evaluationState,
      response: response ?? this.response,
      ttft: ttft ?? this.ttft,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// VLM Error types
class VLMError {
  final VLMErrorType type;
  final String message;
  final Object? originalError;

  const VLMError({
    required this.type,
    required this.message,
    this.originalError,
  });
}

enum VLMErrorType {
  loadFailed,
  processingFailed,
  cancelled,
}

/// Service for communicating with the native FastVLM implementation
/// Riverpod 3.x Notifier API
class FastVLMService extends Notifier<VLMState> {
  static const MethodChannel _channel = MethodChannel('com.fastvlm/vlm');
  static const EventChannel _eventChannel =
      EventChannel('com.fastvlm/vlm_stream');

  StreamSubscription<dynamic>? _streamSubscription;

  @override
  VLMState build() => const VLMState();

  /// Load the FastVLM model
  Future<void> loadModel() async {
    try {
      state = state.copyWith(clearError: true);
      final result = await _channel.invokeMethod<bool>('loadModel');
      state = state.copyWith(isModelLoaded: result ?? false);
    } on PlatformException catch (e) {
      debugPrint('Failed to load model: ${e.message}');
      state = state.copyWith(
        error: VLMError(
          type: VLMErrorType.loadFailed,
          message: 'Failed to load model: ${e.message}',
          originalError: e,
        ),
      );
    }
  }

  /// Process an image from camera stream (BGRA8888 format) - non-streaming
  Future<VLMResult> processImage({
    required Uint8List imageData,
    required int width,
    required int height,
    required String prompt,
  }) async {
    state = state.copyWith(
      isProcessing: true,
      evaluationState: EvaluationState.processingPrompt,
      clearError: true,
    );

    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'processImage',
        {
          'imageData': imageData,
          'width': width,
          'height': height,
          'prompt': prompt,
        },
      );

      final vlmResult = VLMResult.fromMap(result);
      state = state.copyWith(
        response: vlmResult.response,
        ttft: vlmResult.ttft,
      );
      return vlmResult;
    } on PlatformException catch (e) {
      state = state.copyWith(
        error: VLMError(
          type: VLMErrorType.processingFailed,
          message: 'Failed to process image: ${e.message}',
          originalError: e,
        ),
      );
      rethrow;
    } catch (e) {
      state = state.copyWith(
        error: VLMError(
          type: VLMErrorType.processingFailed,
          message: 'Unexpected error processing image: $e',
          originalError: e,
        ),
      );
      rethrow;
    } finally {
      state = state.copyWith(
        isProcessing: false,
        evaluationState: EvaluationState.idle,
      );
    }
  }

  /// Process an image with streaming response
  Stream<StreamEvent> processImageStreaming({
    required Uint8List imageData,
    required int width,
    required int height,
    required String prompt,
  }) {
    final controller = StreamController<StreamEvent>.broadcast();

    state = state.copyWith(
      isProcessing: true,
      evaluationState: EvaluationState.processingPrompt,
      response: '',
      ttft: '',
      clearError: true,
    );

    _streamSubscription?.cancel();
    _streamSubscription = _eventChannel.receiveBroadcastStream().listen(
      (event) {
        if (event is Map) {
          final type = event['type'] as String?;
          switch (type) {
            case 'token':
              final text = event['text'] as String? ?? '';
              state = state.copyWith(response: text);
              controller.add(TokenEvent(
                text: text,
                tokenCount: event['tokenCount'] as int? ?? 0,
              ));
              break;
            case 'ttft':
              final ttft = event['ttft'] as String? ?? '';
              state = state.copyWith(ttft: ttft);
              controller.add(TTFTEvent(ttft: ttft));
              break;
            case 'state':
              final stateStr = event['state'] as String?;
              final evalState = _parseEvaluationState(stateStr);
              state = state.copyWith(evaluationState: evalState);
              controller.add(StateChangeEvent(state: evalState));
              break;
            case 'complete':
              state = state.copyWith(
                isProcessing: false,
                evaluationState: EvaluationState.idle,
              );
              controller.add(CompleteEvent(
                tokenCount: event['tokenCount'] as int? ?? 0,
              ));
              controller.close();
              break;
            case 'error':
              final message = event['message'] as String? ?? 'Unknown error';
              state = state.copyWith(
                isProcessing: false,
                evaluationState: EvaluationState.idle,
                error: VLMError(
                  type: VLMErrorType.processingFailed,
                  message: message,
                ),
              );
              controller.addError(FastVLMException(message));
              controller.close();
              break;
          }
        }
      },
      onError: (error) {
        state = state.copyWith(
          isProcessing: false,
          evaluationState: EvaluationState.idle,
          error: VLMError(
            type: VLMErrorType.processingFailed,
            message: error.toString(),
            originalError: error,
          ),
        );
        controller.addError(error);
        controller.close();
      },
    );

    // Start the streaming process
    _channel.invokeMethod<bool>(
      'processImageStreaming',
      {
        'imageData': imageData,
        'width': width,
        'height': height,
        'prompt': prompt,
      },
    ).catchError((error) {
      controller.addError(error);
      controller.close();
      return false;
    });

    return controller.stream;
  }

  /// Process an image from file (JPEG/PNG bytes) - non-streaming
  Future<VLMResult> processImageFromFile({
    required Uint8List imageBytes,
    required String prompt,
  }) async {
    state = state.copyWith(
      isProcessing: true,
      evaluationState: EvaluationState.processingPrompt,
      clearError: true,
    );

    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'processImageFile',
        {
          'imageBytes': imageBytes,
          'prompt': prompt,
        },
      );

      final vlmResult = VLMResult.fromMap(result);
      state = state.copyWith(
        response: vlmResult.response,
        ttft: vlmResult.ttft,
      );
      return vlmResult;
    } on PlatformException catch (e) {
      state = state.copyWith(
        error: VLMError(
          type: VLMErrorType.processingFailed,
          message: 'Failed to process image: ${e.message}',
          originalError: e,
        ),
      );
      rethrow;
    } catch (e) {
      state = state.copyWith(
        error: VLMError(
          type: VLMErrorType.processingFailed,
          message: 'Unexpected error processing image: $e',
          originalError: e,
        ),
      );
      rethrow;
    } finally {
      state = state.copyWith(
        isProcessing: false,
        evaluationState: EvaluationState.idle,
      );
    }
  }

  /// Process an image from file with streaming response
  Stream<StreamEvent> processImageFromFileStreaming({
    required Uint8List imageBytes,
    required String prompt,
  }) {
    final controller = StreamController<StreamEvent>.broadcast();

    state = state.copyWith(
      isProcessing: true,
      evaluationState: EvaluationState.processingPrompt,
      response: '',
      ttft: '',
      clearError: true,
    );

    _streamSubscription?.cancel();
    _streamSubscription = _eventChannel.receiveBroadcastStream().listen(
      (event) {
        if (event is Map) {
          final type = event['type'] as String?;
          switch (type) {
            case 'token':
              final text = event['text'] as String? ?? '';
              state = state.copyWith(response: text);
              controller.add(TokenEvent(
                text: text,
                tokenCount: event['tokenCount'] as int? ?? 0,
              ));
              break;
            case 'ttft':
              final ttft = event['ttft'] as String? ?? '';
              state = state.copyWith(ttft: ttft);
              controller.add(TTFTEvent(ttft: ttft));
              break;
            case 'state':
              final stateStr = event['state'] as String?;
              final evalState = _parseEvaluationState(stateStr);
              state = state.copyWith(evaluationState: evalState);
              controller.add(StateChangeEvent(state: evalState));
              break;
            case 'complete':
              state = state.copyWith(
                isProcessing: false,
                evaluationState: EvaluationState.idle,
              );
              controller.add(CompleteEvent(
                tokenCount: event['tokenCount'] as int? ?? 0,
              ));
              controller.close();
              break;
            case 'error':
              final message = event['message'] as String? ?? 'Unknown error';
              state = state.copyWith(
                isProcessing: false,
                evaluationState: EvaluationState.idle,
                error: VLMError(
                  type: VLMErrorType.processingFailed,
                  message: message,
                ),
              );
              controller.addError(FastVLMException(message));
              controller.close();
              break;
          }
        }
      },
      onError: (error) {
        state = state.copyWith(
          isProcessing: false,
          evaluationState: EvaluationState.idle,
          error: VLMError(
            type: VLMErrorType.processingFailed,
            message: error.toString(),
            originalError: error,
          ),
        );
        controller.addError(error);
        controller.close();
      },
    );

    // Start the streaming process
    _channel.invokeMethod<bool>(
      'processImageFile',
      {
        'imageBytes': imageBytes,
        'prompt': prompt,
        'streaming': true,
      },
    ).catchError((error) {
      controller.addError(error);
      controller.close();
      return false;
    });

    return controller.stream;
  }

  EvaluationState _parseEvaluationState(String? state) {
    switch (state) {
      case 'processingPrompt':
        return EvaluationState.processingPrompt;
      case 'generatingResponse':
        return EvaluationState.generatingResponse;
      default:
        return EvaluationState.idle;
    }
  }

  /// Cancel any ongoing generation
  Future<void> cancel() async {
    try {
      await _channel.invokeMethod<void>('cancel');
      state = state.copyWith(
        isProcessing: false,
        evaluationState: EvaluationState.idle,
      );
    } on PlatformException catch (e) {
      debugPrint('Failed to cancel: ${e.message}');
    }
    _streamSubscription?.cancel();
    _streamSubscription = null;
  }

  /// Get model information
  Future<String> getModelInfo() async {
    try {
      final result = await _channel.invokeMethod<String>('getModelInfo');
      return result ?? 'Unknown';
    } on PlatformException catch (e) {
      debugPrint('Failed to get model info: ${e.message}');
      return 'Error: ${e.message}';
    }
  }

  /// Clear current error
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Clear response
  void clearResponse() {
    state = state.copyWith(response: '', ttft: '');
  }

  /// Dispose VLM resources
  void disposeVLM() {
    cancel();
  }
}

/// Result from VLM inference
class VLMResult {
  final String response;
  final String ttft;
  final int tokenCount;

  VLMResult({
    required this.response,
    required this.ttft,
    required this.tokenCount,
  });

  factory VLMResult.fromMap(Map<Object?, Object?>? map) {
    if (map == null) {
      return VLMResult(response: '', ttft: '', tokenCount: 0);
    }

    return VLMResult(
      response: map['response'] as String? ?? '',
      ttft: map['ttft'] as String? ?? '',
      tokenCount: map['tokenCount'] as int? ?? 0,
    );
  }
}

/// Exception class for FastVLM errors
class FastVLMException implements Exception {
  final String message;

  FastVLMException(this.message);

  @override
  String toString() => 'FastVLMException: $message';
}

/// Evaluation state enum matching native implementation
enum EvaluationState {
  idle,
  processingPrompt,
  generatingResponse,
}

/// Stream events for streaming response
abstract class StreamEvent {}

class TokenEvent extends StreamEvent {
  final String text;
  final int tokenCount;

  TokenEvent({required this.text, required this.tokenCount});
}

class TTFTEvent extends StreamEvent {
  final String ttft;

  TTFTEvent({required this.ttft});
}

class StateChangeEvent extends StreamEvent {
  final EvaluationState state;

  StateChangeEvent({required this.state});
}

class CompleteEvent extends StreamEvent {
  final int tokenCount;

  CompleteEvent({required this.tokenCount});
}

/// Provider for VLM service
final vlmServiceProvider =
    NotifierProvider<FastVLMService, VLMState>(FastVLMService.new);
