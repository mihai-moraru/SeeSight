// Copyright (c) 2025-2026 Mihai Moraru. MIT License. See LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which camera lens to use by default
enum DefaultCamera {
  front,
  back;

  String get label {
    switch (this) {
      case DefaultCamera.front:
        return 'Front';
      case DefaultCamera.back:
        return 'Back';
    }
  }
}

/// App-wide settings state
class SettingsState {
  final ThemeMode themeMode;
  final DefaultCamera defaultCamera;

  const SettingsState({
    this.themeMode = ThemeMode.system,
    this.defaultCamera = DefaultCamera.back,
  });

  SettingsState copyWith({
    ThemeMode? themeMode,
    DefaultCamera? defaultCamera,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      defaultCamera: defaultCamera ?? this.defaultCamera,
    );
  }

  String get themeLabel {
    switch (themeMode) {
      case ThemeMode.system:
        return 'System';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }
}

/// Settings notifier — Riverpod 3.x Notifier API
class SettingsNotifier extends Notifier<SettingsState> {
  @override
  SettingsState build() => const SettingsState();

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
  }

  void setDefaultCamera(DefaultCamera camera) {
    state = state.copyWith(defaultCamera: camera);
  }

  void toggleDefaultCamera() {
    state = state.copyWith(
      defaultCamera: state.defaultCamera == DefaultCamera.back
          ? DefaultCamera.front
          : DefaultCamera.back,
    );
  }
}

/// Provider for app settings
final settingsProvider =
    NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);
