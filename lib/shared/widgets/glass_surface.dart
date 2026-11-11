import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/app_world.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/theme_presets.dart';

/// Saturation color matrix helper for Apple-style vibrancy behind frosted glass.
List<double> _vibrancyColorMatrix(double saturation) {
  final invS = 1.0 - saturation;
  final r = 0.2126 * invS;
  final g = 0.7152 * invS;
  final b = 0.0722 * invS;
  return <double>[
    r + saturation, g, b, 0, 0,
    r, g + saturation, b, 0, 0,
    r, g, b + saturation, 0, 0,
    0, 0, 0, 1, 0,
  ];
}

/// Paints a BitChord / iOS 26 45-degree directional specular rim catchlight and
/// subtle inner top sheen on a rounded rectangle without obscuring child text.
class LiquidGlassRimPainter extends CustomPainter {
  const LiquidGlassRimPainter({
    required this.borderRadius,
    required this.isDark,
    this.strokeWidth = 1.1,
    this.rimStrength = 1.0,
    this.drawInnerSheen = true,
  });

  final BorderRadius borderRadius;
  final bool isDark;
  final double strokeWidth;
  final double rimStrength;
  final bool drawInnerSheen;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final rrect = borderRadius.toRRect(rect);

    if (drawInnerSheen) {
      canvas.save();
      canvas.clipRRect(rrect);
      final sheenPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.42],
          colors: [
            Colors.white.withValues(
              alpha: (isDark ? 0.11 : 0.36) * rimStrength,
            ),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(rect);
      canvas.drawRect(rect, sheenPaint);
      canvas.restore();
    }

    // 45° top-left primary catchlight & bottom-right secondary counter-glint
    final insetRRect = rrect.deflate(strokeWidth * 0.5);
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        stops: const [0.0, 0.28, 0.68, 1.0],
        colors: isDark
            ? [
                Colors.white.withValues(alpha: (0.58 * rimStrength).clamp(0.0, 1.0)),
                Colors.white.withValues(alpha: (0.14 * rimStrength).clamp(0.0, 1.0)),
                Colors.white.withValues(alpha: (0.06 * rimStrength).clamp(0.0, 1.0)),
                Colors.white.withValues(alpha: (0.30 * rimStrength).clamp(0.0, 1.0)),
              ]
            : [
                Colors.white.withValues(alpha: (0.92 * rimStrength).clamp(0.0, 1.0)),
                Colors.white.withValues(alpha: (0.35 * rimStrength).clamp(0.0, 1.0)),
                Colors.black.withValues(alpha: (0.05 * rimStrength).clamp(0.0, 1.0)),
                Colors.white.withValues(alpha: (0.55 * rimStrength).clamp(0.0, 1.0)),
              ],
      ).createShader(rect);
    canvas.drawRRect(insetRRect, rimPaint);

    // Subtle crisp outer hairline
    final hairlinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.65
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.10 * rimStrength)
          : Colors.black.withValues(alpha: 0.07 * rimStrength);
    canvas.drawRRect(rrect.deflate(0.32), hairlinePaint);
  }

  @override
  bool shouldRepaint(covariant LiquidGlassRimPainter oldDelegate) =>
      oldDelegate.borderRadius != borderRadius ||
      oldDelegate.isDark != isDark ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.rimStrength != rimStrength ||
      oldDelegate.drawInnerSheen != drawInnerSheen;
}

/// Resolves standard translucent glass fill respecting [AppWorldColors] and
/// Apple Liquid Glass mode.
Color resolveLiquidGlassFill(
  BuildContext context, {
  Color? override,
  bool liquidGlass = true,
}) {
  if (override != null) return override;
  final colors = AppWorldTokens.colorsOf(context);
  if (!liquidGlass) return colors.glassFill;
  final appleBase = colors.isDark
      ? const Color(0xFF14161D).withValues(alpha: 0.44)
      : const Color(0xFFFAFAFC).withValues(alpha: 0.58);
  return Color.lerp(colors.glassFill, appleBase, 0.65)!;
}

