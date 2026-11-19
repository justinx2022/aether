import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entity/multimedia_item.dart';
import '../../../settings/presentation/player_settings_provider.dart';
import 'hotstar_player_style.dart';

/// Modern Unified Player Controls Suite.
///
/// Implements an organized visual hierarchy:
/// 1. Top left: Compact title, poster thumbnail, release metadata, and format badges (1080p, Dolby Vision, 5.1).
/// 2. Top right: PiP, Cast/Stream, More options (...), and Profile avatar.
/// 3. Centre: Dominant frosted glass Play/Pause and 10s skip controls.
/// 4. Bottom: Continuous progress scrubber with timestamps.
/// 5. Control Dock: Glassmorphic dock for Volume, Speed, Subtitles, Audio, Display, Bookmarks, Episodes, and Fullscreen.
/// 6. Settings Flyout Panel: Right-aligned glassmorphic card grouping Quality, Audio, Subtitle, Speed, Engine, and About.
/// 7. Collapsible Diagnostics HUD: Stream stats and bitrate waveform (hidden by default).
/// 8. Atmospheric Ambient Glow: Luminous bottom neon glow keyed to customizable theme color.

String _formatDuration(Duration d) {
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60);
  final seconds = d.inSeconds.remainder(60);
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

/// 1. Modern Top Bar
class ModernPlayerTopBar extends StatelessWidget {
  final MultimediaItem item;
  final Episode? episode;
  final String qualityLabel;
  final VoidCallback onBack;
  final VoidCallback onMore;
  final VoidCallback? onPip;
  final VoidCallback? onCast;
  final Color accentColor;

