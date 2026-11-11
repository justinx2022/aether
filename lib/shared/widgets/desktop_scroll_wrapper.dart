import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/device_info_provider.dart';

class DesktopScrollWrapper extends ConsumerStatefulWidget {
  final Widget child;
  final ScrollController controller;
  final double scrollAmount;
  final Future<void> Function()? onScrollLeft;
  final Future<void> Function()? onScrollRight;

  /// Whether to show navigation buttons. If null, defaults to true on desktop platforms.
  final bool? showButtons;

  /// Whether to use compact styling (smaller buttons/padding).
  final bool isCompact;

  const DesktopScrollWrapper({
    super.key,
    required this.child,
    required this.controller,
    this.scrollAmount = 300.0,
    this.onScrollLeft,
    this.onScrollRight,
    this.showButtons,
    this.isCompact = false,
  });

  @override
  ConsumerState<DesktopScrollWrapper> createState() =>
      _DesktopScrollWrapperState();
}

class _DesktopScrollWrapperState extends ConsumerState<DesktopScrollWrapper>
    with SingleTickerProviderStateMixin<DesktopScrollWrapper> {
  bool _showLeft = false;
  bool _showRight = false;
  Ticker? _scrollTicker;
  double? _targetOffset;
  Duration _lastTick = Duration.zero;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_updateArrows);
    // Initial check after build
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateArrows());
  }

  @override
  void didUpdateWidget(DesktopScrollWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_updateArrows);
      widget.controller.addListener(_updateArrows);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateArrows());
  }

  void _cancelSmoothScroll() {
    _targetOffset = null;
    if (_scrollTicker?.isActive ?? false) {
      _scrollTicker!.stop();
    }
  }

  void _enqueueWheelScroll(double delta) {
    if (!widget.controller.hasClients || delta == 0) return;
    final pos = widget.controller.position;
    final multiplier = delta.abs() < 24 ? 1.15 : 1.45;
    final base = _targetOffset ?? widget.controller.offset;
    _targetOffset = (base + delta * multiplier).clamp(
      pos.minScrollExtent,
      pos.maxScrollExtent,
    );
    _scrollTicker ??= createTicker(_onScrollTick);
    if (!_scrollTicker!.isActive) {
      _lastTick = Duration.zero;
      _scrollTicker!.start();
    }
  }

  void _onScrollTick(Duration elapsed) {
    final targetRaw = _targetOffset;
    if (!mounted || !widget.controller.hasClients || targetRaw == null) {
      _cancelSmoothScroll();
      return;
    }
    final pos = widget.controller.position;
    final target = targetRaw.clamp(pos.minScrollExtent, pos.maxScrollExtent);
    final rawDt = _lastTick == Duration.zero
        ? (1.0 / 120.0)
        : (elapsed - _lastTick).inMicroseconds / 1000000.0;
    _lastTick = elapsed;
    final dt = rawDt.clamp(0.001, 0.05);
    final current = widget.controller.offset;
    final diff = target - current;
    if (diff.abs() < 0.35) {
      widget.controller.jumpTo(target);
      _cancelSmoothScroll();
      return;
    }
    final alpha = 1.0 - math.exp(-dt * 18.0);
    widget.controller.jumpTo(current + diff * alpha);
  }

  @override
  void dispose() {
    _scrollTicker?.dispose();
    widget.controller.removeListener(_updateArrows);
    super.dispose();
  }

  void _updateArrows() {
    if (!widget.controller.hasClients) return;

    final position = widget.controller.position;
    final showLeft = position.pixels > 1.0;
    final showRight =
        position.maxScrollExtent > 1.0 &&
        position.pixels < (position.maxScrollExtent - 1.0);

    if (showLeft != _showLeft || showRight != _showRight) {
      if (mounted) {
        setState(() {
          _showLeft = showLeft;
          _showRight = showRight;
        });
      }
    }
  }

  void _scroll(bool right) {
    if (right && widget.onScrollRight != null) {
      widget.onScrollRight!();
      return;
    }
    if (!right && widget.onScrollLeft != null) {
      widget.onScrollLeft!();
      return;
    }

    if (!widget.controller.hasClients) return;

    final current = widget.controller.offset;
    final target = right
        ? current + widget.scrollAmount
        : current - widget.scrollAmount;

    widget.controller.animateTo(
      target.clamp(0.0, widget.controller.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  bool get _shouldShowButtons {
    // On a television these arrows are dead weight - there is no pointer to
    // click them and the D-pad scrolls the rail directly. DeviceProfile.isTv
    // (leanback / Apple TV) is the only authority for that; the second,
    // "fallback while the provider loads" check that used to sit here read
    // MediaQuery's navigation mode, which no host in this app ever sets, so
    // it answered false on the very televisions it was meant to catch.
    final profile = ref.watch(deviceProfileProvider).asData?.value;
    if (profile?.isTv == true) return false;

    // If explicitly set, use that value
    if (widget.showButtons != null) return widget.showButtons!;
    // Default: show on desktop platforms only
    return Platform.isMacOS || Platform.isWindows || Platform.isLinux;
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateArrows());

    final childWithListener = Listener(
      onPointerDown: (_) => _cancelSmoothScroll(),
      onPointerSignal: (pointerSignal) {
        if (pointerSignal is PointerScrollEvent && widget.controller.hasClients) {
          final delta = pointerSignal.scrollDelta.dy != 0
              ? pointerSignal.scrollDelta.dy
              : pointerSignal.scrollDelta.dx;
          if (delta != 0) {
            _enqueueWheelScroll(delta);
          }
        }
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          _updateArrows();
          return false;
        },
        child: NotificationListener<ScrollMetricsNotification>(
          onNotification: (notification) {
            _updateArrows();
            return false;
          },
          child: widget.child,
        ),
      ),
    );

    // Only show buttons if enabled
    if (!_shouldShowButtons) {
      return childWithListener;
    }

    return Stack(
      children: [
        childWithListener,

        // Left Button
        if (_showLeft)
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerLeft,
              child: _ScrollButton(
                icon: Icons.chevron_left,
                isCompact: widget.isCompact,
                onTap: () => _scroll(false),
              ),
            ),
          ),

        // Right Button
        if (_showRight)
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerRight,
              child: _ScrollButton(
                icon: Icons.chevron_right,
                isCompact: widget.isCompact,
                onTap: () => _scroll(true),
              ),
            ),
          ),
      ],
    );
  }
}

class _ScrollButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isCompact;

  const _ScrollButton({
    required this.icon,
    required this.onTap,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Material(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
        shape: const CircleBorder(),
        elevation: 4,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(isCompact ? 4.0 : 8.0),
            child: Icon(
              icon,
              color: Theme.of(context).colorScheme.onSurface,
              size: isCompact ? 20 : 24,
            ),
          ),
        ),
      ),
    );
  }
}
