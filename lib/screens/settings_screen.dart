// Copyright (c) 2025-2026 Mihai Moraru. MIT License. See LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/settings_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static const String _appVersion = '0.1.0';
  static const String _buildNumber = '1';
  static const int _easterEggTaps = 7;

  int _versionTapCount = 0;
  DateTime? _lastTapTime;

  void _handleVersionTap(BuildContext context, bool isDark) {
    final now = DateTime.now();
    // Reset counter if more than 2s between taps
    if (_lastTapTime != null &&
        now.difference(_lastTapTime!).inMilliseconds > 2000) {
      _versionTapCount = 0;
    }
    _lastTapTime = now;
    _versionTapCount++;

    if (_versionTapCount >= _easterEggTaps) {
      _versionTapCount = 0;
      HapticFeedback.heavyImpact();
      _showEasterEgg(context, isDark);
    } else if (_versionTapCount >= 4) {
      HapticFeedback.lightImpact();
    }
  }

  void _showEasterEgg(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [const Color(0xFF1A1A2E), const Color(0xFF16213E)]
                  : [Colors.white, const Color(0xFFF0F4FF)],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.06),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 24,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('👨\u200d💻', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              Text(
                'With ❤️ by Mihai',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Turning calories into code.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontStyle: FontStyle.italic,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.6)
                      : Colors.black.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '🤫 Shhh…',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final settings = ref.watch(settingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0A) : Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          // Modern app bar
          SliverAppBar.large(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            leading: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).pop();
              },
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black)
                      .withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            title: Text(
              'Settings',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),

          // Content
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Appearance ──
                _SectionHeader(title: 'Appearance', isDark: isDark),
                const SizedBox(height: 8),
                _SettingsCard(
                  isDark: isDark,
                  children: [
                    _ThemeSelector(
                      currentMode: settings.themeMode,
                      isDark: isDark,
                      onChanged: (mode) {
                        HapticFeedback.selectionClick();
                        ref.read(settingsProvider.notifier).setThemeMode(mode);
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // ── General ──
                _SectionHeader(title: 'General', isDark: isDark),
                const SizedBox(height: 8),
                _SettingsCard(
                  isDark: isDark,
                  children: [
                    _SettingsTile(
                      icon: Icons.camera_alt_rounded,
                      iconColor: const Color(0xFF6366F1),
                      title: 'Default Camera',
                      subtitle: '${settings.defaultCamera.label} camera',
                      isDark: isDark,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref
                            .read(settingsProvider.notifier)
                            .toggleDefaultCamera();
                      },
                    ),
                    _SettingsDivider(isDark: isDark),
                    _SettingsTile(
                      icon: Icons.speed_rounded,
                      iconColor: const Color(0xFFF59E0B),
                      title: 'Processing Quality',
                      subtitle: 'Balanced',
                      isDark: isDark,
                      onTap: () {},
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // ── About ──
                _SectionHeader(title: 'About', isDark: isDark),
                const SizedBox(height: 8),
                _SettingsCard(
                  isDark: isDark,
                  children: [
                    _SettingsTile(
                      icon: Icons.info_outline_rounded,
                      iconColor: const Color(0xFF3B82F6),
                      title: 'App Version',
                      subtitle: '$_appVersion ($_buildNumber)',
                      isDark: isDark,
                      showOnTapChevron: false,
                      onTap: () => _handleVersionTap(context, isDark),
                    ),
                    _SettingsDivider(isDark: isDark),
                    _SettingsTile(
                      icon: Icons.memory_rounded,
                      iconColor: const Color(0xFF10B981),
                      title: 'ML Engine',
                      subtitle: 'Apple FastVLM-0.5B – On-device',
                      isDark: isDark,
                    ),
                    _SettingsDivider(isDark: isDark),
                    _SettingsTile(
                      icon: Icons.description_outlined,
                      iconColor: const Color(0xFF8B5CF6),
                      title: 'Licenses',
                      isDark: isDark,
                      // onTap: () => showLicensePage(
                      //   context: context,
                      //   applicationName: 'SeeSight',
                      //   applicationVersion: '$_appVersion+$_buildNumber',
                      //   applicationIcon: Padding(
                      //     padding: const EdgeInsets.all(16),
                      //     child: ClipRRect(
                      //       borderRadius: BorderRadius.circular(16),
                      //       child: Image.asset(
                      //         'assets/logo.png',
                      //         width: 64,
                      //         height: 64,
                      //       ),
                      //     ),
                      //   ),
                      // ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Footer
                Center(
                  child: Column(
                    children: [
                      Text(
                        'SeeSight',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.4)
                              : Colors.black.withValues(alpha: 0.3),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'AI-powered visual understanding',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.25)
                              : Colors.black.withValues(alpha: 0.2),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section Header ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final bool isDark;

  const _SectionHeader({required this.title, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          color: isDark
              ? Colors.white.withValues(alpha: 0.4)
              : Colors.black.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

// ─── Settings Card ───────────────────────────────────────────────────────────

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  final bool isDark;

  const _SettingsCard({required this.children, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Column(children: children),
    );
  }
}

// ─── Settings Divider ────────────────────────────────────────────────────────

class _SettingsDivider extends StatelessWidget {
  final bool isDark;

  const _SettingsDivider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 56),
      child: Divider(
        height: 1,
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.06),
      ),
    );
  }
}

// ─── Settings Tile ───────────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final bool isDark;
  final bool showOnTapChevron;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.isDark,
    this.showOnTapChevron = true,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.4)
                        : Colors.black.withValues(alpha: 0.4),
                  ),
                ),
              if (onTap != null && showOnTapChevron) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.2)
                      : Colors.black.withValues(alpha: 0.2),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Theme Selector ──────────────────────────────────────────────────────────

class _ThemeSelector extends StatelessWidget {
  final ThemeMode currentMode;
  final bool isDark;
  final ValueChanged<ThemeMode> onChanged;

  const _ThemeSelector({
    required this.currentMode,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.palette_rounded,
                    size: 18,
                    color: Color(0xFFF59E0B),
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  'Theme',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: ThemeMode.values.map((mode) {
                final isSelected = mode == currentMode;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onChanged(mode),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDark
                                ? Colors.white.withValues(alpha: 0.12)
                                : Colors.white)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _iconForMode(mode),
                            size: 16,
                            color: isSelected
                                ? (isDark ? Colors.white : Colors.black87)
                                : (isDark
                                    ? Colors.white.withValues(alpha: 0.4)
                                    : Colors.black.withValues(alpha: 0.4)),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _labelForMode(mode),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: isSelected
                                  ? (isDark ? Colors.white : Colors.black87)
                                  : (isDark
                                      ? Colors.white.withValues(alpha: 0.4)
                                      : Colors.black.withValues(alpha: 0.4)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return Icons.settings_brightness_rounded;
      case ThemeMode.light:
        return Icons.light_mode_rounded;
      case ThemeMode.dark:
        return Icons.dark_mode_rounded;
    }
  }

  String _labelForMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'Auto';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }
}
