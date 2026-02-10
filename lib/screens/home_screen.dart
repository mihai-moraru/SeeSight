// Copyright (c) 2025-2026 Mihai Moraru. MIT License. See LICENSE file.

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/app_state.dart';
import '../services/camera_service.dart';
import '../services/settings_service.dart';
import '../services/vlm_service.dart';
import '../widgets/camera_preview_widget.dart';
import '../widgets/error_dialog.dart';
import '../widgets/glass_container.dart';
import '../widgets/mode_toggle.dart';
import '../widgets/response_bottom_sheet.dart';
import 'settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  static const List<QuickPrompt> _quickPrompts = [
    QuickPrompt(
      label: 'Describe',
      prompt: 'Describe the image in English.',
      suffix: 'Output should be brief, about 15 words or less.',
    ),
    QuickPrompt(
      label: 'Count',
      prompt: 'Count objects in the image.',
      suffix: 'Output only the count.',
    ),
    QuickPrompt(
      label: 'Read Text',
      prompt: 'What is written in this image?',
      suffix: 'Output only the text in the image.',
    ),
    QuickPrompt(
      label: 'Colors',
      prompt: 'What colors are in this image?',
      suffix: 'Output a brief list of main colors.',
    ),
    QuickPrompt(
      label: 'Emotion',
      prompt: "What is this person's facial expression?",
      suffix: 'Output only one or two words.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Set status bar to light (white icons) for dark camera background
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    _initializeApp();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _handleAppBackground();
        break;
      case AppLifecycleState.resumed:
        _handleAppForeground();
        break;
      default:
        break;
    }
  }

  Future<void> _handleAppBackground() async {
    await ref.read(vlmServiceProvider.notifier).cancel();
    await ref.read(cameraServiceProvider.notifier).pause();
  }

  Future<void> _handleAppForeground() async {
    await ref.read(cameraServiceProvider.notifier).resume();
    final appState = ref.read(appStateProvider);
    if (appState.cameraMode == CameraMode.continuous) {
      _startContinuousCapture();
    }
  }

  Future<void> _initializeApp() async {
    await _requestPermissions();

    final settings = ref.read(settingsProvider);
    final preferredDirection = settings.defaultCamera == DefaultCamera.front
        ? CameraLensDirection.front
        : CameraLensDirection.back;
    await ref
        .read(cameraServiceProvider.notifier)
        .initialize(preferredDirection: preferredDirection);
    await ref.read(vlmServiceProvider.notifier).loadModel();

    final appState = ref.read(appStateProvider);
    if (appState.cameraMode == CameraMode.continuous) {
      _startContinuousCapture();
    }
  }

  Future<void> _requestPermissions() async {
    final status = await Permission.camera.request();
    if (status.isDenied && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Camera permission is required'),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _startContinuousCapture() {
    final cameraService = ref.read(cameraServiceProvider.notifier);
    cameraService.startImageStream(_onCameraImage);
  }

  void _stopContinuousCapture() {
    ref.read(cameraServiceProvider.notifier).stopImageStream();
  }

  void _onCameraImage(CameraImage image) {
    final cameraState = ref.read(cameraServiceProvider);
    if (!cameraState.frameRateController.shouldProcessFrame()) {
      return;
    }

    final vlmState = ref.read(vlmServiceProvider);
    final appState = ref.read(appStateProvider);

    if (vlmState.isProcessing ||
        !vlmState.isModelLoaded ||
        appState.cameraMode != CameraMode.continuous) {
      return;
    }

    _processImage(
      imageData: image.planes.first.bytes,
      width: image.width,
      height: image.height,
    );
  }

  Future<void> _processImage({
    required Uint8List imageData,
    required int width,
    required int height,
  }) async {
    final vlmService = ref.read(vlmServiceProvider.notifier);
    final appState = ref.read(appStateProvider);

    try {
      await vlmService.processImage(
        imageData: imageData,
        width: width,
        height: height,
        prompt: appState.fullPrompt,
      );
    } catch (e) {
      debugPrint('Error processing image: $e');
    } finally {
      ref
          .read(cameraServiceProvider)
          .frameRateController
          .reportProcessingComplete();
    }
  }

  Future<void> _captureAndProcess() async {
    HapticFeedback.mediumImpact();
    final vlmState = ref.read(vlmServiceProvider);
    if (vlmState.isProcessing || !vlmState.isModelLoaded) return;

    final bytes = await ref.read(cameraServiceProvider.notifier).captureImage();
    if (bytes == null) return;

    ref.read(appStateProvider.notifier).setCapturedImage(bytes);

    final vlmService = ref.read(vlmServiceProvider.notifier);
    final appState = ref.read(appStateProvider);

    try {
      await vlmService.processImageFromFile(
        imageBytes: bytes,
        prompt: appState.fullPrompt,
      );
    } catch (e) {
      debugPrint('Error processing captured image: $e');
    }
  }

  void _clearCapturedImage() {
    HapticFeedback.lightImpact();
    ref.read(appStateProvider.notifier).clearCapturedImage();
    ref.read(vlmServiceProvider.notifier).clearResponse();
  }

  Future<void> _onCameraModeChanged(CameraMode mode) async {
    final currentMode = ref.read(appStateProvider).cameraMode;
    if (currentMode == mode) return;

    ref.read(appStateProvider.notifier).setCameraMode(mode);
    await ref.read(vlmServiceProvider.notifier).cancel();
    ref.read(vlmServiceProvider.notifier).clearResponse();

    if (mode == CameraMode.continuous) {
      _startContinuousCapture();
    } else {
      _stopContinuousCapture();
    }
  }

  void _onPromptChanged(String prompt, String suffix) {
    ref.read(appStateProvider.notifier).setPrompt(prompt, suffix);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cameraState = ref.watch(cameraServiceProvider);
    final vlmState = ref.watch(vlmServiceProvider);
    final appState = ref.watch(appStateProvider);
    final mediaQuery = MediaQuery.of(context);

    return AppErrorListener(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Layer 1: Full-screen camera preview
            _buildCameraLayer(cameraState, appState),

            // Layer 2: Top overlays (safe area aware)
            Positioned(
              top: mediaQuery.padding.top + 12,
              left: 16,
              right: 16,
              child: _buildTopOverlays(vlmState, appState, cameraState),
            ),

            // Layer 3: Bottom sheet with status indicator + capture button
            ResponseBottomSheet(
              prompt: appState.prompt,
              promptSuffix: appState.promptSuffix,
              response: vlmState.response,
              isLoading: vlmState.isProcessing && vlmState.response.isEmpty,
              isModelLoaded: vlmState.isModelLoaded,
              onPromptChanged: _onPromptChanged,
              quickPrompts: _quickPrompts,
              evaluationState: vlmState.evaluationState,
              floatingWidget: appState.cameraMode == CameraMode.singleFrame
                  ? _buildCaptureButton(appState, vlmState)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraLayer(CameraState cameraState, AppState appState) {
    // Show captured image in single frame mode
    if (appState.cameraMode == CameraMode.singleFrame &&
        appState.capturedImageBytes != null) {
      return Image.memory(
        appState.capturedImageBytes!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }

    return CameraPreviewWidget(
      controller: cameraState.controller,
      isCameraInitialized: cameraState.isInitialized,
    );
  }

  Widget _buildTopOverlays(
      VLMState vlmState, AppState appState, CameraState cameraState) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mode toggle
            ModeToggle(
              selectedMode: appState.cameraMode,
              onModeChanged: _onCameraModeChanged,
            ),

            // Right side: camera switch + settings
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (cameraState.canSwitchCamera)
                  CameraSwitchButton(
                    onTap: () =>
                        ref.read(cameraServiceProvider.notifier).switchCamera(),
                  ),
                const SizedBox(width: 8),
                _SettingsButton(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SettingsScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        // TTFT pill centered below the row
        if (vlmState.ttft.isNotEmpty) ...[
          const SizedBox(height: 10),
          GlassContainer(
            blur: 10,
            opacity: 0.15,
            borderRadius: BorderRadius.circular(20),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              'TTFT: ${vlmState.ttft}',
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCaptureButton(AppState appState, VLMState vlmState) {
    final hasCapturedImage = appState.capturedImageBytes != null;

    if (hasCapturedImage) {
      // Retake button
      return GestureDetector(
        onTap: _clearCapturedImage,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.refresh_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Retake',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Capture button
    final isDisabled = vlmState.isProcessing || !vlmState.isModelLoaded;

    return GestureDetector(
      onTap: isDisabled ? null : _captureAndProcess,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: isDisabled ? 0.3 : 1.0),
          border: Border.all(
            color: Colors.white,
            width: 4,
          ),
          boxShadow: isDisabled
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
        ),
        child: vlmState.isProcessing
            ? const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Colors.black54,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

/// Glassmorphic settings gear button matching the camera switch button style
class _SettingsButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SettingsButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.settings_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}
