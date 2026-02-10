// Copyright (c) 2025-2026 Mihai Moraru. MIT License. See LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/app_state.dart';
import '../services/camera_service.dart';
import '../services/vlm_service.dart';

/// Error dialog widget with retry options
class ErrorDialog extends ConsumerWidget {
  final AppError error;
  final VoidCallback? onDismiss;

  const ErrorDialog({
    super.key,
    required this.error,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AlertDialog(
      icon: Icon(
        _getErrorIcon(),
        color: Theme.of(context).colorScheme.error,
        size: 48,
      ),
      title: Text(error.title),
      content: Text(error.message),
      actions: [
        TextButton(
          onPressed: () {
            _dismissError(ref);
            Navigator.of(context).pop();
            onDismiss?.call();
          },
          child: const Text('Dismiss'),
        ),
        if (error.canRetry)
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _retryAction(ref);
            },
            child: const Text('Retry'),
          ),
        if (error.source == ErrorSource.camera &&
            error.title == 'Camera Permission Denied')
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
      ],
    );
  }

  IconData _getErrorIcon() {
    switch (error.source) {
      case ErrorSource.camera:
        return Icons.camera_alt_outlined;
      case ErrorSource.vlm:
        return Icons.memory_outlined;
    }
  }

  void _dismissError(WidgetRef ref) {
    switch (error.source) {
      case ErrorSource.camera:
        ref.read(cameraServiceProvider.notifier).clearError();
        break;
      case ErrorSource.vlm:
        ref.read(vlmServiceProvider.notifier).clearError();
        break;
    }
  }

  void _retryAction(WidgetRef ref) {
    switch (error.source) {
      case ErrorSource.camera:
        ref.read(cameraServiceProvider.notifier).clearError();
        ref.read(cameraServiceProvider.notifier).initialize();
        break;
      case ErrorSource.vlm:
        ref.read(vlmServiceProvider.notifier).clearError();
        ref.read(vlmServiceProvider.notifier).loadModel();
        break;
    }
  }

  /// Show error dialog
  static Future<void> show(BuildContext context, AppError error) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ErrorDialog(error: error),
    );
  }
}

/// Error banner widget for non-blocking errors
class ErrorBanner extends ConsumerWidget {
  final AppError error;

  const ErrorBanner({
    super.key,
    required this.error,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialBanner(
      backgroundColor: Theme.of(context).colorScheme.errorContainer,
      leading: Icon(
        _getErrorIcon(),
        color: Theme.of(context).colorScheme.error,
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            error.title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
          ),
          Text(
            error.message,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => _dismissError(ref),
          child: const Text('Dismiss'),
        ),
        if (error.canRetry)
          TextButton(
            onPressed: () => _retryAction(ref),
            child: const Text('Retry'),
          ),
      ],
    );
  }

  IconData _getErrorIcon() {
    switch (error.source) {
      case ErrorSource.camera:
        return Icons.camera_alt_outlined;
      case ErrorSource.vlm:
        return Icons.memory_outlined;
    }
  }

  void _dismissError(WidgetRef ref) {
    switch (error.source) {
      case ErrorSource.camera:
        ref.read(cameraServiceProvider.notifier).clearError();
        break;
      case ErrorSource.vlm:
        ref.read(vlmServiceProvider.notifier).clearError();
        break;
    }
  }

  void _retryAction(WidgetRef ref) {
    switch (error.source) {
      case ErrorSource.camera:
        ref.read(cameraServiceProvider.notifier).clearError();
        ref.read(cameraServiceProvider.notifier).initialize();
        break;
      case ErrorSource.vlm:
        ref.read(vlmServiceProvider.notifier).clearError();
        ref.read(vlmServiceProvider.notifier).loadModel();
        break;
    }
  }
}

/// Error listener widget that shows dialogs automatically
class AppErrorListener extends ConsumerWidget {
  final Widget child;

  const AppErrorListener({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AppError?>(combinedErrorProvider, (previous, next) {
      if (next != null && previous == null) {
        ErrorDialog.show(context, next);
      }
    });

    return child;
  }
}