/// A translucent, Apple iOS 26 / BitChord-inspired Liquid Glass panel with
/// vibrancy saturation boost, directional 45° specular rim catchlight, inner
/// sheen, and soft depth shadow.
///
/// Rules the pack sets, enforced here:
///  * glass is chrome, not content: never wrap a scrolling list or a card grid
///    in this when [blurSigma] > 0 (use [LightweightGlassSurface] there);
///  * [blurSigma] of zero paints the same rimmed translucent glass without a
///    GPU BackdropFilter pass.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpace.lg),
    this.borderRadius,
    this.blurSigma = AppBlur.chrome,
    this.fill,
    this.border,
    this.shadow = true,
    this.clipBehavior = Clip.antiAlias,
    this.useVibrancy = true,
    this.rimStrength = 1.0,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;
  final double blurSigma;

  /// Overrides the glass fill. For darker player scrims or tinted pills.
  final Color? fill;

  /// Overrides the directional specular rim with an explicit [BoxBorder].
  final BoxBorder? border;

  final bool shadow;
  final Clip clipBehavior;

  /// Applies subtle BitChord saturation boost behind the blur when active.
  final bool useVibrancy;

  /// Scales specular rim highlight intensity (0 disables extra specular rim).
  final double rimStrength;

  @override
  Widget build(BuildContext context) {
    final colors = AppWorldTokens.colorsOf(context);
    final tokens = Theme.of(context).extension<AppSurfaceTokens>();
    final liquidGlass = tokens?.liquidGlass ?? true;
    final glassPerf = tokens?.glassPerformance ?? false;
    final radius = borderRadius ?? AppRadius.panel;
    final resolvedRadius = radius.resolve(Directionality.of(context));
    final reduce = AppMotion.reduced(context);

    final panelFill = resolveLiquidGlassFill(
      context,
      override: fill,
      liquidGlass: liquidGlass,
    );

    final Widget paddedChild = Padding(padding: padding, child: child);
    final Widget paintedContent = (border == null && liquidGlass && rimStrength > 0)
        ? CustomPaint(
            painter: LiquidGlassRimPainter(
              borderRadius: resolvedRadius,
              isDark: colors.isDark,
              rimStrength: rimStrength,
              drawInnerSheen: true,
            ),
            child: paddedChild,
          )
        : paddedChild;

    Widget panel = DecoratedBox(
      decoration: BoxDecoration(
        color: panelFill,
        borderRadius: radius,
        border: border ??
            (liquidGlass ? null : Border.all(color: colors.glassEdge, width: 1)),
      ),
      child: paintedContent,
    );

    if (blurSigma > 0 && !reduce && !glassPerf) {
      // Single-pass blur kept bounded (12 max in Liquid Glass) with
      // TileMode.clamp and RepaintBoundary isolation so GPU frame times stay
      // fast. When Performance Mode (or desktop Skia glassPerf) is active,
      // skip BackdropFilter completely so Skia/ANGLE never allocates D3D11
      // offscreen saveLayers.
      final effectiveSigma = !liquidGlass
          ? blurSigma
          : math.min(math.max(blurSigma, 10.0), 12.0);
      final blurFilter = ImageFilter.blur(
        sigmaX: effectiveSigma,
        sigmaY: effectiveSigma,
        tileMode: TileMode.clamp,
      );
      final platform = Theme.of(context).platform;
      final useSinglePassBlur =
          platform == TargetPlatform.windows || platform == TargetPlatform.linux;
      final filter = (liquidGlass &&
              useVibrancy &&
              !useSinglePassBlur &&
              effectiveSigma <= 10.0)
          ? ImageFilter.compose(
              outer: ColorFilter.matrix(_vibrancyColorMatrix(1.24)),
              inner: blurFilter,
            )
          : blurFilter;

      panel = RepaintBoundary(
        child: ClipRRect(
          borderRadius: radius,
          clipBehavior: clipBehavior,
          child: BackdropFilter(filter: filter, child: panel),
        ),
      );
    } else {
      panel = ClipRRect(
        borderRadius: radius,
        clipBehavior: clipBehavior,
        child: panel,
      );
    }

    if (!shadow) return panel;
    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: colors.isDark ? (liquidGlass ? 0.42 : 0.34) : 0.10,
            ),
            blurRadius: liquidGlass ? 26 : 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: panel,
    );
  }
}

/// Zero-BackdropFilter Liquid Glass surface for scrolling lists, settings groups,
/// and cards that still deserve the Apple specular rim and sheen at locked 120Hz.
class LightweightGlassSurface extends StatelessWidget {
  const LightweightGlassSurface({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.borderRadius,
    this.fill,
    this.shadow = false,
    this.rimStrength = 0.85,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;
  final Color? fill;
  final bool shadow;
  final double rimStrength;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      padding: padding,
      borderRadius: borderRadius,
      blurSigma: 0,
      fill: fill,
      shadow: shadow,
      useVibrancy: false,
      rimStrength: rimStrength,
      child: child,
    );
  }
}

/// A glass panel that fills the width of its parent. The settings screens and
/// the details action bar use this shape repeatedly.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpace.lg,
      vertical: AppSpace.md,
    ),
    this.borderRadius,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      padding: padding,
      borderRadius: borderRadius ?? AppRadius.panel,
      blurSigma: AppBlur.subtle,
      child: child,
    );
  }
}