  const ModernPlayerTopBar({
    super.key,
    required this.item,
    this.episode,
    required this.qualityLabel,
    required this.onBack,
    required this.onMore,
    this.onPip,
    this.onCast,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final ep = episode;
    final epText = ep != null
        ? (ep.name.isNotEmpty
            ? (ep.season > 0
                ? 'S${ep.season} E${ep.episode} • ${ep.name}'
                : 'Episode ${ep.episode} • ${ep.name}')
            : (ep.season > 0
                ? 'Season ${ep.season} Episode ${ep.episode}'
                : 'Episode ${ep.episode}'))
        : null;

    final yearStr = item.year != null && item.year! > 0 ? '${item.year}' : '';
    final durStr = item.duration != null && item.duration! > 0
        ? '${item.duration! ~/ 60}h ${item.duration! % 60}m'
        : '';
    final ratingStr = item.contentRating ?? '';
    final metaText = epText ??
        [yearStr, durStr, ratingStr].where((s) => s.isNotEmpty).join(' • ');

    final posterUrl = item.posterImageUrl;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xE6000000),
            Color(0x99000000),
            Color(0x00000000),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Glass Back Button
            _FrostedIconButton(
              icon: Icons.arrow_back_rounded,
              size: 40,
              iconSize: 20,
              tooltip: 'Back',
              onTap: onBack,
            ),
            const SizedBox(width: 14),

            // Poster Thumbnail (if available)
            if (posterUrl.isNotEmpty)
              Container(
                width: 36,
                height: 48,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white24, width: 0.8),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black45,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: Image.network(
                    posterUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.white10,
                      child: const Icon(Icons.movie_rounded, color: Colors.white54, size: 20),
                    ),
                  ),
                ),
              ),

            // Title & Metadata
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (metaText.isNotEmpty)
                        Flexible(
                          child: Text(
                            metaText,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      if (metaText.isNotEmpty) const SizedBox(width: 10),
                      // Format Pills
                      _FormatPill(
                        label: qualityLabel.isEmpty ? '1080p' : qualityLabel,
                        color: accentColor,
                        isFilled: true,
                      ),
                      const SizedBox(width: 6),
                      const _FormatPill(
                        label: 'Dolby Vision',
                        icon: Icons.brightness_6_rounded,
                      ),
                      const SizedBox(width: 6),
                      const _FormatPill(
                        label: '5.1',
                        icon: Icons.surround_sound_rounded,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Top Right Action Buttons
            if (onPip != null) ...[
              _FrostedIconButton(
                icon: Icons.picture_in_picture_alt_rounded,
                size: 38,
                iconSize: 18,
                tooltip: 'Picture in Picture',
                onTap: onPip!,
              ),
              const SizedBox(width: 10),
            ],
            if (onCast != null) ...[
              _FrostedIconButton(
                icon: Icons.cast_rounded,
                size: 38,
                iconSize: 18,
                tooltip: 'Cast Stream',
                onTap: onCast!,
              ),
              const SizedBox(width: 10),
            ],
            _FrostedIconButton(
              icon: Icons.more_horiz_rounded,
              size: 38,
              iconSize: 20,
              tooltip: 'Settings & More',
              onTap: onMore,
            ),
            const SizedBox(width: 10),
            // Profile Avatar
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accentColor, accentColor.withValues(alpha: 0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white30, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.35),
                    blurRadius: 10,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Text(
                'J',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 2. Format Badge Pill
class _FormatPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;
  final bool isFilled;

  const _FormatPill({
    required this.label,
    this.icon,
    this.color,
    this.isFilled = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Colors.white.withValues(alpha: 0.15);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isFilled
            ? (color ?? Colors.purple).withValues(alpha: 0.28)
            : const Color(0x33000000),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: isFilled
              ? (color ?? Colors.purple).withValues(alpha: 0.7)
              : Colors.white.withValues(alpha: 0.18),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: Colors.white70),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: isFilled ? (color ?? Colors.white) : Colors.white70,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// 3. Visually Dominant Centre Controls
class ModernPlayerCenterControls extends StatelessWidget {
  final bool playing;
  final VoidCallback onTogglePlay;
  final VoidCallback onSkipBackward;
  final VoidCallback onSkipForward;
  final Color accentColor;

  const ModernPlayerCenterControls({
    super.key,
    required this.playing,
    required this.onTogglePlay,
    required this.onSkipBackward,
    required this.onSkipForward,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Skip Backward 10s
          _FrostedCircularButton(
            size: 54,
            icon: Icons.replay_10_rounded,
            iconSize: 28,
            tooltip: 'Rewind 10s',
            onTap: onSkipBackward,
          ),
          const SizedBox(width: 32),

          // Central Dominant Play/Pause
          GestureDetector(
            onTap: onTogglePlay,
            child: Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xCC1A1A2E),
                    const Color(0xEE0D0D18),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35),
                  width: 1.6,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 28,
                    spreadRadius: 4,
                  ),
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.35),
                    blurRadius: 36,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 42,
                ),
              ),
            ),
          ),
          const SizedBox(width: 32),

          // Skip Forward 10s
          _FrostedCircularButton(
            size: 54,
            icon: Icons.forward_10_rounded,
            iconSize: 28,
            tooltip: 'Forward 10s',
            onTap: onSkipForward,
          ),
        ],
      ),
    );
  }
}

