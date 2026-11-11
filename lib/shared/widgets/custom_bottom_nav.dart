import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:skystream/l10n/generated/app_localizations.dart';

import '../../core/theme/app_world.dart';
import '../../core/theme/theme_presets.dart';
import '../focus/app_focus.dart';
import 'glass_surface.dart';

/// Floating Apple iOS 26 / BitChord-style Liquid Glass bottom navigation bar.
///
/// Renders a spring-physics gliding selection pill over `[Home, Explore, Library, Settings]`
/// paired with a detached circular Search glass orb (`branchIndex = 1`) beside it.
/// Falls back to a clean unified pill when [AppSurfaceTokens.liquidGlass] is turned off.
class CustomBottomNavBar extends StatefulWidget {
  final int currentIndex;
  final void Function(int) onTap;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const double height = 62;

  /// The pill's offset from the screen bottom.
  static double bottomInsetFor(BuildContext context) =>
      math.max(MediaQuery.viewPaddingOf(context).bottom - 8, 12);

  @override
  State<CustomBottomNavBar> createState() => _CustomBottomNavBarState();
}

class _CustomBottomNavBarState extends State<CustomBottomNavBar>
    with SingleTickerProviderStateMixin {
  static const List<int> _mainBranches = <int>[0, 2, 3, 4];

  late final AnimationController _pillController;
  double _pillPosition = 0.0;
  double _pillFrom = 0.0;
  double _pillTo = 0.0;
  bool _searchPressed = false;

  @override
  void initState() {
    super.initState();
    _pillPosition = _slotForBranch(widget.currentIndex).toDouble();
    _pillFrom = _pillPosition;
    _pillTo = _pillPosition;
    _pillController = AnimationController.unbounded(vsync: this)
      ..addListener(() {
        if (!mounted) return;
        setState(() {
          _pillPosition = _pillController.value;
        });
      });
  }

  @override
  void didUpdateWidget(CustomBottomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex &&
        widget.currentIndex != 1) {
      final target = _slotForBranch(widget.currentIndex).toDouble();
      _animatePillTo(target);
    }
  }

  void _animatePillTo(double target) {
    _pillFrom = _pillPosition;
    _pillTo = target;
    _pillController.stop();
    if ((_pillPosition - target).abs() < 0.001) {
      setState(() => _pillPosition = target);
      return;
    }
    const spring = SpringDescription(
      mass: 1.0,
      stiffness: 340.0,
      damping: 24.0,
    );
    final simulation = SpringSimulation(spring, _pillPosition, target, 0.0);
    _pillController.animateWith(simulation);
  }

  int _slotForBranch(int branchIndex) {
    final idx = _mainBranches.indexOf(branchIndex);
    return idx >= 0 ? idx : 0;
  }

  @override
  void dispose() {
    _pillController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final tokens = theme.extension<AppSurfaceTokens>();
    final liquidGlass = tokens?.liquidGlass ?? true;
    final isDark = theme.brightness == Brightness.dark;
    final world = AppWorldTokens.colorsOf(context);

    final mainItems = <_BottomNavItemSpec>[
      _BottomNavItemSpec(
        branchIndex: 0,
        icon: Icons.home_outlined,
        selectedIcon: Icons.home_rounded,
        label: localizations.home,
      ),
      _BottomNavItemSpec(
        branchIndex: 2,
        icon: Icons.explore_outlined,
        selectedIcon: Icons.explore_rounded,
        label: localizations.explore,
      ),
      _BottomNavItemSpec(
        branchIndex: 3,
        icon: Icons.video_library_outlined,
        selectedIcon: Icons.video_library_rounded,
        label: localizations.library,
      ),
      _BottomNavItemSpec(
        branchIndex: 4,
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings_rounded,
        label: localizations.settings,
      ),
    ];

    if (!liquidGlass) {
      final allItems = <_BottomNavItemSpec>[
        mainItems[0],
        _BottomNavItemSpec(
          branchIndex: 1,
          icon: Icons.search_outlined,
          selectedIcon: Icons.search_rounded,
          label: localizations.search,
        ),
        mainItems[1],
        mainItems[2],
        mainItems[3],
      ];
      return _ClassicPillNavBar(
        items: allItems,
        currentIndex: widget.currentIndex,
        onTap: widget.onTap,
        world: world,
      );
    }

    final isMainTabSelected = widget.currentIndex != 1;
    final isSearchSelected = widget.currentIndex == 1;
    final totalTravel = (_pillTo - _pillFrom).abs();
    final flightProgress = totalTravel > 0.01
        ? (1.0 - (((_pillPosition - _pillTo).abs()) / totalTravel).clamp(0.0, 1.0))
        : 1.0;
    final midFlightStretch = math.sin(flightProgress * math.pi).clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth.clamp(0.0, 444.0);
        const double orbSize = CustomBottomNavBar.height;
        const double gap = 10.0;
        final double pillWidth = math.max(200.0, maxW - orbSize - gap);
        final double innerWidth = (pillWidth - 10.0).clamp(180.0, 500.0);
        final double slotWidth = innerWidth / mainItems.length;
        final double clampedPos = _pillPosition.clamp(
          0.0,
          (mainItems.length - 1).toDouble(),
        );
        final double indicatorLeft = clampedPos * slotWidth;

        final pillHighlightColor = isDark
            ? Colors.white.withValues(alpha: 0.16)
            : Colors.white.withValues(alpha: 0.78);

        return Align(
          alignment: Alignment.bottomCenter,
          heightFactor: 1,
          child: SizedBox(
            width: maxW,
            height: CustomBottomNavBar.height,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Detached iOS 26 / BitChord main glass capsule pill
                SizedBox(
                  width: pillWidth,
                  height: CustomBottomNavBar.height,
                  child: GlassSurface(
                    borderRadius: BorderRadius.circular(CustomBottomNavBar.height / 2),
                    padding: const EdgeInsets.all(5),
                    blurSigma: 20,
                    rimStrength: 1.15,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Spring-physics Liquid Glass Selection Pill
                        if (isMainTabSelected)
                          Positioned(
                            left: indicatorLeft,
                            top: 0,
                            bottom: 0,
                            width: slotWidth,
                            child: Transform.scale(
                              scaleX: 1.0 + 0.06 * midFlightStretch,
                              scaleY: 1.0 + 0.03 * midFlightStretch,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                    (CustomBottomNavBar.height - 10) / 2,
                                  ),
                                  color: pillHighlightColor,
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.20)
                                        : Colors.white.withValues(alpha: 0.90),
                                    width: 0.85,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: isDark ? 0.22 : 0.06,
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        Row(
                          children: [
                            for (final item in mainItems)
                              Expanded(
                                child: _LiquidNavTabCell(
                                  spec: item,
                                  isSelected: item.branchIndex == widget.currentIndex,
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    widget.onTap(item.branchIndex);
                                  },
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: gap),
                // Detached Circular Liquid Glass Search Orb (BitChord standaloneIndex)
                SizedBox(
                  width: orbSize,
                  height: orbSize,
                  child: AnimatedScale(
                    scale: _searchPressed ? 1.07 : 1.0,
                    duration: const Duration(milliseconds: 140),
                    curve: Curves.easeOutCubic,
                    child: Semantics(
                      selected: isSearchSelected,
                      button: true,
                      label: localizations.search,
                      child: GlassSurface(
                        borderRadius: BorderRadius.circular(orbSize / 2),
                        padding: const EdgeInsets.all(5),
                        blurSigma: 20,
                        rimStrength: isSearchSelected ? 1.35 : 1.15,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(orbSize / 2),
                            onTapDown: (_) => setState(() => _searchPressed = true),
                            onTapUp: (_) => setState(() => _searchPressed = false),
                            onTapCancel: () => setState(() => _searchPressed = false),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              widget.onTap(1);
                            },
                            focusColor: world.accent.withValues(alpha: 0.20),
                            hoverColor: Colors.transparent,
                            splashColor: Colors.transparent,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutCubic,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSearchSelected
                                    ? pillHighlightColor
                                    : Colors.transparent,
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                isSearchSelected
                                    ? Icons.search_rounded
                                    : Icons.search_outlined,
                                size: 24,
                                color: isSearchSelected
                                    ? (isDark ? Colors.white : Colors.black)
                                    : (isDark
                                        ? Colors.white.withValues(alpha: 0.72)
                                        : Colors.black.withValues(alpha: 0.65)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LiquidNavTabCell extends StatefulWidget {
  const _LiquidNavTabCell({
    required this.spec,
    required this.isSelected,
    required this.onTap,
  });

  final _BottomNavItemSpec spec;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_LiquidNavTabCell> createState() => _LiquidNavTabCellState();
}

class _LiquidNavTabCellState extends State<_LiquidNavTabCell> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'BottomNavTab');
  bool _focused = false;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) setState(() => _focused = _focusNode.hasFocus);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final world = AppWorldTokens.colorsOf(context);
    final activeColor = isDark ? Colors.white : Colors.black;
    final inactiveColor = isDark
        ? Colors.white.withValues(alpha: 0.62)
        : Colors.black.withValues(alpha: 0.56);
    final contentColor = widget.isSelected ? activeColor : inactiveColor;
    final radius = BorderRadius.circular((CustomBottomNavBar.height - 10) / 2);

    return FocusRing(
      focused: _focused,
      borderRadius: radius,
      child: Semantics(
        selected: widget.isSelected,
        button: true,
        label: widget.spec.label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            focusNode: _focusNode,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            onTap: widget.onTap,
            borderRadius: radius,
            focusColor: world.accent.withValues(alpha: 0.16),
            hoverColor: Colors.transparent,
            splashColor: Colors.transparent,
            child: AnimatedScale(
              scale: _pressed ? 0.92 : (widget.isSelected ? 1.03 : 1.0),
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOutCubic,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.max,
                children: [
                  Icon(
                    widget.isSelected
                        ? widget.spec.selectedIcon
                        : widget.spec.icon,
                    size: 21,
                    color: contentColor,
                  ),
                  const SizedBox(height: 2),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      widget.spec.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 10.5,
                        fontWeight:
                            widget.isSelected ? FontWeight.w700 : FontWeight.w500,
                        letterSpacing: -0.1,
                        height: 1.05,
                        color: contentColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClassicPillNavBar extends StatelessWidget {
  const _ClassicPillNavBar({
    required this.items,
    required this.currentIndex,
    required this.onTap,
    required this.world,
  });

  final List<_BottomNavItemSpec> items;
  final int currentIndex;
  final void Function(int) onTap;
  final AppWorldColors world;

  @override
  Widget build(BuildContext context) {
    final count = items.length;
    final highlight = AnimatedAlign(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      alignment: count <= 1
          ? Alignment.center
          : Alignment(-1 + 2 * (currentIndex / (count - 1)), 0),
      child: FractionallySizedBox(
        widthFactor: count == 0 ? 1 : 1 / count,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular((CustomBottomNavBar.height - 12) / 2),
              color: world.accent.withValues(alpha: world.isDark ? 0.20 : 0.16),
            ),
          ),
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final fullWidth = constraints.maxWidth.clamp(0.0, 420.0);
        return Align(
          alignment: Alignment.bottomCenter,
          heightFactor: 1,
          child: SizedBox(
            width: fullWidth,
            height: CustomBottomNavBar.height,
            child: GlassSurface(
              borderRadius: BorderRadius.circular(CustomBottomNavBar.height / 2),
              padding: EdgeInsets.zero,
              rimStrength: 0,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  highlight,
                  Row(
                    children: [
                      for (final item in items)
                        Expanded(
                          child: _LiquidNavTabCell(
                            spec: item,
                            isSelected: item.branchIndex == currentIndex,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              onTap(item.branchIndex);
                            },
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BottomNavItemSpec {
  final int branchIndex;
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _BottomNavItemSpec({
    required this.branchIndex,
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}
