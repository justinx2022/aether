import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../skip/data/skip_service.dart';
import '../widgets/player_control_components.dart';
import '../widgets/player_stream_widgets.dart';

/// Classic SkyStream minimal top bar adapted for [MediaKitPlayerScreen].
///
/// Reuses [PlayerTopBar] and [PlayerIconButton] with zero [BackdropFilter] or
/// multi-layer liquid glass surfaces so users can compare or switch between
/// Liquid Glass and Classic chrome on Windows and TV.
class ClassicMediaKitTopBar extends StatelessWidget {
  const ClassicMediaKitTopBar({
    super.key,
    required this.title,
    this.subtitleTag,
    required this.onBack,
    this.nightAudioEnabled = false,
    this.onToggleNightAudio,
    this.showPipButton = false,
    this.onEnterPip,
    this.sleepTimerMinutes,
    this.onOpenSleepTimer,
    this.onLockScreen,
    this.isTv = false,
  });

  final String title;
  final String? subtitleTag;
  final VoidCallback onBack;
  final bool nightAudioEnabled;
  final VoidCallback? onToggleNightAudio;
  final bool showPipButton;
  final VoidCallback? onEnterPip;
  final int? sleepTimerMinutes;
  final VoidCallback? onOpenSleepTimer;
  final VoidCallback? onLockScreen;
  final bool isTv;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final trailingActions = <Widget>[
      if (onToggleNightAudio != null)
        PlayerIconButton(
          icon: nightAudioEnabled
              ? Icons.record_voice_over_rounded
              : Icons.record_voice_over_outlined,
          tooltip: l10n.playerNightAudio,
          highlight: nightAudioEnabled,
          isTv: isTv,
          onPressed: onToggleNightAudio,
        ),
      if (onOpenSleepTimer != null)
        PlayerIconButton(
          icon: sleepTimerMinutes != null
              ? Icons.bedtime_rounded
              : Icons.bedtime_outlined,
          tooltip: sleepTimerMinutes != null
              ? '${l10n.playerSleepTimer} (${sleepTimerMinutes}m)'
              : l10n.playerSleepTimer,
          highlight: sleepTimerMinutes != null,
          isTv: isTv,
          onPressed: onOpenSleepTimer,
        ),
      if (showPipButton && onEnterPip != null)
        PlayerIconButton(
          icon: Icons.picture_in_picture_alt_rounded,
          tooltip: l10n.pip,
          isTv: isTv,
          onPressed: onEnterPip,
        ),
      if (onLockScreen != null)
        PlayerIconButton(
          icon: Icons.lock_outline_rounded,
          tooltip: l10n.playerLockControls,
          isTv: isTv,
          onPressed: onLockScreen,
        ),
    ];

    return PlayerTopBar(
      title: title,
      subtitle: subtitleTag,
      onBack: onBack,
      isTv: isTv,
      trailing: trailingActions.isEmpty
          ? null
          : Row(mainAxisSize: MainAxisSize.min, children: trailingActions),
    );
  }
}

/// Classic SkyStream minimal bottom bar adapted for [MediaKitPlayerScreen].
///
/// Mirrors BitChord's [LiquidGlassBottomDock] notifier isolation: only the
/// [PlayerScrubber] and [PlayerTimeLabel] rebuild on playback position/buffer
/// ticks while transport controls and action pills stay completely static.
class ClassicMediaKitBottomBar extends StatefulWidget {
  const ClassicMediaKitBottomBar({
    super.key,
    required this.position,
    required this.duration,
    required this.buffer,
    this.positionListenable,
    this.bufferListenable,
    required this.playing,
    required this.seekStepSeconds,
    required this.onPlayPause,
    required this.onSeekRelative,
    required this.onSeekStart,
    required this.onSeekUpdate,
    required this.onSeekEnd,
    required this.hasEpisodes,
    required this.onOpenEpisodes,
    required this.onOpenAudio,
    required this.onOpenSubtitles,
    required this.subtitlesActive,
    required this.subtitleDelay,
    required this.playbackSpeed,
    required this.onCycleSpeed,
    required this.onOpenSources,
    required this.onOpenMore,
    this.skipSegments = const [],
    this.isTv = false,
    this.isLive = false,
    this.onToggleFullscreen,
    this.isFullscreen = false,
  });