/// 4. Modern Bottom Scrub Bar & Dock
class ModernPlayerBottomDock extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final double bufferRatio;
  final bool isLive;
  final double volume;
  final double speed;
  final String audioTrackLabel;
  final String subtitleTrackLabel;
  final String fitLabel;
  final bool hasEpisodes;
  final bool isFullscreen;
  final Color accentColor;
  final bool showKeyboardHint;
  final ValueChanged<double> onSeek;
  final VoidCallback onTogglePlay;
  final ValueChanged<double> onVolumeChanged;
  final VoidCallback onSpeedTap;
  final VoidCallback onSubtitleTap;
  final VoidCallback onAudioTap;
  final VoidCallback onFitTap;
  final VoidCallback onBookmarksTap;
  final VoidCallback onEpisodesTap;
  final VoidCallback onFullscreenTap;
  final VoidCallback onMoreOptionsTap;

  const ModernPlayerBottomDock({
    super.key,
    required this.position,
    required this.duration,
    required this.bufferRatio,
    this.isLive = false,
    required this.volume,
    required this.speed,
    required this.audioTrackLabel,
    required this.subtitleTrackLabel,
    required this.fitLabel,
    required this.hasEpisodes,
    required this.isFullscreen,
    required this.accentColor,
    this.showKeyboardHint = true,
    required this.onSeek,
    required this.onTogglePlay,
    required this.onVolumeChanged,
    required this.onSpeedTap,
    required this.onSubtitleTap,
    required this.onAudioTap,
    required this.onFitTap,
    required this.onBookmarksTap,
    required this.onEpisodesTap,
    required this.onFullscreenTap,
    required this.onMoreOptionsTap,
  });

  @override
  Widget build(BuildContext context) {
    final posMs = position.inMilliseconds.toDouble();
    final durMs = duration.inMilliseconds.toDouble();
    final validDuration = durMs > 0;
    final progress = validDuration ? (posMs / durMs).clamp(0.0, 1.0) : 0.0;
    final bufferProgress = bufferRatio.clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Color(0xF0000000),
            Color(0xA6000000),
            Color(0x00000000),
          ],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Scrubber Row with Timestamp
            Row(
              children: [
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6.5,
                        elevation: 4,
                      ),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                      activeTrackColor: accentColor,
                      inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
                      secondaryActiveTrackColor: Colors.white.withValues(alpha: 0.35),
                      thumbColor: Colors.white,
                      overlayColor: accentColor.withValues(alpha: 0.25),
                    ),
                    child: Slider(
                      value: validDuration ? posMs.clamp(0.0, durMs) : 0.0,
                      min: 0.0,
                      max: validDuration ? durMs : 1.0,
                      secondaryTrackValue: validDuration ? bufferProgress * durMs : 0.0,
                      onChanged: validDuration ? onSeek : null,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  isLive
                      ? 'LIVE'
                      : '${_formatDuration(position)} / ${_formatDuration(duration)}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Control Dock Row
            Row(
              children: [
                // Keyboard Shortcut Pill Hint (Bottom Left)
                if (showKeyboardHint)
                  GestureDetector(
                    onTap: onMoreOptionsTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome, size: 12, color: accentColor),
                          const SizedBox(width: 5),
                          Text(
                            'Press [K] for more options',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const Spacer(),

                // Volume Bar
                _VolumeController(
                  volume: volume,
                  onVolumeChanged: onVolumeChanged,
                  accentColor: accentColor,
                ),
                const SizedBox(width: 8),
                const _DockDivider(),
                const SizedBox(width: 8),

                // Speed
                _DockButton(
                  icon: Icons.speed_rounded,
                  label: '${speed == 1.0 ? '1.0' : speed.toString()}x',
                  tooltip: 'Playback Speed',
                  onTap: onSpeedTap,
                ),
                const SizedBox(width: 6),

                // Subtitles
                _DockButton(
                  icon: Icons.closed_caption_rounded,
                  label: 'CC',
                  tooltip: 'Subtitles ($subtitleTrackLabel)',
                  onTap: onSubtitleTap,
                ),
                const SizedBox(width: 6),

                // Audio Track Dropdown
                _DockButton(
                  icon: Icons.audiotrack_rounded,
                  label: audioTrackLabel.isNotEmpty ? audioTrackLabel : 'Audio',
                  hasDropdown: true,
                  tooltip: 'Audio Tracks',
                  onTap: onAudioTap,
                ),
                const SizedBox(width: 8),
                const _DockDivider(),
                const SizedBox(width: 8),

                // Display Fit
                _DockIconButton(
                  icon: Icons.aspect_ratio_rounded,
                  tooltip: 'Aspect Ratio ($fitLabel)',
                  onTap: onFitTap,
                ),
                const SizedBox(width: 4),

                // Bookmarks
                _DockIconButton(
                  icon: Icons.bookmark_border_rounded,
                  tooltip: 'Bookmarks',
                  onTap: onBookmarksTap,
                ),
                const SizedBox(width: 4),

                // Episodes (for series)
                if (hasEpisodes) ...[
                  _DockIconButton(
                    icon: Icons.playlist_play_rounded,
                    tooltip: 'Episode List',
                    onTap: onEpisodesTap,
                  ),
                  const SizedBox(width: 4),
                ],

                // Fullscreen
                _DockIconButton(
                  icon: isFullscreen
                      ? Icons.fullscreen_exit_rounded
                      : Icons.fullscreen_rounded,
                  tooltip: isFullscreen ? 'Exit Fullscreen' : 'Fullscreen',
                  onTap: onFullscreenTap,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 5. Modern Settings Flyout Panel (Right-side Card)
class ModernPlayerSettingsFlyout extends StatelessWidget {
  final String currentQuality;
  final String currentAudio;
  final String currentSubtitle;
  final double currentSpeed;
  final String currentEngine;
  final bool showStatsHud;
  final Color accentColor;
  final VoidCallback onClose;
  final VoidCallback onQualityTap;
  final VoidCallback onAudioTap;
  final VoidCallback onSubtitleTap;
  final VoidCallback onSpeedTap;
  final VoidCallback onEngineTap;
  final VoidCallback onToggleStatsHud;
  final VoidCallback onAdvancedSettingsTap;
  final VoidCallback onAboutTap;

  const ModernPlayerSettingsFlyout({
    super.key,
    required this.currentQuality,
    required this.currentAudio,
    required this.currentSubtitle,
    required this.currentSpeed,
    required this.currentEngine,
    required this.showStatsHud,
    required this.accentColor,
    required this.onClose,
    required this.onQualityTap,
    required this.onAudioTap,
    required this.onSubtitleTap,
    required this.onSpeedTap,
    required this.onEngineTap,
    required this.onToggleStatsHud,
    required this.onAdvancedSettingsTap,
    required this.onAboutTap,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 70,
      right: 20,
      width: 320,
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xE60E111A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1,
            ),
            boxShadow: [
              const BoxShadow(
                color: Colors.black87,
                blurRadius: 28,
                spreadRadius: 4,
                offset: Offset(0, 8),
              ),
              BoxShadow(
                color: accentColor.withValues(alpha: 0.18),
                blurRadius: 20,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 10, 8),
                  child: Row(
                    children: [
                      const Text(
                        'Playback Settings',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18, color: Colors.white70),
                        onPressed: onClose,
                        splashRadius: 16,
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12, height: 1),

                // Settings Rows
                _FlyoutRow(
                  icon: Icons.hd_rounded,
                  title: 'Quality',
                  value: currentQuality.isEmpty ? '1080p' : currentQuality,
                  onTap: onQualityTap,
                ),
                _FlyoutRow(
                  icon: Icons.volume_up_rounded,
                  title: 'Audio Track',
                  value: currentAudio.isEmpty ? 'English' : currentAudio,
                  onTap: onAudioTap,
                ),
                _FlyoutRow(
                  icon: Icons.subtitles_rounded,
                  title: 'Subtitle',
                  value: currentSubtitle.isEmpty ? 'English' : currentSubtitle,
                  onTap: onSubtitleTap,
                ),
                _FlyoutRow(
                  icon: Icons.speed_rounded,
                  title: 'Playback Speed',
                  value: '${currentSpeed == 1.0 ? '1.0' : currentSpeed.toString()}x',
                  onTap: onSpeedTap,
                ),
                _FlyoutRow(
                  icon: Icons.settings_input_component_rounded,
                  title: 'Playback Engine',
                  value: currentEngine,
                  onTap: onEngineTap,
                ),
                _FlyoutRow(
                  icon: Icons.bar_chart_rounded,
                  title: 'Stream Diagnostics HUD',
                  value: showStatsHud ? 'Visible' : 'Hidden',
                  onTap: onToggleStatsHud,
                ),
                const Divider(color: Colors.white12, height: 1),
                _FlyoutRow(
                  icon: Icons.tune_rounded,
                  title: 'Advanced Settings',
                  onTap: onAdvancedSettingsTap,
                ),
                _FlyoutRow(
                  icon: Icons.info_outline_rounded,
                  title: 'About Stream',
                  onTap: onAboutTap,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 6. Collapsible Diagnostics Stats HUD Card (Top Right)
class ModernPlayerStatsCard extends StatelessWidget {
  final String speedText;
  final String qualityText;
  final String cpuText;
  final String ramText;
  final String bufferText;
  final Color accentColor;

  const ModernPlayerStatsCard({
    super.key,
    required this.speedText,
    required this.qualityText,
    required this.cpuText,
    required this.ramText,
    required this.bufferText,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 70,
      right: 20,
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xCC0D1117),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 0.8,
          ),
          boxShadow: [
            const BoxShadow(color: Colors.black54, blurRadius: 16),
            BoxShadow(color: accentColor.withValues(alpha: 0.15), blurRadius: 12),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Playing smoothly',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(Icons.show_chart_rounded, size: 16, color: accentColor),
                Text(
                  speedText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StatsMini(icon: Icons.tv_rounded, text: qualityText),
                _StatsMini(icon: Icons.memory_rounded, text: cpuText),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StatsMini(icon: Icons.data_usage_rounded, text: ramText),
                _StatsMini(icon: Icons.inventory_2_rounded, text: bufferText),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsMini extends StatelessWidget {
  final IconData icon;
  final String text;

  const _StatsMini({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.white38),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(color: Colors.white60, fontSize: 10.5),
        ),
      ],
    );
  }
}

/// 7. Atmospheric Ambient Glow
class ModernPlayerAmbientGlow extends StatelessWidget {
  final Color accentColor;

  const ModernPlayerAmbientGlow({super.key, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      height: 140,
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.bottomCenter,
              radius: 1.1,
              colors: [
                accentColor.withValues(alpha: 0.18),
                accentColor.withValues(alpha: 0.06),
                Colors.transparent,
              ],
              stops: const [0.0, 0.45, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}

// ----------------- Internal Helper Widgets -----------------

class _FrostedIconButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final double iconSize;
  final String tooltip;
  final VoidCallback onTap;

  const _FrostedIconButton({
    required this.icon,
    this.size = 38,
    this.iconSize = 18,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(size / 2),
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.10),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 0.8,
              ),
            ),
            child: Icon(icon, color: Colors.white, size: iconSize),
          ),
        ),
      ),
    );
  }
}

class _FrostedCircularButton extends StatelessWidget {
  final double size;
  final IconData icon;
  final double iconSize;
  final String tooltip;
  final VoidCallback onTap;

  const _FrostedCircularButton({
    required this.size,
    required this.icon,
    required this.iconSize,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(size / 2),
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.45),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.22),
                width: 1.2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black38,
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: iconSize),
          ),
        ),
      ),
    );
  }
}

