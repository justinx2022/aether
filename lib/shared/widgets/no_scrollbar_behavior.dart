import 'dart:ui';
import 'package:flutter/material.dart';

/// The app's scroll behaviour with smooth momentum, mouse dragging, and no ugly scrollbar.
///
/// Enables butter-smooth scrolling across Windows, macOS, Linux, and Android
/// with mouse drag, trackpad, and touch support.
class NoScrollbarBehavior extends MaterialScrollBehavior {
  const NoScrollbarBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    );
  }

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
