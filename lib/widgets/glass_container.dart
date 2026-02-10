// Copyright (c) 2025-2026 Mihai Moraru. MIT License. See LICENSE file.

import 'dart:ui';
import 'package:flutter/material.dart';

/// A reusable glassmorphic container with frosted glass effect
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? tintColor;
  final Border? border;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 10.0,
    this.opacity = 0.1,
    this.borderRadius,
    this.padding,
    this.margin,
    this.tintColor,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveTint = tintColor ?? (isDark ? Colors.white : Colors.black);
    final effectiveBorderRadius = borderRadius ?? BorderRadius.circular(16);

    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: effectiveBorderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: effectiveTint.withValues(alpha: opacity),
              borderRadius: effectiveBorderRadius,
              border: border ??
                  Border.all(
                    color: effectiveTint.withValues(alpha: 0.1),
                    width: 1,
                  ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A pill-shaped glass button with tap feedback
class GlassPill extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double blur;
  final EdgeInsetsGeometry? padding;

  const GlassPill({
    super.key,
    required this.child,
    this.onTap,
    this.blur = 10.0,
    this.padding,
  });

  @override
  State<GlassPill> createState() => _GlassPillState();
}

class _GlassPillState extends State<GlassPill>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _controller.reverse();
  }

  void _handleTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap != null ? _handleTapDown : null,
      onTapUp: widget.onTap != null ? _handleTapUp : null,
      onTapCancel: widget.onTap != null ? _handleTapCancel : null,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: GlassContainer(
          blur: widget.blur,
          borderRadius: BorderRadius.circular(24),
          padding: widget.padding ??
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: widget.child,
        ),
      ),
    );
  }
}