  final Duration position;
  final Duration duration;
  final Duration buffer;
  final ValueListenable<Duration>? positionListenable;
  final ValueListenable<Duration>? bufferListenable;
  final bool playing;
  final int seekStepSeconds;
  final VoidCallback onPlayPause;
  final ValueChanged<int> onSeekRelative;
  final VoidCallback onSeekStart;
  final ValueChanged<Duration> onSeekUpdate;
  final ValueChanged<Duration> onSeekEnd;
  final bool hasEpisodes;
  final VoidCallback onOpenEpisodes;
  final VoidCallback onOpenAudio;
  final VoidCallback onOpenSubtitles;
  final bool subtitlesActive;
  final Duration subtitleDelay;
  final double playbackSpeed;
  final VoidCallback onCycleSpeed;
  final VoidCallback onOpenSources;
  final VoidCallback onOpenMore;
  final List<SkipSegment> skipSegments;
  final bool isTv;
  final bool isLive;
  final VoidCallback? onToggleFullscreen;
  final bool isFullscreen;

  @override
  State<ClassicMediaKitBottomBar> createState() =>
      _ClassicMediaKitBottomBarState();
}

class _ClassicMediaKitBottomBarState extends State<ClassicMediaKitBottomBar> {
  bool _dragging = false;
  Duration _dragPosition = Duration.zero;
  ValueNotifier<Duration>? _fallbackPos;
  ValueNotifier<Duration>? _fallbackBuf;

  ValueListenable<Duration> get _effectivePos =>
      widget.positionListenable ??
      (_fallbackPos ??= ValueNotifier<Duration>(widget.position));

  ValueListenable<Duration> get _effectiveBuf =>
      widget.bufferListenable ??
      (_fallbackBuf ??= ValueNotifier<Duration>(widget.buffer));

