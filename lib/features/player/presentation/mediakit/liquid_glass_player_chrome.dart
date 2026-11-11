import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:skystream/l10n/generated/app_localizations.dart';

import '../../../../shared/widgets/glass_surface.dart';
import '../../../skip/data/skip_service.dart';

/// Floats a modal bottom sheet in a BitChord Apple Liquid Glass translucent
/// frosted panel instead of an opaque Material sheet.
Future<T?> showLiquidGlassPlayerSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    elevation: 0,
    builder: (ctx) {
      final bottomInset = MediaQuery.viewInsetsOf(ctx).bottom;
      return Padding(
        padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + bottomInset),
        child: Center(
          heightFactor: 1.0,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 560,
              maxHeight: MediaQuery.sizeOf(ctx).height * 0.86,
            ),
            child: RepaintBoundary(
              child: GlassSurface(
                borderRadius: BorderRadius.circular(26),
                padding: EdgeInsets.zero,
                blurSigma: 14,
                useVibrancy: false,
                shadow: true,
                rimStrength: 1.25,
                fill: const Color(0xFF0B101B).withValues(alpha: 0.72),
                child: builder(ctx),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Reusable BitChord optical frosted capsule for player chrome buttons/bars.
class LiquidPlayerCapsule extends StatelessWidget {
  const LiquidPlayerCapsule({
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(22)),
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    this.activeAccent,
    this.rimStrength = 1.05,
    this.blurSigma = 12.0,
    super.key,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;
  final Color? activeAccent;
  final double rimStrength;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    final isWindows = Theme.of(context).platform == TargetPlatform.windows;
    final baseAlpha = isWindows ? 0.78 : 0.50;
    final accentBlendAlpha = isWindows ? 0.82 : 0.54;
    final fill = activeAccent != null
        ? Color.alphaBlend(
            activeAccent!.withValues(alpha: isWindows ? 0.28 : 0.24),
            const Color(0xFF0E1422).withValues(alpha: accentBlendAlpha),
          )
        : const Color(0xFF0E1422).withValues(alpha: baseAlpha);

    return RepaintBoundary(
      child: GlassSurface(
        borderRadius: borderRadius,
        padding: padding,
        blurSigma: isWindows ? 0 : blurSigma,
        useVibrancy: false,
        shadow: false,
        rimStrength: activeAccent != null ? math.max(1.25, rimStrength) : rimStrength,
        fill: fill,
        child: child,
      ),
    );
  }
}

/// Frosted circular action orb (Back, PiP, Lock, Night Audio, Transport Skip).
class LiquidPlayerOrbButton extends StatefulWidget {
  const LiquidPlayerOrbButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 42,
    this.iconSize = 20,
    this.activeAccent,
    this.active = false,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final double iconSize;
  final Color? activeAccent;
  final bool active;

  @override
  State<LiquidPlayerOrbButton> createState() => _LiquidPlayerOrbButtonState();
}

class _LiquidPlayerOrbButtonState extends State<LiquidPlayerOrbButton> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.active
        ? (widget.activeAccent ?? const Color(0xFF818CF8))
        : null;
    final button = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _pressed ? 0.91 : (_hovered ? 1.06 : 1.0),
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: LiquidPlayerCapsule(
              borderRadius: BorderRadius.circular(widget.size / 2),
              padding: EdgeInsets.zero,
              activeAccent: accent,
              blurSigma: 12,
              child: Center(
                child: Icon(
                  widget.icon,
                  size: widget.iconSize,
                  color: widget.active
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.92),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (widget.tooltip != null && widget.tooltip!.isNotEmpty) {
      return Tooltip(message: widget.tooltip!, child: button);
    }
    return button;
  }
}

/// Top floating BitChord Liquid Glass HUD: title capsule on left, quick-toggle
/// orbs on right.
class LiquidGlassTopHud extends StatelessWidget {
  const LiquidGlassTopHud({
    required this.title,
    required this.onBack,
    this.subtitleTag,
    this.qualityBadge,
    this.nightAudioEnabled = false,
    this.onToggleNightAudio,
    this.showPipButton = false,
    this.onEnterPip,
    this.sleepTimerMinutes,
    this.onOpenSleepTimer,
    this.isLocked = false,
    this.onLockScreen,
    this.isTv = false,
    super.key,
  });

  final String title;
  final String? subtitleTag;
  final String? qualityBadge;
  final VoidCallback onBack;
  final bool nightAudioEnabled;
  final VoidCallback? onToggleNightAudio;
  final bool showPipButton;
  final VoidCallback? onEnterPip;
  final int? sleepTimerMinutes;
  final VoidCallback? onOpenSleepTimer;
  final bool isLocked;
  final VoidCallback? onLockScreen;
  final bool isTv;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final topPad = MediaQuery.paddingOf(context).top;

    return Container(
      padding: EdgeInsets.fromLTRB(
        isTv ? 28 : 14,
        math.max(10.0, topPad + 6),
        isTv ? 28 : 14,
        14,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xBA05070D),
            Color(0x5205070D),
            Color(0x0005070D),
          ],
          stops: <double>[0.0, 0.58, 1.0],
        ),
      ),
      child: Row(
        children: <Widget>[
          LiquidPlayerOrbButton(
            icon: Icons.arrow_back_ios_new_rounded,
            tooltip: l10n.goBack,
            size: isTv ? 48 : 42,
            iconSize: isTv ? 22 : 18,
            onPressed: onBack,
          ),
          const SizedBox(width: 10),
          Flexible(
            child: LiquidPlayerCapsule(
              borderRadius: BorderRadius.circular(22),
              padding: EdgeInsets.symmetric(
                horizontal: isTv ? 16 : 13,
                vertical: isTv ? 9 : 7,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isTv ? 16 : 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                        if (subtitleTag != null && subtitleTag!.isNotEmpty)
                          Text(
                            subtitleTag!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.68),
                              fontSize: isTv ? 12.5 : 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (qualityBadge != null && qualityBadge!.isNotEmpty) ...<Widget>[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: LinearGradient(
                          colors: <Color>[
                            const Color(0xFF38BDF8).withValues(alpha: 0.28),
                            const Color(0xFF818CF8).withValues(alpha: 0.28),
                          ],
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.28),
                          width: 0.7,
                        ),
                      ),
                      child: Text(
                        qualityBadge!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Right utility orb cluster
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (onToggleNightAudio != null) ...<Widget>[
                LiquidPlayerOrbButton(
                  icon: Icons.nightlight_round,
                  tooltip: l10n.playerNightAudio,
                  active: nightAudioEnabled,
                  activeAccent: const Color(0xFFF59E0B),
                  size: isTv ? 46 : 40,
                  iconSize: isTv ? 20 : 18,
                  onPressed: onToggleNightAudio,
                ),
                const SizedBox(width: 8),
              ],
              if (onOpenSleepTimer != null) ...<Widget>[
                LiquidPlayerOrbButton(
                  icon: sleepTimerMinutes != null
                      ? Icons.bedtime_rounded
                      : Icons.bedtime_outlined,
                  tooltip: l10n.playerSleepTimer,
                  active: sleepTimerMinutes != null,
                  activeAccent: const Color(0xFF818CF8),
                  size: isTv ? 46 : 40,
                  iconSize: isTv ? 20 : 18,
                  onPressed: onOpenSleepTimer,
                ),
                const SizedBox(width: 8),
              ],
              if (showPipButton && onEnterPip != null) ...<Widget>[
                LiquidPlayerOrbButton(
                  icon: Icons.picture_in_picture_alt_rounded,
                  tooltip: l10n.pip,
                  size: isTv ? 46 : 40,
                  iconSize: isTv ? 20 : 18,
                  onPressed: onEnterPip,
                ),
                const SizedBox(width: 8),
              ],
              if (!isTv && onLockScreen != null)
                LiquidPlayerOrbButton(
                  icon: isLocked
                      ? Icons.lock_rounded
                      : Icons.lock_open_rounded,
                  tooltip: l10n.playerLockControls,
                  size: 40,
                  iconSize: 18,
                  onPressed: onLockScreen,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Center BitChord frosted glass Play/Pause sphere & flanking -/+ seek orbs.
class LiquidGlassCenterTransport extends StatelessWidget {
  const LiquidGlassCenterTransport({
    required this.isPlaying,
    required this.isBuffering,
    required this.seekStepSeconds,
    required this.onPlayPause,
    required this.onSeekBackward,
    required this.onSeekForward,
    this.isLive = false,
    super.key,
  });

  final bool isPlaying;
  final bool isBuffering;
  final int seekStepSeconds;
  final VoidCallback onPlayPause;
  final VoidCallback onSeekBackward;
  final VoidCallback onSeekForward;
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (!isLive) ...<Widget>[
          _SeekStepOrb(
            seconds: seekStepSeconds,
            forward: false,
            tooltip: l10n.playerRewindSeconds(seekStepSeconds),
            onPressed: onSeekBackward,
          ),
          const SizedBox(width: 28),
        ],
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPlayPause,
          child: SizedBox(
            width: 78,
            height: 78,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                RepaintBoundary(
                  child: GlassSurface(
                    borderRadius: BorderRadius.circular(39),
                    padding: EdgeInsets.zero,
                    blurSigma: 14,
                    useVibrancy: false,
                    rimStrength: 1.4,
                    fill: const Color(0xFF101626).withValues(alpha: 0.48),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 160),
                        switchInCurve: Curves.easeOutBack,
                        child: Icon(
                          isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          key: ValueKey<bool>(isPlaying),
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                ),
                if (isBuffering)
                  const SizedBox(
                    width: 72,
                    height: 72,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF7DD3FC),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (!isLive) ...<Widget>[
          const SizedBox(width: 28),
          _SeekStepOrb(
            seconds: seekStepSeconds,
            forward: true,
            tooltip: l10n.playerForwardSeconds(seekStepSeconds),
            onPressed: onSeekForward,
          ),
        ],
      ],
    );
  }
}

class _SeekStepOrb extends StatelessWidget {
  const _SeekStepOrb({
    required this.seconds,
    required this.forward,
    required this.tooltip,
    required this.onPressed,
  });

  final int seconds;
  final bool forward;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: SizedBox(
          width: 54,
          height: 54,
          child: LiquidPlayerCapsule(
            borderRadius: BorderRadius.circular(27),
            padding: EdgeInsets.zero,
            blurSigma: 12,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  forward
                      ? Icons.forward_10_rounded
                      : Icons.replay_10_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                Text(
                  '${seconds}s',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Interactive BitChord Liquid Glass Bottom Dock:
/// expanding luminous scrubber track, floating scrub preview bubble, chapter/
/// skip-segment markers, timestamp toggle pill, and compact glass action chips.
class LiquidGlassBottomDock extends StatefulWidget {
  const LiquidGlassBottomDock({
    required this.position,
    required this.duration,
    required this.buffer,
    required this.showRemainingTime,
    required this.onToggleRemainingTime,
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
    this.skipSegments = const <SkipSegment>[],
    this.isTv = false,
    this.isLive = false,
    this.onToggleFullscreen,
    this.isFullscreen = false,
    super.key,
  });

  final Duration position;
  final Duration duration;
  final Duration buffer;
  final bool showRemainingTime;
  final VoidCallback onToggleRemainingTime;
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
  State<LiquidGlassBottomDock> createState() => _LiquidGlassBottomDockState();
}

class _LiquidGlassBottomDockState extends State<LiquidGlassBottomDock> {
  bool _dragging = false;
  bool _hovering = false;
  double _dragFraction = 0.0;

  static String _fmtClock(Duration d) {
    final neg = d.isNegative;
    final abs = d.abs();
    final h = abs.inHours;
    final m = abs.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = abs.inSeconds.remainder(60).toString().padLeft(2, '0');
    final core = h > 0 ? '$h:$m:$s' : '$m:$s';
    return neg ? '-$core' : core;
  }

  void _updateFromLocalX(double dx, double width, {bool finish = false}) {
    final totalMs = widget.duration.inMilliseconds;
    if (width <= 0 || totalMs <= 0) return;
    final frac = (dx / width).clamp(0.0, 1.0);
    setState(() => _dragFraction = frac);
    final target = Duration(milliseconds: (totalMs * frac).round());
    if (finish) {
      setState(() => _dragging = false);
      widget.onSeekEnd(target);
    } else {
      widget.onSeekUpdate(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final totalMs = widget.duration.inMilliseconds;
    final liveFraction = totalMs > 0
        ? (widget.position.inMilliseconds / totalMs).clamp(0.0, 1.0)
        : 0.0;
    final activeFraction = _dragging ? _dragFraction : liveFraction;
    final bufferedFraction = totalMs > 0
        ? (widget.buffer.inMilliseconds / totalMs).clamp(0.0, 1.0)
        : 0.0;
    final displayPos = _dragging
        ? Duration(milliseconds: (totalMs * _dragFraction).round())
        : widget.position;
    final remaining = widget.duration - displayPos;
    final rightLabel = widget.showRemainingTime && totalMs > 0
        ? _fmtClock(-remaining)
        : _fmtClock(widget.duration);

    final delayMs = widget.subtitleDelay.inMilliseconds;
    final delayText = delayMs == 0
        ? null
        : '${delayMs > 0 ? '+' : ''}${(delayMs / 1000).toStringAsFixed(1)}s';

    return Container(
      padding: EdgeInsets.fromLTRB(
        widget.isTv ? 28 : 14,
        14,
        widget.isTv ? 28 : 14,
        math.max(12.0, bottomPad + 8),
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: <Color>[
            Color(0xD205070D),
            Color(0x6605070D),
            Color(0x0005070D),
          ],
          stops: <double>[0.0, 0.56, 1.0],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (!widget.isLive)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final trackWidth = constraints.maxWidth;
                  final thumbX = (trackWidth * activeFraction).clamp(14.0, math.max(14.0, trackWidth - 14.0));
                  final deltaFromNow = displayPos - widget.position;
                  final deltaSec = deltaFromNow.inSeconds;
                  final deltaTag = deltaSec.abs() >= 1
                      ? ' ${deltaSec > 0 ? '+' : ''}${deltaSec}s'
                      : '';

                  return MouseRegion(
                    onEnter: (_) => setState(() => _hovering = true),
                    onExit: (_) => setState(() => _hovering = false),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragStart: (d) {
                        setState(() => _dragging = true);
                        widget.onSeekStart();
                        _updateFromLocalX(d.localPosition.dx, trackWidth);
                      },
                      onHorizontalDragUpdate: (d) {
                        _updateFromLocalX(d.localPosition.dx, trackWidth);
                      },
                      onHorizontalDragEnd: (_) {
                        _updateFromLocalX(
                          _dragFraction * trackWidth,
                          trackWidth,
                          finish: true,
                        );
                      },
                      onTapDown: (d) {
                        _updateFromLocalX(
                          d.localPosition.dx,
                          trackWidth,
                          finish: true,
                        );
                      },
                      child: SizedBox(
                        height: 36,
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.centerLeft,
                          children: <Widget>[
                            // Floating Liquid Glass scrub time pill during drag
                            if (_dragging && totalMs > 0)
                              Positioned(
                                left: (thumbX - 48)
                                    .clamp(
                                      0.0,
                                      math.max(0.0, trackWidth - 96.0),
                                    )
                                    .toDouble(),
                                top: -38,
                                child: LiquidPlayerCapsule(
                                  borderRadius: BorderRadius.circular(14),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  activeAccent: const Color(0xFF38BDF8),
                                  child: Text(
                                    '${_fmtClock(displayPos)}$deltaTag',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      fontFeatures: <FontFeature>[
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            // Track rail capsule
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 120),
                              height: (_dragging || _hovering) ? 8.5 : 5.0,
                              width: trackWidth,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.white.withValues(alpha: 0.16),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  width: 0.5,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: <Widget>[
                                    // Buffered region
                                    FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: bufferedFraction,
                                      child: Container(
                                        color: Colors.white.withValues(
                                          alpha: 0.24,
                                        ),
                                      ),
                                    ),
                                    // Skip segment markers (intro / outro)
                                    if (totalMs > 0)
                                      for (final seg in widget.skipSegments)
                                        Positioned(
                                          left: ((seg.startTime * 1000 / totalMs)
                                                  .clamp(0.0, 1.0)) *
                                              trackWidth,
                                          width: math.max(
                                            3.0,
                                            (((seg.endTime - seg.startTime) *
                                                        1000 /
                                                        totalMs)
                                                    .clamp(0.0, 1.0)) *
                                                trackWidth,
                                          ),
                                          top: 0,
                                          bottom: 0,
                                          child: Container(
                                            color: const Color(0xFFFBBF24)
                                                .withValues(alpha: 0.65),
                                          ),
                                        ),
                                    // Played luminous gradient fill
                                    FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: activeFraction,
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: <Color>[
                                              Color(0xFF38BDF8),
                                              Color(0xFF818CF8),
                                              Color(0xFFC084FC),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Glowing optical glass scrubber thumb
                            Positioned(
                              left: math.max(
                                0.0,
                                (trackWidth * activeFraction) -
                                    ((_dragging || _hovering) ? 9 : 6.5),
                              ),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 120),
                                width: (_dragging || _hovering) ? 18 : 13,
                                height: (_dragging || _hovering) ? 18 : 13,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  boxShadow: <BoxShadow>[
                                    BoxShadow(
                                      color: const Color(0xFF818CF8)
                                          .withValues(alpha: 0.65),
                                      blurRadius:
                                          (_dragging || _hovering) ? 12 : 6,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          // Action Strip in Liquid Glass Pills
          Row(
            children: <Widget>[
              GestureDetector(
                onTap: widget.onToggleRemainingTime,
                child: LiquidPlayerCapsule(
                  borderRadius: BorderRadius.circular(18),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  child: Text(
                    widget.isLive
                        ? l10n.live
                        : '${_fmtClock(displayPos)} / $rightLabel',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      fontFeatures: <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (widget.hasEpisodes) ...<Widget>[
                        _GlassDockChip(
                          icon: Icons.video_library_rounded,
                          label: l10n.episodes,
                          onTap: widget.onOpenEpisodes,
                        ),
                        const SizedBox(width: 7),
                      ],
                      _GlassDockChip(
                        icon: Icons.audiotrack_rounded,
                        label: l10n.audio,
                        onTap: widget.onOpenAudio,
                      ),
                      const SizedBox(width: 7),
                      _GlassDockChip(
                        icon: widget.subtitlesActive
                            ? Icons.subtitles_rounded
                            : Icons.subtitles_outlined,
                        label: delayText != null
                            ? '${l10n.subtitles} $delayText'
                            : l10n.subtitles,
                        active: widget.subtitlesActive,
                        onTap: widget.onOpenSubtitles,
                      ),
                      if (!widget.isLive) ...<Widget>[
                        const SizedBox(width: 7),
                        _GlassDockChip(
                          icon: Icons.speed_rounded,
                          label:
                              '${widget.playbackSpeed == widget.playbackSpeed.roundToDouble() ? widget.playbackSpeed.toInt() : widget.playbackSpeed}x',
                          active: (widget.playbackSpeed - 1.0).abs() > 0.01,
                          onTap: widget.onCycleSpeed,
                        ),
                      ],
                      const SizedBox(width: 7),
                      _GlassDockChip(
                        icon: Icons.tune_rounded,
                        label: l10n.sources,
                        onTap: widget.onOpenSources,
                      ),
                      const SizedBox(width: 7),
                      if (widget.onToggleFullscreen != null) ...<Widget>[
                        _GlassDockChip(
                          icon: widget.isFullscreen
                              ? Icons.fullscreen_exit_rounded
                              : Icons.fullscreen_rounded,
                          label: l10n.fullscreen,
                          active: widget.isFullscreen,
                          onTap: widget.onToggleFullscreen!,
                        ),
                        const SizedBox(width: 7),
                      ],
                      _GlassDockChip(
                        icon: Icons.more_horiz_rounded,
                        label: l10n.playerMoreControls,
                        onTap: widget.onOpenMore,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GlassDockChip extends StatelessWidget {
  const _GlassDockChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: LiquidPlayerCapsule(
        borderRadius: BorderRadius.circular(18),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        activeAccent: active ? const Color(0xFF818CF8) : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              size: 16,
              color: active
                  ? const Color(0xFFA5B4FC)
                  : Colors.white.withValues(alpha: 0.92),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: active
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.92),
                fontSize: 12,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// BitChord Apple Liquid Glass vertical gesture feedback rail for Left=Volume
/// and Right=Brightness on touch screens.
class LiquidGlassEdgeRail extends StatelessWidget {
  const LiquidGlassEdgeRail({
    required this.icon,
    required this.fraction,
    required this.percentLabel,
    required this.titleLabel,
    required this.onLeft,
    this.boosted = false,
    super.key,
  });

  final IconData icon;
  final double fraction;
  final String percentLabel;
  final String titleLabel;
  final bool onLeft;
  final bool boosted;

  @override
  Widget build(BuildContext context) {
    final clamped = fraction.clamp(0.0, 1.0);
    final fillGradient = boosted
        ? const LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: <Color>[Color(0xFF38BDF8), Color(0xFFF59E0B)],
          )
        : LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: onLeft
                ? const <Color>[Color(0xFF38BDF8), Color(0xFF818CF8)]
                : const <Color>[Color(0xFFFBBF24), Color(0xFFFEF08A)],
          );

    return Align(
      alignment: onLeft ? Alignment.centerLeft : Alignment.centerRight,
      child: Padding(
        padding: EdgeInsets.only(
          left: onLeft ? 22 : 0,
          right: onLeft ? 0 : 22,
        ),
        child: LiquidPlayerCapsule(
          borderRadius: BorderRadius.circular(26),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 14),
          blurSigma: 14,
          activeAccent: boosted ? const Color(0xFFF59E0B) : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                percentLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: 8,
                height: 116,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: Colors.white.withValues(alpha: 0.16),
                ),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionallySizedBox(
                    heightFactor: clamped,
                    widthFactor: 1.0,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        gradient: fillGradient,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Icon(
                icon,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(height: 3),
              Text(
                titleLabel,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
