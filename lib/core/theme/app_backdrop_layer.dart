import 'package:flutter/material.dart';

import 'app_world.dart';
import 'theme_presets.dart';

/// Paints the page colour - or the chosen ambient gradient - behind the shell.
///
/// Installed by `AppScaffold`, once, around the branch navigator. The tab
/// screens already lay themselves out on a transparent [Scaffold], so this is
/// what they are transparent *onto*: a single opaque base, washed with the
/// world's own gradient and, if the viewer picked one, their ambient backdrop
/// on top of that.
///
/// The world wash is shallow on purpose - a tinted top that settles into the
/// page colour - so it reads as depth rather than as decoration, and it is two
/// opaque stops rather than a blur, so it costs a gradient fill and nothing
/// else.
///
/// Deliberately not app-wide. Routes pushed above the shell - details, the
/// player - keep the theme's own opaque scaffold colour, so the fade
/// compositions inside them (the details hero blending into the page) keep
/// working and video is never drawn over a gradient.
class AppBackdropLayer extends StatelessWidget {
  const AppBackdropLayer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppSurfaceTokens>();
    // A theme without the extension is one a test built by hand; its scaffold
    // colour is the only honest answer.
    final base = tokens?.base ?? theme.scaffoldBackgroundColor;
    final world = theme.extension<AppWorldTokens>();
    final ambient = tokens == null || tokens.backdrop == AppBackdrop.none
        ? null
        : tokens.backdrop.gradientFor(
            brightness: theme.brightness,
            base: base,
            seed: theme.colorScheme.primary,
          );
    // The world wash sits underneath an ambient backdrop, so choosing one
    // deepens the page instead of replacing its identity.
    final gradient =
        ambient ??
        world?.colors.pageGradient ??
        LinearGradient(colors: [base, base]);

    final backdrop = tokens?.backdrop ?? AppBackdrop.liquidMesh;

    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: gradient),
        child: CustomPaint(
          painter: SpaceBackdropPainter(
            backdrop: backdrop,
            brightness: theme.brightness,
            accent: theme.colorScheme.primary,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Paints soft luminous chromatic mesh orbs so Liquid Glass chrome visibly refracts depth.
class SpaceBackdropPainter extends CustomPainter {
  final AppBackdrop backdrop;
  final Brightness brightness;
  final Color? accent;

  const SpaceBackdropPainter({
    required this.backdrop,
    required this.brightness,
    this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (backdrop == AppBackdrop.none || backdrop == AppBackdrop.obsidianVoid) {
      return;
    }

    final isDark = brightness == Brightness.dark;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    void drawOrb({
      required Alignment alignment,
      required double radius,
      required Color color,
      required double alpha,
    }) {
      final paint = Paint()
        ..shader = RadialGradient(
          center: alignment,
          radius: radius,
          colors: [color.withValues(alpha: alpha), Colors.transparent],
        ).createShader(rect);
      canvas.drawRect(rect, paint);
    }

    final aScale = isDark ? 1.0 : 0.58;
    final seedColor = accent ?? const Color(0xFF448AFF);

    switch (backdrop) {
      case AppBackdrop.none:
      case AppBackdrop.obsidianVoid:
        return;
      case AppBackdrop.liquidMesh:
        drawOrb(
          alignment: const Alignment(-0.72, -0.78),
          radius: 0.92,
          color: Color.lerp(const Color(0xFF4F46E5), seedColor, 0.35)!,
          alpha: 0.28 * aScale,
        );
        drawOrb(
          alignment: const Alignment(0.82, -0.25),
          radius: 0.80,
          color: const Color(0xFF06B6D4),
          alpha: 0.18 * aScale,
        );
        drawOrb(
          alignment: const Alignment(-0.05, 0.92),
          radius: 0.85,
          color: Color.lerp(const Color(0xFF7C3AED), seedColor, 0.30)!,
          alpha: 0.22 * aScale,
        );
      case AppBackdrop.nebula:
        drawOrb(
          alignment: const Alignment(-0.6, -0.7),
          radius: 0.85,
          color: const Color(0xFF7C3AED),
          alpha: 0.22 * aScale,
        );
        drawOrb(
          alignment: const Alignment(0.7, -0.2),
          radius: 0.75,
          color: const Color(0xFF06B6D4),
          alpha: 0.15 * aScale,
        );
        drawOrb(
          alignment: const Alignment(0.0, 0.95),
          radius: 0.75,
          color: const Color(0xFF6D28D9),
          alpha: 0.14 * aScale,
        );
      case AppBackdrop.blackhole:
        final paint = Paint()
          ..shader = RadialGradient(
            center: const Alignment(0.0, -0.5),
            radius: 0.9,
            colors: [
              const Color(0xFFD97706).withValues(alpha: 0.20 * aScale),
              const Color(0xFF92400E).withValues(alpha: 0.10 * aScale),
              Colors.transparent,
            ],
            stops: const [0.0, 0.45, 1.0],
          ).createShader(rect);
        canvas.drawRect(rect, paint);
        drawOrb(
          alignment: const Alignment(0.15, 0.95),
          radius: 0.70,
          color: const Color(0xFFB45309),
          alpha: 0.12 * aScale,
        );
      case AppBackdrop.starfield:
        drawOrb(
          alignment: const Alignment(0.0, -0.8),
          radius: 1.0,
          color: const Color(0xFF2563EB),
          alpha: 0.18 * aScale,
        );
        drawOrb(
          alignment: const Alignment(0.0, 0.95),
          radius: 0.75,
          color: const Color(0xFF1D4ED8),
          alpha: 0.12 * aScale,
        );
      case AppBackdrop.aurora:
        drawOrb(
          alignment: const Alignment(-0.65, -0.7),
          radius: 0.85,
          color: const Color(0xFF2AA9A0),
          alpha: 0.22 * aScale,
        );
        drawOrb(
          alignment: const Alignment(0.55, 0.88),
          radius: 0.85,
          color: const Color(0xFF7C5CFF),
          alpha: 0.16 * aScale,
        );
      case AppBackdrop.dusk:
        drawOrb(
          alignment: const Alignment(-0.6, -0.7),
          radius: 0.85,
          color: const Color(0xFFB14E8C),
          alpha: 0.20 * aScale,
        );
        drawOrb(
          alignment: const Alignment(0.4, 0.9),
          radius: 0.85,
          color: const Color(0xFF4A5BC4),
          alpha: 0.16 * aScale,
        );
      case AppBackdrop.ember:
        drawOrb(
          alignment: const Alignment(-0.6, -0.7),
          radius: 0.85,
          color: const Color(0xFFD2691E),
          alpha: 0.20 * aScale,
        );
        drawOrb(
          alignment: const Alignment(0.35, 0.92),
          radius: 0.80,
          color: const Color(0xFFB23A2E),
          alpha: 0.14 * aScale,
        );
    }
  }

  @override
  bool shouldRepaint(covariant SpaceBackdropPainter oldDelegate) =>
      oldDelegate.backdrop != backdrop ||
      oldDelegate.brightness != brightness ||
      oldDelegate.accent != accent;
}
