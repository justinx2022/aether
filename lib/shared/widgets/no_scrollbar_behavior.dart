import 'dart:ui';
import 'package:flutter/material.dart';

/// The global Aether scroll behavior supporting ultra-fluid 120Hz/ProMotion
/// inertia bouncing physics and universal pointer drag.
class AetherScrollBehavior extends MaterialScrollBehavior {
  final bool ultraFluid;
  const AetherScrollBehavior({this.ultraFluid = true});

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
      };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    if (ultraFluid) {
      return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
    }
    return super.getScrollPhysics(context);
  }
}

/// The app's scroll behaviour with the scrollbar taken away.
///
/// For screens that draw their own edge hint - a gradient where the list
/// carries on - in place of a scrollbar.
class NoScrollbarBehavior extends AetherScrollBehavior {
  const NoScrollbarBehavior({super.ultraFluid = true});

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