  @override
  void didUpdateWidget(covariant ClassicMediaKitBottomBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.positionListenable == null && _fallbackPos != null) {
      _fallbackPos!.value = widget.position;
    }
    if (widget.bufferListenable == null && _fallbackBuf != null) {
      _fallbackBuf!.value = widget.buffer;
    }
  }

  @override
  void dispose() {
    _fallbackPos?.dispose();
    _fallbackBuf?.dispose();
    super.dispose();
  }

  String _formatSpeed(double speed) {
    final formatted = speed % 1 == 0
        ? speed.toStringAsFixed(0)
        : speed.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
    return '${formatted}x';
  }

  String _formatSubLabel(AppLocalizations l10n) {
    if (widget.subtitleDelay == Duration.zero) return l10n.subtitles;
    final secs = widget.subtitleDelay.inMilliseconds / 1000.0;
    final sign = secs > 0 ? '+' : '';
    final formatted = secs.abs() < 10 && secs % 1 != 0
        ? secs.toStringAsFixed(1)
        : secs.toStringAsFixed(0);
    return '${l10n.subtitles} ($sign${formatted}s)';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasDuration =
        !widget.isLive && widget.duration > Duration.zero;
    final canSeek = hasDuration;
    final totalMs = widget.duration.inMilliseconds;

    final progressBar = RepaintBoundary(
      child: ValueListenableBuilder<Duration>(
        valueListenable: _effectiveBuf,
        builder: (context, buf, _) {
          final bufferRatio = totalMs > 0
              ? (buf.inMilliseconds / totalMs).clamp(0.0, 1.0)
              : 0.0;
          return ValueListenableBuilder<Duration>(
            valueListenable: _effectivePos,
            builder: (context, pos, _) {
              final shown = _dragging ? _dragPosition : pos;
              return PlayerScrubber(
                position: shown,
                duration: widget.duration,
                bufferRatio: bufferRatio,
                canSeek: canSeek,
                hasDuration: hasDuration,
                isLive: widget.isLive,
                skipSegments: widget.skipSegments,
                isTv: widget.isTv,
                onChangeStart: (ms) {
                  setState(() {
                    _dragging = true;
                    _dragPosition = Duration(milliseconds: ms.round());
                  });
                  widget.onSeekStart();
                },
                onChanged: (ms) {
                  final next = Duration(milliseconds: ms.round());
                  setState(() => _dragPosition = next);
                  widget.onSeekUpdate(next);
                },
                onChangeEnd: (ms) {
                  final target = Duration(milliseconds: ms.round());
                  setState(() => _dragging = false);
                  widget.onSeekEnd(target);
                },
              );
            },
          );
        },
      ),
    );

    final clock = ValueListenableBuilder<Duration>(
      valueListenable: _effectivePos,
      builder: (context, pos, _) {
        final shown = _dragging ? _dragPosition : pos;
        return PlayerTimeLabel(
          position: shown,
          duration: widget.duration,
          hasDuration: hasDuration,
          isLive: widget.isLive,
        );
      },
    );

    final leading = <Widget>[
      PlayerIconButton(
        icon: widget.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
        tooltip: widget.playing ? l10n.pause : l10n.play,
        isTv: widget.isTv,
        autofocus: widget.isTv,
        onPressed: widget.onPlayPause,
      ),
      if (!widget.isLive) ...[
        PlayerIconButton(
          icon: Icons.replay_10_rounded,
          tooltip: l10n.playerRewindSeconds(widget.seekStepSeconds),
          isTv: widget.isTv,
          onPressed: () => widget.onSeekRelative(-widget.seekStepSeconds),
        ),
        PlayerIconButton(
          icon: Icons.forward_10_rounded,
          tooltip: l10n.playerForwardSeconds(widget.seekStepSeconds),
          isTv: widget.isTv,
          onPressed: () => widget.onSeekRelative(widget.seekStepSeconds),
        ),
      ],
      const SizedBox(width: 6),
      clock,
    ];

    final actions = <Widget>[
      if (widget.hasEpisodes)
        PlayerActionButton(
          icon: Icons.video_library_rounded,
          label: l10n.episodes,
          isTv: widget.isTv,
          onTap: widget.onOpenEpisodes,
        ),
      PlayerActionButton(
        icon: Icons.audiotrack_rounded,
        label: l10n.audio,
        isTv: widget.isTv,
        onTap: widget.onOpenAudio,
      ),
      PlayerActionButton(
        icon: Icons.subtitles_rounded,
        label: _formatSubLabel(l10n),
        highlight: widget.subtitlesActive,
        isTv: widget.isTv,
        onTap: widget.onOpenSubtitles,
      ),
      if (!widget.isLive)
        PlayerActionButton(
          icon: Icons.speed_rounded,
          label: _formatSpeed(widget.playbackSpeed),
          highlight: (widget.playbackSpeed - 1.0).abs() > 0.05,
          isTv: widget.isTv,
          onTap: widget.onCycleSpeed,
        ),
      PlayerActionButton(
        icon: Icons.tune_rounded,
        label: l10n.sources,
        isTv: widget.isTv,
        onTap: widget.onOpenSources,
      ),
      if (widget.onToggleFullscreen != null)
        PlayerActionButton(
          icon: widget.isFullscreen
              ? Icons.fullscreen_exit_rounded
              : Icons.fullscreen_rounded,
          label: l10n.fullscreen,
          highlight: widget.isFullscreen,
          isTv: widget.isTv,
          onTap: widget.onToggleFullscreen!,
        ),
      PlayerActionButton(
        icon: Icons.more_horiz_rounded,
        label: l10n.playerMoreControls,
        isTv: widget.isTv,
        onTap: widget.onOpenMore,
      ),
    ];

    return PlayerBottomBar(
      progressBar: progressBar,
      leading: leading,
      actions: actions,
      isTv: widget.isTv,
      scrollingActions: !widget.isTv,
    );
  }
}
