// Copyright (c) 2025-2026 Mihai Moraru. MIT License. See LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/app_state.dart';
import 'glass_container.dart';

/// Modern segmented toggle with glassmorphism and animations
class ModeToggle extends StatelessWidget {
  final CameraMode selectedMode;
  final ValueChanged<CameraMode> onModeChanged;

  const ModeToggle({
    super.key,
    required this.selectedMode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      blur: 15,
      opacity: 0.15,
      borderRadius: BorderRadius.circular(28),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSegment(
            context,
            mode: CameraMode.continuous,
            icon: Icons.videocam_rounded,
            label: 'Live',
          ),
          _buildSegment(
            context,
            mode: CameraMode.singleFrame,
            icon: Icons.camera_alt_rounded,
            label: 'Photo',
          ),
        ],
      ),
    );
  }

  Widget _buildSegment(
    BuildContext context, {
    required CameraMode mode,
    required IconData icon,
    required String label,
  }) {
    final isSelected = selectedMode == mode;

    return GestureDetector(
      onTap: () {
        if (selectedMode != mode) {
          HapticFeedback.selectionClick();
          onModeChanged(mode);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : Colors.white70,
            ),
            const SizedBox(width: 6),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
