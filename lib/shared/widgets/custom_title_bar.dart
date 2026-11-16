import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../../core/router/app_router.dart' show immersiveRouteActive;

class CustomTitleBar extends StatefulWidget {
  const CustomTitleBar({super.key});

  @override
  State<CustomTitleBar> createState() => _CustomTitleBarState();
}

class _CustomTitleBarState extends State<CustomTitleBar> with WindowListener {
  bool _hovered = false;
  bool _isMaximized = false;
  bool _isFullScreen = false;
  bool _isAlwaysOnTop = false;

  /// Whether a route is drawing to the window's own edges - the player.
  bool _immersiveRoute = immersiveRouteActive.value;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    immersiveRouteActive.addListener(_onImmersiveRouteChanged);
    _updateStates();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    immersiveRouteActive.removeListener(_onImmersiveRouteChanged);
    super.dispose();
  }

  void _onImmersiveRouteChanged() {
    if (!mounted) return;
    setState(() {
      _immersiveRoute = immersiveRouteActive.value;
      if (_immersiveRoute) _hovered = false;
    });
  }

  @override
  void onWindowMaximize() {
    _updateStates();
  }

  @override
  void onWindowUnmaximize() {
    _updateStates();
  }

  @override
  void onWindowEnterFullScreen() {
    _updateStates();
  }

  @override
  void onWindowLeaveFullScreen() {
    _updateStates();
  }

  Future<void> _updateStates() async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    final isMax = await windowManager.isMaximized();
    final isFull = await windowManager.isFullScreen();
    final isAlways = await windowManager.isAlwaysOnTop();
    if (mounted) {
      setState(() {
        _isMaximized = isMax;
        _isFullScreen = isFull;
        _isAlwaysOnTop = isAlways;
        if (isFull) _hovered = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_immersiveRoute || _isFullScreen) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final titleBarColor = isDark
        ? const Color(0xE0050505)
        : const Color(0xD8FAF8F5);
    final iconColor = isDark
        ? Colors.white.withValues(alpha: 0.85)
        : const Color(0xFF5C5C5C);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: _hovered ? (Platform.isMacOS ? 28 : 48) : 8,
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: _hovered ? titleBarColor : Colors.transparent,
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (_hovered)
              Positioned(
                left: Platform.isMacOS ? 80 : 0,
                right: 0,
                top: 0,
                bottom: 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onPanStart: (_) {
                    windowManager.startDragging();
                  },
                  onDoubleTap: () async {
                    final isMax = await windowManager.isMaximized();
                    if (isMax) {
                      await windowManager.unmaximize();
                    } else {
                      await windowManager.maximize();
                    }
                  },
                ),
              ),
            // Pin icon on the left (visible when neither maximized nor fullscreen)
            if (_hovered && !_isFullScreen && !_isMaximized)
              Positioned(
                left: Platform.isMacOS ? 80 : 12,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _PinButton(
                    isActive: _isAlwaysOnTop,
                    onPressed: () async {
                      final nextState = !_isAlwaysOnTop;
                      await windowManager.setAlwaysOnTop(nextState);
                      await _updateStates();
                    },
                  ),
                ),
              ),
            // Right-side window controls (fullscreen, minimize, maximize/restore, close)
            if (!Platform.isMacOS)
              Positioned(
                right: 12,
                top: 0,
                bottom: 0,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: _hovered ? 1.0 : 0.0,
                  child: IgnorePointer(
                    ignoring: !_hovered,
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _TitleBarButton(
                            onPressed: () async {
                              await windowManager.setFullScreen(!_isFullScreen);
                              await _updateStates();
                            },
                            child: Icon(
                              _isFullScreen
                                  ? Icons.fullscreen_exit_rounded
                                  : Icons.fullscreen_rounded,
                              color: iconColor,
                              size: 16,
                            ),
                          ),
                          if (!_isFullScreen) ...[
                            const SizedBox(width: 6),
                            _TitleBarButton(
                              onPressed: () => windowManager.minimize(),
                              child: Center(
                                child: Container(
                                  width: 10,
                                  height: 1.5,
                                  color: iconColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            _TitleBarButton(
                              onPressed: () async {
                                if (_isMaximized) {
                                  await windowManager.unmaximize();
                                } else {
                                  await windowManager.maximize();
                                }
                                await _updateStates();
                              },
                              child: Center(
                                child: _isMaximized
                                    ? SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: Stack(
                                          children: [
                                            Positioned(
                                              right: 0,
                                              top: 0,
                                              child: Container(
                                                width: 8,
                                                height: 8,
                                                decoration: BoxDecoration(
                                                  border: Border.all(
                                                    color: iconColor,
                                                    width: 1.2,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Positioned(
                                              left: 0,
                                              bottom: 0,
                                              child: Container(
                                                width: 8,
                                                height: 8,
                                                decoration: BoxDecoration(
                                                  color: isDark
                                                      ? const Color(0xFF050505)
                                                      : const Color(0xFFFAF8F5),
                                                  border: Border.all(
                                                    color: iconColor,
                                                    width: 1.2,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: iconColor,
                                            width: 1.2,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            _CloseButton(
                              onPressed: () => windowManager.close(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PinButton extends StatefulWidget {
  final bool isActive;
  final VoidCallback onPressed;

  const _PinButton({required this.isActive, required this.onPressed});

  @override
  State<_PinButton> createState() => _PinButtonState();
}

class _PinButtonState extends State<_PinButton> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hoverColor = isDark
        ? Colors.white.withValues(alpha: 0.15)
        : const Color(0xFFE4D9C8);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onPressed,
        borderRadius: BorderRadius.circular(6),
        hoverColor: hoverColor,
        splashColor: hoverColor.withValues(alpha: 0.2),
        child: SizedBox(
          width: 32,
          height: Platform.isMacOS ? 28 : 32,
          child: Icon(
            widget.isActive ? Icons.push_pin_rounded : Icons.push_pin_outlined,
            color: widget.isActive
                ? theme.colorScheme.primary
                : (isDark
                      ? Colors.white.withValues(alpha: 0.5)
                      : const Color(0xFF5C5C5C).withValues(alpha: 0.6)),
            size: 16,
          ),
        ),
      ),
    );
  }
}

class _TitleBarButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;

  const _TitleBarButton({required this.child, required this.onPressed});

  @override
  State<_TitleBarButton> createState() => _TitleBarButtonState();
}

class _TitleBarButtonState extends State<_TitleBarButton> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hoverColor = isDark
        ? Colors.white.withValues(alpha: 0.15)
        : const Color(0xFFE4D9C8);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onPressed,
        borderRadius: BorderRadius.circular(6),
        hoverColor: hoverColor,
        splashColor: hoverColor.withValues(alpha: 0.2),
        child: SizedBox(width: 32, height: 32, child: widget.child),
      ),
    );
  }
}

class _CloseButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _CloseButton({required this.onPressed});

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: InkWell(
          onTap: widget.onPressed,
          borderRadius: BorderRadius.circular(6),
          hoverColor: Colors.red.withValues(alpha: 0.8),
          splashColor: Colors.red,
          child: SizedBox(
            width: 32,
            height: 32,
            child: Icon(
              Icons.close_rounded,
              color: _isHovered
                  ? Colors.white
                  : (isDark
                        ? Colors.white.withValues(alpha: 0.85)
                        : const Color(0xFF5C5C5C)),
              size: 16,
            ),
          ),
        ),
      ),
    );
  }
}
