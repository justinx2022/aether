import 'package:flutter/material.dart';

import '../../core/theme/app_world.dart';
import '../../core/theme/design_tokens.dart';

/// A solid elevated panel with one hairline edge and a soft shadow.
///
/// This is the app's only raised surface. Everything that wants a lifted
/// panel - the sidebar dock, the phone navigation pill, player sheets,
/// dialogs, the details action bar - composes this rather than reaching for
/// its own decoration, so the fill, edge and radius cannot drift apart.
///
/// There is no blur anywhere in the app: depth comes from solid fills,
/// hairlines and shadows only.
///
/// Rules the pack sets, enforced here:
///  * panels are chrome, not content: never wrap a scrolling list or a card
///    grid in this;
///  * the fill comes from the active world, so a panel on GROUND is warm and a
///    panel on SKY is cool without the caller naming a colour;
///  * the edge is a hairline, not a border, and it is the same on every panel.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpace.lg),
    this.borderRadius,
    this.fill,
    this.border,
    this.shadow = true,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;

  /// Overrides the world's elevated fill. For the rare panel that needs to be
  /// darker or lighter - a player scrim, for instance.
  final Color? fill;

  /// Overrides the hairline. Null keeps the world's hairline edge.
  final BoxBorder? border;

  final bool shadow;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final colors = AppWorldTokens.colorsOf(context);
    final radius = borderRadius ?? AppRadius.panel;

    Widget panel = DecoratedBox(
      decoration: BoxDecoration(
        color: fill ?? colors.elevated,
        borderRadius: radius,
        border: border ?? Border.all(color: colors.hairline, width: 1),
      ),
      child: Padding(padding: padding, child: child),
    );

    // Solid surface, clipped crisp - no blur anywhere.
    panel = ClipRRect(
      borderRadius: radius,
      clipBehavior: clipBehavior,
      child: panel,
    );

    if (!shadow) return panel;
    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: colors.isDark ? 0.34 : 0.10),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: panel,
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
      child: child,
    );
  }
}