class _VolumeController extends StatefulWidget {
  final double volume;
  final ValueChanged<double> onVolumeChanged;
  final Color accentColor;

  const _VolumeController({
    required this.volume,
    required this.onVolumeChanged,
    required this.accentColor,
  });

  @override
  State<_VolumeController> createState() => _VolumeControllerState();
}

class _VolumeControllerState extends State<_VolumeController> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final vol = widget.volume;
    final isMuted = vol <= 0;

    return MouseRegion(
      onEnter: (_) => setState(() => _expanded = true),
      onExit: (_) => setState(() => _expanded = false),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              isMuted
                  ? Icons.volume_off_rounded
                  : (vol > 50 ? Icons.volume_up_rounded : Icons.volume_down_rounded),
              color: Colors.white70,
              size: 20,
            ),
            tooltip: isMuted ? 'Unmute' : 'Mute',
            onPressed: () => widget.onVolumeChanged(isMuted ? 100.0 : 0.0),
            splashRadius: 18,
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: _expanded ? 80 : 0,
            height: 24,
            child: ClipRect(
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
                  activeTrackColor: widget.accentColor,
                  inactiveTrackColor: Colors.white24,
                  thumbColor: Colors.white,
                ),
                child: Slider(
                  value: vol.clamp(0.0, 100.0),
                  min: 0.0,
                  max: 100.0,
                  onChanged: widget.onVolumeChanged,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DockButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String tooltip;
  final bool hasDropdown;
  final VoidCallback onTap;

  const _DockButton({
    required this.icon,
    required this.label,
    required this.tooltip,
    this.hasDropdown = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white70, size: 16),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (hasDropdown) ...[
                  const SizedBox(width: 3),
                  const Icon(Icons.arrow_drop_down_rounded, color: Colors.white54, size: 16),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DockIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _DockIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, color: Colors.white70, size: 20),
        onPressed: onTap,
        splashRadius: 18,
      ),
    );
  }
}

class _DockDivider extends StatelessWidget {
  const _DockDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 18,
      color: Colors.white12,
    );
  }
}

class _FlyoutRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback onTap;

  const _FlyoutRow({
    required this.icon,
    required this.title,
    this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 18, color: Colors.white70),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (value != null) ...[
                Text(
                  value!,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
