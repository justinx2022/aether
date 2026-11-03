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

    final backdrop = tokens?.backdrop ?? AppBackdrop.nebula;

    return DecoratedBox(
      decoration: BoxDecoration(gradient: gradient),
      child: CustomPaint(
        painter: SpaceBackdropPainter(
          backdrop: backdrop,
          brightness: theme.brightness,
        ),
        child: child,
      ),
    );
  }
}

/// Paints subtle celestial space effects (nebula gas clouds, event horizon accretion glow, star clusters).
class SpaceBackdropPainter extends CustomPainter {
  final AppBackdrop backdrop;
  final Brightness brightness;

  const SpaceBackdropPainter({
    required this.backdrop,
    required this.brightness,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (backdrop == AppBackdrop.none || backdrop == AppBackdrop.obsidianVoid) {
      return;
    }

    final isDark = brightness == Brightness.dark;
    if (!isDark) return;

    if (backdrop == AppBackdrop.nebula) {
      final paint1 = Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.6, -0.7),
          radius: 0.8,
          colors: [
            const Color(0xFF7C3AED).withValues(alpha: 0.18),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint1);

      final paint2 = Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.7, -0.2),
          radius: 0.7,
          colors: [
            const Color(0xFF06B6D4).withValues(alpha: 0.12),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint2);
    } else if (backdrop == AppBackdrop.blackhole) {
      final paint = Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.0, -0.5),
          radius: 0.9,
          colors: [
            const Color(0xFFD97706).withValues(alpha: 0.16),
            const Color(0xFF92400E).withValues(alpha: 0.08),
            Colors.transparent,
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
    } else if (backdrop == AppBackdrop.starfield) {
      final paint = Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.0, -0.8),
          radius: 1.0,
          colors: [
            const Color(0xFF2563EB).withValues(alpha: 0.14),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant SpaceBackdropPainter oldDelegate) =>
      oldDelegate.backdrop != backdrop || oldDelegate.brightness != brightness;
}
